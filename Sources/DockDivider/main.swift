import AppKit
import DockDividerCore
import ServiceManagement

// The dividers are the Dock's native spacers ("spacer-tile"): no icon and no tooltip.
// The app reads where each spacer is through Accessibility and draws over it a line like the
// one next to the Trash, in a transparent window that ignores clicks.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var lines: [NSWindow] = []
    private var items: DockItems?
    private var layout = DockLayout(lines: [], edge: .minY, thickness: 0)
    private var timer: Timer?
    // Refresh at 60 Hz until this date, 2 Hz otherwise: a full Accessibility read costs ~1 ms.
    private var fastUntil = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "poweron", accessibilityDescription: "Dock Divider")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Add Divider", action: #selector(addSpacer), keyEquivalent: ""))
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin(_:)), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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
            if self.layout.isNear(point, screen: screen.frame) { self.speedUp() }
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
        run("/usr/bin/defaults", ["write", "com.apple.dock", "persistent-apps", "-array-add",
                                  #"{"tile-type"="spacer-tile";}"#])
        run("/usr/bin/killall", ["Dock"])
    }

    private func speedUp() {
        fastUntil = Date() + 1
        if timer?.timeInterval != 1.0 / 60 { refresh() }
    }

    private func refresh() {
        // At the fast rate, only re-read the position of the items already found; a full scan
        // costs four times as much. An item that is gone (Dock restarted, spacer removed) forces it.
        if Date() >= fastUntil || items == nil { items = dockItems() }
        var next = items.flatMap(dockLayout(of:))
        if next == nil {
            items = dockItems()
            next = items.flatMap(dockLayout(of:))
        }
        let previous = layout
        layout = next ?? previous
        if layout.lines != previous.lines { fastUntil = max(fastUntil, Date() + 0.5) }
        let interval = Date() < fastUntil ? 1.0 / 60 : 0.5
        if timer?.timeInterval != interval {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        }

        let frames = layout.lines
        guard frames != previous.lines else { return }
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

struct DockItems {
    var separator: AXUIElement
    var spacers: [AXUIElement]
}

// The Trash separator item and the spacers, in Dock order.
func dockItems() -> DockItems? {
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
          let list = children(of: AXUIElementCreateApplication(dock.processIdentifier)).first(where: { role(of: $0) == "AXList" })
    else { return nil }
    let items = children(of: list)
    guard let separator = items.first(where: { subrole(of: $0) == "AXSeparatorDockItem" }) else { return nil }
    return DockItems(separator: separator, spacers: items.filter { subrole(of: $0) == "AXSpacerDockItem" })
}

// The lines over the spacers, nil if any item is gone.
func dockLayout(of items: DockItems) -> DockLayout? {
    let spacers = items.spacers.compactMap(frame(of:))
    guard spacers.count == items.spacers.count,
          let separator = frame(of: items.separator),
          let screenHeight = NSScreen.screens.first?.frame.height
    else { return nil }
    let screensMidX = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }.midX
    return DockLayout(separator: separator, spacers: spacers, screenHeight: screenHeight, screensMidX: screensMidX)
}

func children(of element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    return value as? [AXUIElement] ?? []
}

func role(of element: AXUIElement) -> String? { stringAttribute(kAXRoleAttribute, of: element) }
func subrole(of element: AXUIElement) -> String? { stringAttribute(kAXSubroleAttribute, of: element) }

func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value as? String
}

// Frame in Accessibility coordinates: origin at the top-left corner of the main screen.
func frame(of element: AXUIElement) -> CGRect? {
    var position: CFTypeRef?, size: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
    // CF types do not support "as?": check the type first, so the cast cannot fail.
    guard let position, let size,
          CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
    else { return nil }
    var origin = CGPoint.zero, extent = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
          AXValueGetValue(size as! AXValue, .cgSize, &extent)
    else { return nil }
    return CGRect(origin: origin, size: extent)
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
