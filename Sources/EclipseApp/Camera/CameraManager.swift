import Foundation
import AppKit

// MARK: - Camera Model

struct DetectedCamera: Equatable {
    let id: UUID
    let name: String
    let port: String
    let backend: CameraBackend
    var isConnected: Bool = false

    enum CameraBackend {
        case canon
        case gphoto2
        case sony
    }

    static func == (lhs: DetectedCamera, rhs: DetectedCamera) -> Bool { lhs.id == rhs.id }
}

struct ExposureSettings {
    var shutter: String
    var aperture: String
    var iso: String
}

// MARK: - Camera Manager

final class CameraManager: ObservableObject {
    static let shared = CameraManager()

    @Published var detectedCameras:   [DetectedCamera] = []
    @Published var connectedCamera:   DetectedCamera?
    @Published var liveViewImage:     NSImage?
    @Published var isLiveViewRunning = false
    @Published var statusMessage     = "Ready"
    @Published var availableShutters:  [String] = []
    @Published var availableApertures: [String] = []
    @Published var availableISOs:      [String] = []
    @Published var currentExposure = ExposureSettings(shutter: "1/500", aperture: "5.6", iso: "400")

    private var liveViewTimer: Timer?
    private let gphoto2 = GPhoto2Bridge.shared
    private let bgQueue = DispatchQueue(label: "camera.manager.bg", qos: .userInitiated)

    private init() {}

    // MARK: - Detection

    func detectCameras() {
        statusMessage = "Scanning for cameras…"
        var allCameras: [DetectedCamera] = []
        let group = DispatchGroup()

        // gphoto2 scan
        group.enter()
        gphoto2.detectCameras { cameras in
            allCameras.append(contentsOf: cameras)
            group.leave()
        }

        // Sony USB scan
        group.enter()
        SonyCameraSDKBridge.shared.detectSonyCameras { cameras in
            // Deduplicate against gphoto2 results by name
            let newCams = cameras.filter { sony in
                !allCameras.contains { $0.name.lowercased() == sony.name.lowercased() }
            }
            allCameras.append(contentsOf: newCams)
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.detectedCameras = allCameras
            self.statusMessage = allCameras.isEmpty ? "No cameras found" : "Found \(allCameras.count) camera(s)"
        }
    }

    // MARK: - Connect

    func connect(to camera: DetectedCamera) {
        statusMessage = "Connecting to \(camera.name)…"
        let connect: (@escaping (Bool) -> Void) -> Void = { [self] completion in
            switch camera.backend {
            case .sony:
                SonyCameraSDKBridge.shared.connect(port: camera.port, completion: completion)
            default:
                gphoto2.connect(port: camera.port, completion: completion)
            }
        }
        connect { [weak self] ok in
            guard let self = self else { return }
            if ok {
                var c = camera; c.isConnected = true
                self.connectedCamera = c
                self.statusMessage = "Connected: \(camera.name)"
                self.loadAvailableSettings()
            } else {
                self.statusMessage = "Failed to connect to \(camera.name)"
            }
        }
    }

    func disconnect() {
        gphoto2.disconnect()
        SonyCameraSDKBridge.shared.disconnect()
        connectedCamera = nil
        stopLiveView()
        statusMessage = "Disconnected"
    }

    // MARK: - Settings

    func loadAvailableSettings() {
        gphoto2.listConfig(key: "shutterspeed") { [weak self] in self?.availableShutters  = $0 }
        gphoto2.listConfig(key: "aperture")     { [weak self] in self?.availableApertures = $0 }
        gphoto2.listConfig(key: "iso")          { [weak self] in self?.availableISOs      = $0 }
    }

    func applyExposure(_ settings: ExposureSettings) {
        currentExposure = settings
        gphoto2.setConfig(key: "shutterspeed", value: settings.shutter)
        gphoto2.setConfig(key: "aperture",     value: settings.aperture)
        gphoto2.setConfig(key: "iso",          value: settings.iso)
    }

    // MARK: - Capture

    func singleShot() {
        guard connectedCamera != nil else { statusMessage = "No camera connected"; return }
        statusMessage = "Capturing…"
        gphoto2.triggerCapture { [weak self] ok in
            self?.statusMessage = ok ? "Captured ✓" : "Capture failed"
        }
    }

    func burst(shots: Int, intervalMs: Int = 0) {
        guard connectedCamera != nil else { return }
        statusMessage = "Burst: \(shots) shots…"
        bgQueue.async { [weak self] in
            guard let self = self else { return }
            let group = DispatchGroup()
            for i in 0..<shots {
                group.enter()
                self.gphoto2.triggerCapture { ok in
                    DispatchQueue.main.async {
                        self.statusMessage = ok ? "Burst \(i+1)/\(shots)" : "Burst shot \(i+1) failed"
                    }
                    group.leave()
                }
                group.wait()
                if intervalMs > 0 { Thread.sleep(forTimeInterval: Double(intervalMs) / 1000.0) }
            }
            DispatchQueue.main.async { self.statusMessage = "Burst complete ✓" }
        }
    }

    // MARK: - Live View

    func startLiveView() {
        guard connectedCamera != nil, !isLiveViewRunning else { return }
        isLiveViewRunning = true
        liveViewTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.gphoto2.captureLiveViewJpeg { data in
                if let data = data, let img = NSImage(data: data) {
                    self.liveViewImage = img
                }
            }
        }
        RunLoop.main.add(liveViewTimer!, forMode: .common)
    }

    func stopLiveView() {
        liveViewTimer?.invalidate()
        liveViewTimer = nil
        isLiveViewRunning = false
    }
}
