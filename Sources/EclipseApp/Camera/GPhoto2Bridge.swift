import Foundation

/// Thin bridge to gphoto2 CLI — all calls run on a serial background queue.
final class GPhoto2Bridge {

    // Shared singleton so Sony bridge can also use it
    static let shared = GPhoto2Bridge()

    private let queue = DispatchQueue(label: "gphoto2.bridge", qos: .userInitiated)
    private var connectedPort: String?

    init() {}

    // MARK: - Detection

    func detectCameras(completion: @escaping ([DetectedCamera]) -> Void) {
        queue.async {
            let out = self.runGPhoto(args: ["--auto-detect"])
            var cameras: [DetectedCamera] = []
            let lines = out.components(separatedBy: "\n").dropFirst(2)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let port = parts.last!
                    let name = parts.dropLast().joined(separator: " ")
                    cameras.append(DetectedCamera(
                        id: UUID(), name: name, port: port, backend: .gphoto2))
                }
            }
            DispatchQueue.main.async { completion(cameras) }
        }
    }

    // MARK: - Connection

    func connect(port: String, completion: @escaping (Bool) -> Void) {
        queue.async {
            let out = self.runGPhoto(args: ["--port", port, "--summary"])
            let ok = out.contains("Manufacturer") || out.contains("Model") || out.contains("Camera")
            if ok { self.connectedPort = port }
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func disconnect() {
        queue.async { self.connectedPort = nil }
    }

    // MARK: - Config (uses stored port or explicit port)

    func listConfig(key: String, completion: @escaping ([String]) -> Void) {
        queue.async {
            guard let port = self.connectedPort else {
                DispatchQueue.main.async { completion([]) }; return
            }
            self.listConfigOnPort(key: key, port: port, completion: completion)
        }
    }

    func listConfigOnPort(key: String, port: String, completion: @escaping ([String]) -> Void) {
        queue.async {
            let out = self.runGPhoto(args: ["--port", port, "--get-config", key])
            var choices: [String] = []
            for line in out.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("Choice:") {
                    let parts = t.components(separatedBy: " ").filter { !$0.isEmpty }
                    if parts.count >= 3 { choices.append(parts[2...].joined(separator: " ")) }
                }
            }
            DispatchQueue.main.async { completion(choices) }
        }
    }

    func setConfig(key: String, value: String) {
        queue.async {
            guard let port = self.connectedPort else { return }
            _ = self.runGPhoto(args: ["--port", port, "--set-config", "\(key)=\(value)"])
        }
    }

    func setConfig(key: String, value: String, port: String) {
        queue.async {
            _ = self.runGPhoto(args: ["--port", port, "--set-config", "\(key)=\(value)"])
        }
    }

    // MARK: - Capture

    func triggerCapture(completion: @escaping (Bool) -> Void) {
        queue.async {
            guard let port = self.connectedPort else {
                DispatchQueue.main.async { completion(false) }; return
            }
            self.triggerCapture(port: port, completion: completion)
        }
    }

    func triggerCapture(port: String, completion: @escaping (Bool) -> Void) {
        queue.async {
            let out = self.runGPhoto(args: ["--port", port, "--trigger-capture"])
            let ok = !out.lowercased().contains("error")
            DispatchQueue.main.async { completion(ok) }
        }
    }

    // MARK: - Live View

    func captureLiveViewJpeg(completion: @escaping (Data?) -> Void) {
        queue.async {
            guard let port = self.connectedPort else {
                DispatchQueue.main.async { completion(nil) }; return
            }
            self.captureLiveViewJpeg(port: port, completion: completion)
        }
    }

    func captureLiveViewJpeg(port: String, completion: @escaping (Data?) -> Void) {
        queue.async {
            let tmp = NSTemporaryDirectory() + "lv_\(Int.random(in: 0..<999999)).jpg"
            _ = self.runGPhoto(args: ["--port", port, "--capture-preview",
                                      "--filename", tmp, "--force-overwrite"])
            let data = try? Data(contentsOf: URL(fileURLWithPath: tmp))
            try? FileManager.default.removeItem(atPath: tmp)
            DispatchQueue.main.async { completion(data) }
        }
    }

    // MARK: - Shell runner

    @discardableResult
    private func runGPhoto(args: [String]) -> String {
        let paths = ["/usr/local/bin/gphoto2", "/opt/homebrew/bin/gphoto2", "/usr/bin/gphoto2"]
        guard let binary = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return "gphoto2 not found"
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = pipe
        try? proc.run(); proc.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
