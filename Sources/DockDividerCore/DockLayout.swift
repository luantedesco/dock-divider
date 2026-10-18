import CoreGraphics
import Foundation

// Where the Dock is and where to draw the lines, in AppKit coordinates.
public struct DockLayout {
    public var lines: [NSRect]
    public var edge: NSRectEdge
    public var thickness: CGFloat

    public init(lines: [NSRect], edge: NSRectEdge, thickness: CGFloat) {
        self.lines = lines
        self.edge = edge
        self.thickness = thickness
    }

    // One line at the center of each spacer, across the Dock. The system line spans ~72% of the
    // separator item's thickness, centered on it. With the Dock hidden, Accessibility reports the
    // items off screen, and the lines go off screen with them.
    // Frames are in Accessibility coordinates (origin at the top-left corner of the main screen);
    // screenHeight is the main screen's height and screensMidX the middle of all screens together.
    public init(separator: CGRect, spacers: [CGRect], screenHeight: CGFloat, screensMidX: CGFloat) {
        // On a bottom Dock the separator item is tall and narrow; on a side Dock, wide and short.
        let horizontal = separator.height > separator.width
        let length = ((horizontal ? separator.height : separator.width) * 0.72).rounded()
        lines = spacers.map { spacer in
            // Rect in Accessibility coordinates, converted to AppKit's (origin at the bottom).
            let rect = horizontal
                ? CGRect(x: spacer.midX - 0.5, y: separator.midY - length / 2, width: 1, height: length)
                : CGRect(x: separator.midX - length / 2, y: spacer.midY - 0.5, width: length, height: 1)
            return NSRect(x: rect.minX, y: screenHeight - rect.maxY, width: rect.width, height: rect.height)
        }
        edge = horizontal ? .minY : separator.midX < screensMidX ? .minX : .maxX
        thickness = horizontal ? separator.height : separator.width
    }

    // Cursor within the band along the Dock's screen edge, with room for the Dock to start hiding.
    // screen is the frame of the screen the cursor is on.
    public func isNear(_ point: NSPoint, screen: NSRect) -> Bool {
        let band = thickness + 40
        switch edge {
        case .minX: return point.x - screen.minX < band
        case .maxX: return screen.maxX - point.x < band
        default: return point.y - screen.minY < band
        }
    }
}
