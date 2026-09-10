import Foundation

public enum LocoServeError: Error, Sendable, Equatable {
    case notRunning
    case spawnFailed(String)
    case encodeFailed
    case decodeFailed(String)
    case emptyReply
    case processExited(Int32)
}

/// JSONL client for `loco serve` (one `{"user":…}` line in → one `TurnOutcome` out).
public final class LocoServeClient: @unchecked Sendable {
    private let config: RuntimeConfig
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private let lock = NSLock()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(config: RuntimeConfig = .overlayDefault) {
        self.config = config
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning == true
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        if process?.isRunning == true { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: resolvedLocoPath())
        proc.arguments = config.serveArguments()

        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            throw LocoServeError.spawnFailed(error.localizedDescription)
        }

        process = proc
        stdinHandle = inPipe.fileHandleForWriting
        stdoutHandle = outPipe.fileHandleForReading
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        process?.terminate()
        process = nil
        try? stdinHandle?.close()
        try? stdoutHandle?.close()
        stdinHandle = nil
        stdoutHandle = nil
    }

    /// Send one user turn and wait for a single JSON `TurnOutcome` line.
    public func turn(user: String) throws -> TurnOutcome {
        lock.lock()
        guard let stdin = stdinHandle, let stdout = stdoutHandle, process?.isRunning == true else {
            lock.unlock()
            throw LocoServeError.notRunning
        }
        lock.unlock()

        let payload: [String: String] = ["user": user]
        guard let data = try? encoder.encode(payload),
              var line = String(data: data, encoding: .utf8)
        else {
            throw LocoServeError.encodeFailed
        }
        line.append("\n")
        guard let out = line.data(using: .utf8) else {
            throw LocoServeError.encodeFailed
        }
        try stdin.write(contentsOf: out)

        guard let responseLine = readLine(from: stdout) else {
            if let code = process?.terminationStatus {
                throw LocoServeError.processExited(code)
            }
            throw LocoServeError.emptyReply
        }
        guard let raw = responseLine.data(using: .utf8) else {
            throw LocoServeError.decodeFailed("non-utf8")
        }
        do {
            return try decoder.decode(TurnOutcome.self, from: raw)
        } catch {
            throw LocoServeError.decodeFailed(String(responseLine.prefix(200)))
        }
    }

    private func readLine(from handle: FileHandle) -> String? {
        var buffer = Data()
        while true {
            let chunk = handle.readData(ofLength: 1)
            if chunk.isEmpty {
                return buffer.isEmpty ? nil : String(data: buffer, encoding: .utf8)
            }
            if chunk[0] == UInt8(ascii: "\n") {
                return String(data: buffer, encoding: .utf8)
            }
            buffer.append(chunk)
        }
    }

    private func resolvedLocoPath() -> String {
        if config.locoPath.contains("/") {
            return config.locoPath
        }
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        for dir in pathEnv.split(separator: ":") {
            let candidate = "\(dir)/\(config.locoPath)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        // Common cargo debug location for local dev.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let local = "\(home)/repos/loco-bot/target/debug/loco"
        if FileManager.default.isExecutableFile(atPath: local) {
            return local
        }
        return config.locoPath
    }
}

/// Decode helpers used by tests and mock overlays.
public enum TurnOutcomeJSON {
    public static func decode(_ raw: String) throws -> TurnOutcome {
        guard let data = raw.data(using: .utf8) else {
            throw LocoServeError.decodeFailed("non-utf8")
        }
        return try JSONDecoder().decode(TurnOutcome.self, from: data)
    }
}
