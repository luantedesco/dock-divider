import CoreGraphics
import DockDividerCore
import Foundation
import Testing

// Main screen 1440×900. Frames are in Accessibility coordinates (origin at the top left).
private let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)

@Test func bottomDockDrawsVerticalLinesCenteredOnTheSeparator() {
    let separator = CGRect(x: 1000, y: 820, width: 10, height: 80)
    let spacer = CGRect(x: 500, y: 820, width: 30, height: 80)
    let layout = DockLayout(separator: separator, spacers: [spacer], screenHeight: 900, screensMidX: 720)

    // 72% of 80 is 57.6, rounded to 58; centered on the separator (midY 860) and flipped to AppKit.
    #expect(layout.lines == [NSRect(x: 514.5, y: 900 - 889, width: 1, height: 58)])
    #expect(layout.edge == .minY)
    #expect(layout.thickness == 80)
}

@Test func sideDockDrawsHorizontalLinesAndFindsItsEdge() {
    let left = CGRect(x: 0, y: 600, width: 80, height: 10)
    let right = CGRect(x: 1360, y: 600, width: 80, height: 10)
    let spacer = CGRect(x: 0, y: 300, width: 80, height: 30)
    let leftLayout = DockLayout(separator: left, spacers: [spacer], screenHeight: 900, screensMidX: 720)
    let rightLayout = DockLayout(separator: right, spacers: [], screenHeight: 900, screensMidX: 720)

    #expect(leftLayout.lines == [NSRect(x: 11, y: 900 - 315.5, width: 58, height: 1)])
    #expect(leftLayout.edge == .minX)
    #expect(rightLayout.edge == .maxX)
    #expect(rightLayout.lines.isEmpty)
}

@Test func nearMeansWithinTheDockThicknessPlusRoomToHide() {
    let bottom = DockLayout(lines: [], edge: .minY, thickness: 80)
    #expect(bottom.isNear(NSPoint(x: 700, y: 119), screen: screen))
    #expect(!bottom.isNear(NSPoint(x: 700, y: 120), screen: screen))

    let left = DockLayout(lines: [], edge: .minX, thickness: 60)
    #expect(left.isNear(NSPoint(x: 99, y: 400), screen: screen))
    #expect(!left.isNear(NSPoint(x: 100, y: 400), screen: screen))

    let right = DockLayout(lines: [], edge: .maxX, thickness: 60)
    #expect(right.isNear(NSPoint(x: 1341, y: 400), screen: screen))
    #expect(!right.isNear(NSPoint(x: 1340, y: 400), screen: screen))
}
