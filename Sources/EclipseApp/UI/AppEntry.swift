import Cocoa

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Design System (Dark Mode per WildnetEdge best practices)
// ═══════════════════════════════════════════════════════════════════════════
// Background layers: #0D0D0D → #121212 → #1A1A1A → #242424
// Text: #E0E0E0 primary, #B0B0B0 secondary, #808080 tertiary
// Accent primary: #3A7BD5 (muted blue)   Accent warm: #FF6F61 (coral)
// Accent eclipse: #F5C518 (golden)       Success: #4ADE80
// Contrast ratios: all ≥4.5:1 on dark backgrounds (WCAG AA)
// ═══════════════════════════════════════════════════════════════════════════

struct Theme {
    // Surface layers (avoid pure black — use dark gray per article)
    static let bg0       = NSColor(red: 0.051, green: 0.051, blue: 0.059, alpha: 1) // #0D0D0F
    static let bg1       = NSColor(red: 0.071, green: 0.071, blue: 0.082, alpha: 1) // #121215
    static let bg2       = NSColor(red: 0.102, green: 0.102, blue: 0.118, alpha: 1) // #1A1A1E
    static let bg3       = NSColor(red: 0.141, green: 0.141, blue: 0.161, alpha: 1) // #242429

    // Text (soft whites — never pure #FFF)
    static let textPrimary   = NSColor(red: 0.878, green: 0.878, blue: 0.898, alpha: 1) // #E0E0E5
    static let textSecondary = NSColor(red: 0.690, green: 0.690, blue: 0.722, alpha: 1) // #B0B0B8
    static let textTertiary  = NSColor(red: 0.502, green: 0.502, blue: 0.541, alpha: 1) // #80808A

    // Accents
    static let accentBlue    = NSColor(red: 0.227, green: 0.482, blue: 0.835, alpha: 1) // #3A7BD5
    static let accentCoral   = NSColor(red: 1.000, green: 0.435, blue: 0.380, alpha: 1) // #FF6F61
    static let accentGold    = NSColor(red: 0.961, green: 0.773, blue: 0.094, alpha: 1) // #F5C518
    static let accentGreen   = NSColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1) // #4ADE80
    static let accentPurple  = NSColor(red: 0.608, green: 0.502, blue: 1.000, alpha: 1) // #9B80FF

    // Borders & Dividers
    static let border        = NSColor(white: 0.18, alpha: 1)
    static let borderSubtle  = NSColor(white: 0.12, alpha: 1)
    static let divider       = NSColor(white: 0.15, alpha: 0.6)

    // Radii
    static let cornerSm: CGFloat = 6
    static let cornerMd: CGFloat = 10
    static let cornerLg: CGFloat = 14

    // Fonts
    static func mono(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }
    static func body(_ size: CGFloat, bold: Bool = false) -> NSFont {
        bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        makeWindow()
    }

    private func makeWindow() {
        let vc = MainWindowController()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1360, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Eclipse Mission Control"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.bg0
        window.contentViewController = vc
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        window.minSize = NSSize(width: 960, height: 680)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { window?.makeKeyAndOrderFront(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
