import Foundation

public enum InferenceBackend: String, Codable, Sendable, CaseIterable {
    case cpu
    case gpu
}

public struct RuntimeConfig: Sendable, Equatable {
    /// Absolute or PATH-resolvable path to the `loco` binary.
    public var locoPath: String
    public var backend: InferenceBackend
    public var noMemory: Bool
    public var noTools: Bool
    public var noTopic: Bool
    public var allowFs: Bool
    public var fsRoot: String?

    public init(
        locoPath: String = "loco",
        backend: InferenceBackend = .cpu,
        noMemory: Bool = false,
        noTools: Bool = false,
        noTopic: Bool = false,
        allowFs: Bool = false,
        fsRoot: String? = nil
    ) {
        self.locoPath = locoPath
        self.backend = backend
        self.noMemory = noMemory
        self.noTools = noTools
        self.noTopic = noTopic
        self.allowFs = allowFs
        self.fsRoot = fsRoot
    }

    /// Default for the overlay helper. Prefer cpu when the machine is already
    /// under GPU load; switch to gpu via `LOCO_BACKEND=gpu` (or Settings later).
    public static let overlayDefault = RuntimeConfig(backend: .cpu)

    /// Resolves overlay config from the environment (`LOCO_BACKEND=cpu|gpu|metal`).
    public static func resolvedOverlayDefault(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RuntimeConfig {
        guard let raw = environment["LOCO_BACKEND"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty
        else {
            return overlayDefault
        }
        let backend: InferenceBackend
        switch raw {
        case "gpu", "metal":
            backend = .gpu
        case "cpu":
            backend = .cpu
        default:
            return overlayDefault
        }
        return RuntimeConfig(backend: backend)
    }

    public func serveArguments() -> [String] {
        var args = ["serve", "--backend", backend.rawValue]
        if noMemory { args.append("--no-memory") }
        if noTools { args.append("--no-tools") }
        if noTopic { args.append("--no-topic") }
        if allowFs { args.append("--allow-fs") }
        if let fsRoot {
            args.append(contentsOf: ["--fs-root", fsRoot])
        }
        return args
    }
}
