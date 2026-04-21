import Foundation

// MARK: - Script Command

struct ScriptCommand: Identifiable {
    let id: UUID
    let description: String
    let phase: EclipsePhase
    let offset: TimeInterval    // seconds relative to reference time
    var referenceTime: Date?
    var absoluteTime: Date?
    let action: CameraAction

    enum EclipsePhase: String, CaseIterable {
        case preC1     = "Pre C1"
        case c1        = "C1 (Partial begins)"
        case partial1  = "Partial (C1→C2)"
        case c2        = "C2 (Totality begins)"
        case totality  = "Totality"
        case max       = "Maximum"
        case c3        = "C3 (Totality ends)"
        case partial2  = "Partial (C3→C4)"
        case c4        = "C4 (Partial ends)"
        case postC4    = "Post C4"
    }

    enum CameraAction {
        case single(ExposureSettings)
        case burst(shots: Int, exposure: ExposureSettings)
        case bracketHDR(shots: Int, stopStep: Double, baseExposure: ExposureSettings)
        case setExposure(ExposureSettings)
    }
}

// MARK: - Script Generator

final class ScriptGenerator {

    struct Config {
        var shutterPartial: String = "1/1000"
        var aperturePartial: String = "8"
        var isoPartial: String = "100"

        var shutterTotality: String = "1/500"
        var apertureTotality: String = "5.6"
        var isoTotality: String = "400"

        var shutterBaileys: String = "1/1000"
        var shutterCorona: String = "1/60"
        var shutterDiamond: String = "1/2000"

        var burstShotsBaileys: Int = 10
        var burstShotsCorona: Int = 5
        var hdrBracketStops: Int = 3
        var hdrFrames: Int = 5
    }

    static func generate(contacts: ContactTimes, config: Config) -> [ScriptCommand] {
        var commands: [ScriptCommand] = []
        let partial = ExposureSettings(shutter: config.shutterPartial,
                                       aperture: config.aperturePartial,
                                       iso: config.isoPartial)
        let totality = ExposureSettings(shutter: config.shutterTotality,
                                        aperture: config.apertureTotality,
                                        iso: config.isoTotality)
        let baileys = ExposureSettings(shutter: config.shutterBaileys,
                                       aperture: config.apertureTotality,
                                       iso: config.isoTotality)

        // ── Pre C1: test shot ──────────────────────────────────────────
        if let c1 = contacts.c1 {
            commands.append(ScriptCommand(id: UUID(), description: "Test shot (5 min before C1)",
                phase: .preC1, offset: -300, referenceTime: c1,
                absoluteTime: c1.addingTimeInterval(-300),
                action: .single(partial)))

            // ── C1 ─────────────────────────────────────────────────────
            commands.append(ScriptCommand(id: UUID(), description: "C1 — Partial begins",
                phase: .c1, offset: 0, referenceTime: c1, absoluteTime: c1,
                action: .single(partial)))

            // Partial phase shots every 5 min
            if let c2 = contacts.c2 {
                let duration = c2.timeIntervalSince(c1)
                let steps = max(1, Int(duration / 300))
                for i in 1..<steps {
                    let t = c1.addingTimeInterval(Double(i) * 300)
                    commands.append(ScriptCommand(id: UUID(),
                        description: "Partial phase (\(i*5) min after C1)",
                        phase: .partial1, offset: Double(i) * 300,
                        referenceTime: c1, absoluteTime: t,
                        action: .single(partial)))
                }
            }
        }

        // ── C2: Bailey's Beads burst ───────────────────────────────────
        if let c2 = contacts.c2 {
            commands.append(ScriptCommand(id: UUID(), description: "Bailey's Beads burst (10s before C2)",
                phase: .c2, offset: -10, referenceTime: c2,
                absoluteTime: c2.addingTimeInterval(-10),
                action: .burst(shots: config.burstShotsBaileys, exposure: baileys)))

            commands.append(ScriptCommand(id: UUID(), description: "C2 — Totality begins",
                phase: .c2, offset: 0, referenceTime: c2, absoluteTime: c2,
                action: .single(totality)))
        }

        // ── Totality: HDR corona sequence ─────────────────────────────
        if let max = contacts.max {
            // HDR bracket at max
            commands.append(ScriptCommand(id: UUID(), description: "Corona HDR bracket at MAX",
                phase: .max, offset: 0, referenceTime: max, absoluteTime: max,
                action: .bracketHDR(shots: config.hdrFrames,
                                    stopStep: Double(config.hdrBracketStops),
                                    baseExposure: totality)))

            // Single shots around max
            let coronaExp = ExposureSettings(shutter: config.shutterCorona,
                                              aperture: config.apertureTotality,
                                              iso: config.isoTotality)
            commands.append(ScriptCommand(id: UUID(), description: "Corona wide shot",
                phase: .totality, offset: -15, referenceTime: max,
                absoluteTime: max.addingTimeInterval(-15),
                action: .single(coronaExp)))
        }

        // ── C3: Bailey's Beads burst ───────────────────────────────────
        if let c3 = contacts.c3 {
            let diamondExp = ExposureSettings(shutter: config.shutterDiamond,
                                               aperture: config.apertureTotality,
                                               iso: config.isoTotality)
            commands.append(ScriptCommand(id: UUID(), description: "Diamond ring (C3)",
                phase: .c3, offset: 0, referenceTime: c3, absoluteTime: c3,
                action: .single(diamondExp)))

            commands.append(ScriptCommand(id: UUID(), description: "Bailey's Beads burst (C3 +5s)",
                phase: .c3, offset: 5, referenceTime: c3,
                absoluteTime: c3.addingTimeInterval(5),
                action: .burst(shots: config.burstShotsBaileys, exposure: baileys)))
        }

        // ── Post C4 ────────────────────────────────────────────────────
        if let c4 = contacts.c4 {
            commands.append(ScriptCommand(id: UUID(), description: "Final partial shot (C4)",
                phase: .c4, offset: 0, referenceTime: c4, absoluteTime: c4,
                action: .single(partial)))
        }

        return commands.sorted { ($0.absoluteTime ?? .distantPast) < ($1.absoluteTime ?? .distantPast) }
    }
}

