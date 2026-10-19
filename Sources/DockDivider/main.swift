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
    private let accessItem = NSMenuItem(
        title: String(localized: "Allow Accessibility Access…"), action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private var isTrusted: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.addItem(accessItem)
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
        do {
            try service.status == .enabled ? service.unregister() : service.register()
        } catch {
            logger.error("Open at Login: \(error.localizedDescription, privacy: .public)")
            showError(String(localized: "Open at Login couldn't be changed."), error.localizedDescription)
        }
        item.state = service.status == .enabled ? .on : .off
    }

    // Without Accessibility the Dock can't be read and no line shows, so the menu bar icon turns
    // into a warning and the menu offers the way to System Settings until access is granted.
    private func updateAccess() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        if !trusted { logger.error("Accessibility access is missing: the Dock can't be read.") }
        accessItem.isHidden = trusted
        statusItem.button?.image =
            trusted
            ? NSImage(systemSymbolName: "poweron", accessibilityDescription: String(localized: "Dock Divider"))
            : NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: String(localized: "Dock Divider needs Accessibility access"))
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // The new spacer goes to the end of the apps; the user drags it into place.
    @objc private func addSpacer() {
        let added = run(
            "/usr/bin/defaults",
            [
                "write", "com.apple.dock", "persistent-apps", "-array-add",
                #"{"tile-type"="spacer-tile";}"#,
            ])
        if !added || !run("/usr/bin/killall", ["Dock"]) {
            showError(String(localized: "The divider couldn't be added."))
        }
    }

    private func showError(_ message: String, _ details: String = "") {
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = details
        alert.runModal()
    }

    private func speedUp() {
        tracker.speedUp()
        if timer?.timeInterval != tracker.interval() { refresh() }
    }

    private func refresh() {
        updateAccess()
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

// Whether the tool ran and exited with success.
func run(_ path: String, _ args: [String]) -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    do { try p.run() } catch {
        logger.error("\(path, privacy: .public) didn't run: \(error.localizedDescription, privacy: .public)")
        return false
    }
    p.waitUntilExit()
    if p.terminationStatus != 0 { logger.error("\(path, privacy: .public) exited with \(p.terminationStatus)") }
    return p.terminationStatus == 0
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
