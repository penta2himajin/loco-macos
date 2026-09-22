import Darwin
import Foundation

public enum FMProcess {
    /// File-backed stdio avoids argv limits and stdout/stderr pipe deadlocks.
    public static func run(
        executable: URL, arguments: [String], input: Data, timeout: TimeInterval = 45
    ) throws -> Data {
        guard timeout > 0 else { throw FMAdapterError("FM request timed out") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = directory.appendingPathComponent("stdin")
        let outputURL = directory.appendingPathComponent("stdout")
        let errorURL = directory.appendingPathComponent("stderr")
        try input.write(to: inputURL)
        try Data().write(to: outputURL)
        try Data().write(to: errorURL)
        let stdin = try FileHandle(forReadingFrom: inputURL)
        let stdout = try FileHandle(forUpdating: outputURL)
        let stderr = try FileHandle(forUpdating: errorURL)
        defer { try? stdin.close(); try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while process.isRunning {
            if ProcessInfo.processInfo.systemUptime >= deadline {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
                throw FMAdapterError("FM command timed out: \(arguments.first ?? executable.lastPathComponent)")
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            try stderr.seek(toOffset: 0)
            let detail = String(decoding: try stderr.read(upToCount: 8192) ?? Data(), as: UTF8.self)
            throw FMAdapterError("FM command failed (\(process.terminationStatus)): \(detail.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        try stdout.seek(toOffset: 0)
        let output = try stdout.read(upToCount: 1_048_577) ?? Data()
        guard output.count <= 1_048_576 else { throw FMAdapterError("FM output exceeds 1 MiB") }
        return output
    }
}