// MARK: - Script Executor

final class ScriptExecutor: ObservableObject {
    @Published var isRunning = false
    @Published var currentCommandIndex: Int = -1
    @Published var statusLog: [String] = []

    private var cancelled = false
    private let bgQueue = DispatchQueue(label: "script.executor", qos: .userInitiated)

    func run(script: [ScriptCommand]) {
        guard !isRunning else { return }
        isRunning = true
        cancelled = false
        statusLog = []
        currentCommandIndex = 0

        bgQueue.async { [weak self] in
            for (i, cmd) in script.enumerated() {
                guard let self = self, !self.cancelled else { break }

                if let fire = cmd.absoluteTime {
                    let wait = fire.timeIntervalSinceNow
                    if wait > 0 {
                        DispatchQueue.main.async { self.statusLog.append("⏳ Waiting for \(cmd.description)") }
                        Thread.sleep(forTimeInterval: wait)
                    }
                }
                guard !self.cancelled else { break }
                DispatchQueue.main.async {
                    self.currentCommandIndex = i
                    self.statusLog.append("▶ \(cmd.description)")
                }
                self.executeCommand(cmd)
            }
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.statusLog.append("✅ Script complete")
            }
        }
    }

    func stop() {
        cancelled = true
        isRunning = false
        statusLog.append("⏹ Stopped")
    }

    private func executeCommand(_ cmd: ScriptCommand) {
        let cam = CameraManager.shared
        switch cmd.action {
        case .single(let exp):
            DispatchQueue.main.sync { cam.applyExposure(exp) }
            Thread.sleep(forTimeInterval: 0.1)
            DispatchQueue.main.sync { cam.singleShot() }
        case .burst(let shots, let exp):
            DispatchQueue.main.sync { cam.applyExposure(exp) }
            Thread.sleep(forTimeInterval: 0.1)
            DispatchQueue.main.sync { cam.burst(shots: shots, intervalMs: 0) }
        case .bracketHDR(let shots, let stops, let base):
            let shutterValues = hdrShutterValues(base: base.shutter, steps: shots, stops: stops)
            for sv in shutterValues {
                let exp = ExposureSettings(shutter: sv, aperture: base.aperture, iso: base.iso)
                DispatchQueue.main.sync { cam.applyExposure(exp) }
                Thread.sleep(forTimeInterval: 0.08)
                DispatchQueue.main.sync { cam.singleShot() }
                Thread.sleep(forTimeInterval: 0.2)
            }
        case .setExposure(let exp):
            DispatchQueue.main.sync { cam.applyExposure(exp) }
        }
    }

    private func hdrShutterValues(base: String, steps: Int, stops: Double) -> [String] {
        let presets = ["1/4000","1/2000","1/1000","1/500","1/250","1/125","1/60","1/30","1/15","1/8","1/4","1/2","1"]
        guard let baseIdx = presets.firstIndex(of: base) else { return Array(repeating: base, count: steps) }
        let half = steps / 2
        let stepIdx = max(1, Int(stops))
        return (0..<steps).map { i in
            let offset = (i - half) * stepIdx
            let idx = max(0, min(presets.count - 1, baseIdx + offset))
            return presets[idx]
        }
    }
}
