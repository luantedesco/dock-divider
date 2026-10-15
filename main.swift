import AppKit

// As divisórias são os espaços nativos da Dock ("spacer-tile"): sem ícone e sem balão.
// O app lê pela Acessibilidade onde cada espaço está e desenha por cima uma linha igual à
// que separa a lixeira, numa janela transparente que não recebe cliques.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var lines: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "poweron", accessibilityDescription: "Dock Divider")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Add Divider", action: #selector(addSpacer), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    // Novo espaço vai para o fim dos apps; o usuário arrasta para a posição.
    @objc private func addSpacer() {
        run("/usr/bin/defaults", ["write", "com.apple.dock", "persistent-apps", "-array-add",
                                  #"{"tile-type"="spacer-tile";}"#])
        run("/usr/bin/killall", ["Dock"])
    }

    private func refresh() {
        let frames = dockSpacerLineFrames()
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
        window.backgroundColor = NSColor(white: 1, alpha: 0.33)
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return window
    }
}

// Retângulos, em coordenadas do AppKit, das linhas a desenhar: uma no centro de cada espaço.
// A linha do sistema ocupa ~72% da altura do item da divisória, centralizada nele.
func dockSpacerLineFrames() -> [NSRect] {
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
          let list = children(of: AXUIElementCreateApplication(dock.processIdentifier)).first(where: { role(of: $0) == "AXList" })
    else { return [] }

    let items = children(of: list)
    let spacers = items.filter { subrole(of: $0) == "AXSpacerDockItem" }.compactMap(frame(of:))
    guard let separator = items.first(where: { subrole(of: $0) == "AXSeparatorDockItem" }).flatMap(frame(of:)),
          let screenHeight = NSScreen.screens.first?.frame.height
    else { return [] }

    let width = 1.0, height = (separator.height * 0.72).rounded()
    let y = screenHeight - separator.maxY + (separator.height - height) / 2
    return spacers.map { spacer in
        NSRect(x: spacer.midX - width / 2, y: y, width: width, height: height)
    }
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

// Frame no sistema da Acessibilidade: origem no canto superior esquerdo da tela principal.
func frame(of element: AXUIElement) -> CGRect? {
    var position: CFTypeRef?, size: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
    // Tipos CF não aceitam "as?": confere o tipo antes, e a conversão deixa de poder falhar.
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
