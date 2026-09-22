import Foundation
import LocoMacOSCore

do {
    let environment = ProcessInfo.processInfo.environment
    let rawBudget = environment["LOCO_FM_CONTEXT_TOKENS"] ?? "4096"
    guard let budget = Int(rawBudget), budget > 1024 else {
        throw NSError(domain: "LocoFMAdapter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid LOCO_FM_CONTEXT_TOKENS (must exceed 1024)"])
    }
    let executable = URL(fileURLWithPath: environment["LOCO_FM_PATH"] ?? "/usr/bin/fm")
    let request = FileHandle.standardInput.readDataToEndOfFile()
    let deadline = ProcessInfo.processInfo.systemUptime + 100
    let response = try FMAdapter(contextTokens: budget).respond(to: request) { arguments, input in
        try FMProcess.run(
            executable: executable, arguments: arguments, input: input,
            timeout: min(45, deadline - ProcessInfo.processInfo.systemUptime)
        )
    }
    try FileHandle.standardOutput.write(contentsOf: response + Data("\n".utf8))
} catch {
    try? FileHandle.standardError.write(contentsOf: Data("LocoFMAdapter: \(error.localizedDescription)\n".utf8))
    exit(1)
}
