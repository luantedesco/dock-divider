import Foundation

// Where the Dock's items are. A full scan finds the items; reading the position of items already
// found costs a fourth of it.
public protocol DockReader {
    associatedtype Items
    // The Trash separator and the spacers, nil if the Dock can't be read.
    func scan() -> Items?
    // The lines over the spacers, nil if any item is gone (Dock restarted, spacer removed).
    func layout(of items: Items) -> DockLayout?
}

// When to read the Dock: 60 times a second while it moves, twice a second otherwise.
public final class DockTracker<Reader: DockReader> {
    public private(set) var layout = DockLayout(lines: [], edge: .minY, thickness: 0)
    private let reader: Reader
    private var items: Reader.Items?
    // Read at the fast rate until this date: a full Accessibility read costs ~1 ms.
    private var fastUntil = Date.distantPast

    public init(reader: Reader) {
        self.reader = reader
    }

    // The Dock is about to move: follow it for the next second.
    public func speedUp(now: Date = Date()) {
        fastUntil = now + 1
    }

    // Seconds until the next refresh.
    public func interval(now: Date = Date()) -> TimeInterval {
        now < fastUntil ? 1.0 / 60 : 0.5
    }

    // Reads the Dock and returns whether the lines moved. At the fast rate, only the position of
    // the items already found is read again; an item that is gone forces a full scan. When the
    // Dock can't be read, the lines stay where they were.
    @discardableResult
    public func refresh(now: Date = Date()) -> Bool {
        if now >= fastUntil || items == nil { items = reader.scan() }
        var next = items.flatMap(reader.layout(of:))
        if next == nil {
            items = reader.scan()
            next = items.flatMap(reader.layout(of:))
        }
        let previous = layout.lines
        layout = next ?? layout
        guard layout.lines != previous else { return false }
        fastUntil = max(fastUntil, now + 0.5)
        return true
    }
}
