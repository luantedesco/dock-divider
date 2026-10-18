import AppKit
import DockDividerCore
import ServiceManagement

// The dividers are the Dock's native spacers ("spacer-tile"): no icon and no tooltip.
// The app reads where each spacer is through Accessibility and draws over it a line like the
// one next to the Trash, in a transparent window that ignores clicks.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var lines: [NSWindow] = []
    private let tracker = DockTracker(reader: AccessibilityDockReader())
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "poweron", accessibilityDescription: String(localized: "Dock Divider"))
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: String(localized: "Add Divider"), action: #selector(addSpacer), keyEquivalent: ""))
        let login = NSMenuItem(title: String(localized: "Open at Login"), action: #selector(toggleOpenAtLogin(_:)), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)

        // The Dock moves when it shows, hides, or magnifies, always with the cursor near its edge,
        // and when the Space changes (full screen). The lines follow the animation then.
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            let point = NSEvent.mouseLocation
            guard let self,
                let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
            else { return }
            if self.tracker.layout.isNear(point, screen: screen.frame) { self.speedUp() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.speedUp() }
        refresh()
    }

    @objc private func toggleOpenAtLogin(_ item: NSMenuItem) {
        let service = SMAppService.mainApp
        try? service.status == .enabled ? service.unregister() : service.register()
        item.state = service.status == .enabled ? .on : .off
    }

    // The new spacer goes to the end of the apps; the user drags it into place.
    @objc private func addSpacer() {
        run(
            "/usr/bin/defaults",
            [
                "write", "com.apple.dock", "persistent-apps", "-array-add",
                #"{"tile-type"="spacer-tile";}"#,
            ])
        run("/usr/bin/killall", ["Dock"])
    }

    private func speedUp() {
        tracker.speedUp()
        if timer?.timeInterval != tracker.interval() { refresh() }
    }

    private func refresh() {
        let moved = tracker.refresh()
        let interval = tracker.interval()
        if timer?.timeInterval != interval {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        }

        guard moved else { return }
        let frames = tracker.layout.lines
        while lines.count < frames.count { lines.append(makeLineWindow()) }
        for (i, window) in lines.enumerated() {
            if i < frames.count {
                window.setFrame(frames[i], display: true)
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
        }
    }

    private func makeLineWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        // Same tone as the system line: light in dark mode, dark in light mode.
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.33) : NSColor(white: 0, alpha: 0.4)
        }
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return window
    }
}

func run(_ path: String, _ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
