import AppKit
import DockDividerCore

// Reads the Dock's items through the Accessibility API.
struct AccessibilityDockReader: DockReader {
    struct Items {
        var separator: AXUIElement
        var spacers: [AXUIElement]
    }

    // The Trash separator item and the spacers, in Dock order.
    func scan() -> Items? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
            let list = children(of: AXUIElementCreateApplication(dock.processIdentifier)).first(where: { role(of: $0) == "AXList" })
        else { return nil }
        let items = children(of: list)
        guard let separator = items.first(where: { subrole(of: $0) == "AXSeparatorDockItem" }) else { return nil }
        return Items(separator: separator, spacers: items.filter { subrole(of: $0) == "AXSpacerDockItem" })
    }

    func layout(of items: Items) -> DockLayout? {
        let spacers = items.spacers.compactMap(frame(of:))
        guard spacers.count == items.spacers.count,
            let separator = frame(of: items.separator),
            let screenHeight = NSScreen.screens.first?.frame.height
        else { return nil }
        let screensMidX = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }.midX
        return DockLayout(separator: separator, spacers: spacers, screenHeight: screenHeight, screensMidX: screensMidX)
    }
}

private func children(of element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    return value as? [AXUIElement] ?? []
}

private func role(of element: AXUIElement) -> String? { stringAttribute(kAXRoleAttribute, of: element) }
private func subrole(of element: AXUIElement) -> String? { stringAttribute(kAXSubroleAttribute, of: element) }

private func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value as? String
}

// Frame in Accessibility coordinates: origin at the top-left corner of the main screen.
private func frame(of element: AXUIElement) -> CGRect? {
    var position: CFTypeRef?
    var size: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
    // CF types do not support "as?": check the type first, so the cast cannot fail.
    guard let position, let size,
        CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
    else { return nil }
    var origin = CGPoint.zero
    var extent = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
    else { return nil }
    return CGRect(origin: origin, size: extent)
}
