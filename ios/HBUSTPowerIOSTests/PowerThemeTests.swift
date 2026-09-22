import XCTest
@testable import HBUSTPowerIOS

@MainActor
final class PowerThemeTests: XCTestCase {
    func testEveryThemeIsDistinctAndDescribed() {
        let styles = PowerThemeStyle.allCases
        XCTAssertEqual(styles.count, 3)
        XCTAssertEqual(Set(styles.map(\.rawValue)).count, styles.count)
        XCTAssertEqual(Set(styles.map(\.name)).count, styles.count)
        for style in styles {
            XCTAssertFalse(style.name.isEmpty)
            XCTAssertFalse(style.tagline.isEmpty)
            XCTAssertFalse(style.greeting.isEmpty)
            XCTAssertFalse(style.chargingLine.isEmpty)
            XCTAssertFalse(UIImage(systemName: style.symbol) == nil, style.symbol)
        }
        // The friends' themes say where the colours come from; the default one has nothing to credit.
        XCTAssertNil(PowerThemeStyle.classic.credit)
        XCTAssertNotNil(PowerThemeStyle.purpleBird.credit)
        XCTAssertNotNil(PowerThemeStyle.mapleYellow.credit)
    }

    func testThemesUseDifferentAccentsInBothAppearances() {
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: appearance)
            let accents = PowerThemeStyle.allCases.map { $0.accent.resolvedColor(with: traits) }
            XCTAssertEqual(Set(accents).count, accents.count, "accents must differ in \(appearance)")
        }
    }

    func testStoreRemembersTheChoiceAndAnnouncesIt() {
        let suite = "theme.test." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PowerThemeStore(defaults: defaults)
        XCTAssertEqual(store.style, .classic)

        expectation(forNotification: PowerThemeStore.didChange, object: store)
        store.select(.purpleBird)
        waitForExpectations(timeout: 1)
        XCTAssertEqual(store.style, .purpleBird)
        XCTAssertEqual(PowerThemeStore(defaults: defaults).style, .purpleBird)
    }

    func testStrayBirdsLinesAreAttributedAndCycle() {
        XCTAssertTrue(StrayBirds.attribution.contains("飞鸟集"))
        XCTAssertGreaterThanOrEqual(StrayBirds.lines.count, 10)
        XCTAssertEqual(Set(StrayBirds.lines).count, StrayBirds.lines.count)
        XCTAssertEqual(StrayBirds.line(after: StrayBirds.lines[0]), StrayBirds.lines[1])
        XCTAssertEqual(StrayBirds.line(after: StrayBirds.lines.last!), StrayBirds.lines[0])
    }
}
