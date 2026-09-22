import XCTest
@testable import HBUSTPowerIOS

/// Parsing a flag correctly is worthless if nothing reads it. These tests exist because `isFeatureEnabled`
/// once shipped with zero callers on iOS: every case-for-case parser test passed, and turning `campusCard`
/// off in the panel changed nothing on the phone.
///
/// So these assert the *wiring*: that a switched-off flag actually reaches the screen.
@MainActor
final class FeatureFlagWiringTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "flag-wiring-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Seeds the cache the way a completed fetch would, so the model picks it up when it is created.
    private func model(flags: String) -> AppModel {
        let json = #"{"flags":\#(flags)}"#
        defaults.set(Data(json.utf8), forKey: "cloudConfig.json")
        return AppModel(
            defaults: defaults,
            cloud: CloudConfigStore(defaults: defaults, fetcher: NeverFetches(), isConfigured: true),
            telemetry: TelemetryStore(defaults: defaults, sender: NeverSends(), isConfigured: false)
        )
    }

    private struct NeverFetches: CloudConfigFetching {
        func fetch(etag: String?) async -> CloudFetch { .notModified }
    }

    private struct NeverSends: TelemetrySending {
        func send(_ payload: TelemetryPayload) async -> Bool { false }
    }

    func testModelReadsFlagsFromTheCachedConfig() {
        XCTAssertFalse(model(flags: #"{"campusCard": false}"#).isFeatureEnabled(CloudConfig.flagCampusCard))
        XCTAssertTrue(model(flags: #"{"campusCard": true}"#).isFeatureEnabled(CloudConfig.flagCampusCard))
        // Never published, and no config at all: both leave the feature on.
        XCTAssertTrue(model(flags: "{}").isFeatureEnabled(CloudConfig.flagCampusCard))
        XCTAssertTrue(AppModel(defaults: defaults).isFeatureEnabled(CloudConfig.flagCampusCard))
    }

    func testCampusCardScreenHidesItselfWhenTheFlagIsOff() {
        let off = CampusCardViewController(model: model(flags: #"{"campusCard": false}"#))
        off.loadViewIfNeeded()
        off.beginAppearanceTransition(true, animated: false)
        off.endAppearanceTransition()

        let unavailable = off.view.findSubview(ofType: FeatureUnavailableView.self)
        XCTAssertNotNil(unavailable, "关闭后应显示“暂时不可用”")
        XCTAssertFalse(unavailable!.isHidden)
        XCTAssertNil(off.view.findSubview(withIdentifier: "campus.balance"),
                     "关闭后余额卡不该还显示着")
    }

    func testCampusCardScreenIsNormalWhenTheFlagIsOn() {
        let on = CampusCardViewController(model: model(flags: #"{"campusCard": true}"#))
        on.loadViewIfNeeded()
        on.beginAppearanceTransition(true, animated: false)
        on.endAppearanceTransition()

        XCTAssertNotNil(on.view.findSubview(withIdentifier: "campus.balance"))
        let unavailable = on.view.findSubview(ofType: FeatureUnavailableView.self)
        XCTAssertTrue(unavailable?.isHidden ?? true, "没关闭时不该出现“暂时不可用”")
    }
}

private extension UIView {
    /// Walks the whole tree, skipping hidden branches only when asked, because a hidden ancestor is exactly
    /// what these tests are checking for.
    func findSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let match = self as? T { return match }
        for child in subviews {
            if let match = child.findSubview(ofType: type) { return match }
        }
        return nil
    }

    /// Returns the view only when it and every ancestor up to here are visible.
    func findSubview(withIdentifier identifier: String) -> UIView? {
        if isHidden { return nil }
        if accessibilityIdentifier == identifier { return self }
        for child in subviews {
            if let match = child.findSubview(withIdentifier: identifier) { return match }
        }
        return nil
    }
}
