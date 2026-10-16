import AppKit

// As divisórias são os espaços nativos da Dock ("spacer-tile"): sem ícone e sem balão.
// O app lê pela Acessibilidade onde cada espaço está e desenha por cima uma linha igual à
// que separa a lixeira, numa janela transparente que não recebe cliques.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var lines: [NSWindow] = []
    private var items: DockItems?
    private var layout = DockLayout(lines: [], edge: .minY, thickness: 0)
    private var timer: Timer?
    // Até quando atualizar a 60 Hz. Fora disso, 2 Hz: a leitura pela Acessibilidade custa ~1 ms.
    private var fastUntil = Date.distantPast

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

        // A Dock se mexe ao aparecer, sumir ou ampliar, sempre com o cursor perto da borda dela,
        // e ao trocar de espaço (tela cheia). Nesses momentos as linhas seguem a animação.
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            if let self, self.layout.isNear(NSEvent.mouseLocation) { self.speedUp() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.speedUp() }
        refresh()
    }

    // Novo espaço vai para o fim dos apps; o usuário arrasta para a posição.
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
        // No ritmo rápido só relê a posição dos itens já achados; a varredura completa custa
        // o quádruplo. Item que sumiu (Dock reiniciada, espaço removido) força a varredura.
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
        // Mesmo tom da linha do sistema: clara no tema escuro, escura no claro.
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

// Onde está a Dock e onde desenhar as linhas, em coordenadas do AppKit.
struct DockLayout {
    var lines: [NSRect]
    var edge: NSRectEdge
    var thickness: CGFloat

    // Cursor na faixa da borda da tela em que a Dock fica, com folga para ela começar a sumir.
    func isNear(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })?.frame
        else { return false }
        let band = thickness + 40
        switch edge {
        case .minX: return point.x - screen.minX < band
        case .maxX: return screen.maxX - point.x < band
        default: return point.y - screen.minY < band
        }
    }
}

struct DockItems {
    var separator: AXUIElement
    var spacers: [AXUIElement]
}

// O item da divisória da lixeira e os espaços, na ordem da Dock.
func dockItems() -> DockItems? {
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
          let list = children(of: AXUIElementCreateApplication(dock.processIdentifier)).first(where: { role(of: $0) == "AXList" })
    else { return nil }
    let items = children(of: list)
    guard let separator = items.first(where: { subrole(of: $0) == "AXSeparatorDockItem" }) else { return nil }
    return DockItems(separator: separator, spacers: items.filter { subrole(of: $0) == "AXSpacerDockItem" })
}

// Uma linha no centro de cada espaço, cruzando a Dock. A linha do sistema ocupa ~72% da
// espessura do item da divisória, centralizada nele. Com a Dock oculta, a Acessibilidade
// informa os itens fora da tela, e as linhas ficam fora junto. Nil se algum item sumiu.
func dockLayout(of items: DockItems) -> DockLayout? {
    let spacers = items.spacers.compactMap(frame(of:))
    guard spacers.count == items.spacers.count,
          let separator = frame(of: items.separator),
          let screenHeight = NSScreen.screens.first?.frame.height
    else { return nil }

    // Na Dock de baixo o item da divisória é alto e estreito; nas laterais, largo e baixo.
    let horizontal = separator.height > separator.width
    let length = ((horizontal ? separator.height : separator.width) * 0.72).rounded()
    let lines = spacers.map { spacer in
        // Retângulo no sistema da Acessibilidade, convertido para o do AppKit (origem embaixo).
        let rect = horizontal
            ? CGRect(x: spacer.midX - 0.5, y: separator.midY - length / 2, width: 1, height: length)
            : CGRect(x: separator.midX - length / 2, y: spacer.midY - 0.5, width: length, height: 1)
        return NSRect(x: rect.minX, y: screenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
    let screensMidX = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }.midX
    let edge: NSRectEdge = horizontal ? .minY : separator.midX < screensMidX ? .minX : .maxX
    return DockLayout(lines: lines, edge: edge, thickness: horizontal ? separator.height : separator.width)
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
