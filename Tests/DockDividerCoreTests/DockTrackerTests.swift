import CoreGraphics
import DockDividerCore
import Foundation
import Testing

// A bottom Dock with one spacer. A scan hands out the Dock's current generation; a restart starts
// a new one, and the items of the old one are gone.
private final class FakeDock: DockReader {
    var spacerX: CGFloat = 500
    var isRunning = true
    var generation = 1
    var scans = 0

    func scan() -> Int? {
        scans += 1
        return isRunning ? generation : nil
    }

    func layout(of items: Int) -> DockLayout? {
        guard isRunning, items == generation else { return nil }
        return DockLayout(
            separator: CGRect(x: 1000, y: 820, width: 10, height: 80),
            spacers: [CGRect(x: spacerX, y: 820, width: 30, height: 80)], screenHeight: 900, screensMidX: 720)
    }
}

private let start = Date(timeIntervalSinceReferenceDate: 0)

@Test func firstRefreshScansAndDrawsTheLines() {
    let dock = FakeDock()
    let tracker = DockTracker(reader: dock)

    #expect(tracker.refresh(now: start))
    #expect(tracker.layout.lines.map(\.midX) == [515])
    #expect(dock.scans == 1)
}

@Test func linesThatMovedKeepTheFastRateForHalfASecond() {
    let tracker = DockTracker(reader: FakeDock())
    tracker.refresh(now: start)

    #expect(tracker.interval(now: start + 0.4) == 1.0 / 60)
    #expect(tracker.interval(now: start + 0.5) == 0.5)
}

@Test func atTheSlowRateEveryRefreshScansTheDockAgain() {
    let dock = FakeDock()
    let tracker = DockTracker(reader: dock)
    tracker.refresh(now: start)

    #expect(!tracker.refresh(now: start + 1))
    #expect(dock.scans == 2)
}

@Test func whileTheDockMovesOnlyThePositionsAreReadAgain() {
    let dock = FakeDock()
    let tracker = DockTracker(reader: dock)
    tracker.refresh(now: start)
    tracker.speedUp(now: start + 1)
    dock.spacerX = 600

    #expect(tracker.interval(now: start + 1) == 1.0 / 60)
    #expect(tracker.refresh(now: start + 1.1))
    #expect(tracker.layout.lines.map(\.midX) == [615])
    #expect(dock.scans == 1)
}

@Test func aRestartedDockIsScannedAgainEvenAtTheFastRate() {
    let dock = FakeDock()
    let tracker = DockTracker(reader: dock)
    tracker.refresh(now: start)
    tracker.speedUp(now: start + 1)
    dock.generation += 1

    tracker.refresh(now: start + 1.1)

    #expect(dock.scans == 2)
    #expect(tracker.layout.lines.count == 1)
}

@Test func linesStayWhereTheyWereWhileTheDockCantBeRead() {
    let dock = FakeDock()
    let tracker = DockTracker(reader: dock)
    tracker.refresh(now: start)
    dock.isRunning = false

    #expect(!tracker.refresh(now: start + 1))
    #expect(tracker.layout.lines.map(\.midX) == [515])
}
