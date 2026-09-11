import Foundation

public enum LocoServeError: Error, Sendable, Equatable {
    case notRunning
    case spawnFailed(String)
    case encodeFailed
    case decodeFailed(String)
    case emptyReply
    case processExited(Int32)
    case hostToolLoopExceeded(Int)
}

/// JSONL client for `loco serve` (configure / turn / tool_result).
public final class LocoServeClient: @unchecked Sendable {
    public static let maxHostToolRounds = 8

    private let config: RuntimeConfig
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private let lock = NSLock()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var didConfigure = false

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
        didConfigure = false
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
        didConfigure = false
    }

    /// Advertise host tools once per process lifetime (session start).
    public func ensureConfigured(tools: [HostToolDefinition] = MacHostTools.v1Catalog) throws {
        lock.lock()
        let already = didConfigure
        lock.unlock()
        guard !already else { return }
        let msg = try send(ServeClientMessage.configure(tools: tools))
        guard case .done = msg else {
            throw LocoServeError.decodeFailed("configure expected status=done")
        }
        lock.lock()
        didConfigure = true
        lock.unlock()
    }

    /// One user turn; fulfills `awaiting_tool` via `executeHost` until `done`.
    public func turn(
        user: String,
        executeHost: (String, [String: JSONValue]) -> (ok: Bool, content: JSONValue)
    ) throws -> TurnOutcome {
        try ensureConfigured()
        var message = try send(ServeClientMessage.turn(user: user))
        var rounds = 0
        while true {
            switch message {
            case let .done(outcome):
                return outcome
            case let .awaitingTool(outcome, callId):
                rounds += 1
                if rounds > Self.maxHostToolRounds {
                    throw LocoServeError.hostToolLoopExceeded(Self.maxHostToolRounds)
                }
                let request = outcome.events.reversed().compactMap { event -> (String, [String: JSONValue])? in
                    if case let .toolRequest(name, args, _) = event { return (name, args) }
                    return nil
                }.first
                let name = request?.0 ?? ""
                let args = request?.1 ?? [:]
                let result = executeHost(name, args)
                message = try send(
                    ServeClientMessage.toolResult(callId: callId, ok: result.ok, content: result.content)
                )
            }
        }
    }

    /// Backward-compatible helper used by older call sites / tests.
    public func turn(user: String) throws -> TurnOutcome {
        try turn(user: user) { name, _ in
            (
                false,
                .object([
                    "error": .string("host tool executor not provided"),
                    "tool": .string(name),
                ])
            )
        }
    }

    private func send(_ message: ServeClientMessage) throws -> ServeServerMessage {
        lock.lock()
        guard let stdin = stdinHandle, let stdout = stdoutHandle, process?.isRunning == true else {
            lock.unlock()
            throw LocoServeError.notRunning
        }
        lock.unlock()

        guard let data = try? encoder.encode(message),
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
            return try decoder.decode(ServeServerMessage.self, from: raw)
        } catch {
            // Older loco builds returned bare TurnOutcome without status.
            if let outcome = try? decoder.decode(TurnOutcome.self, from: raw) {
                return .done(outcome: outcome)
            }
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
