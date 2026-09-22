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
    private func model(json: String) -> AppModel {
        defaults.set(Data(json.utf8), forKey: "cloudConfig.json")
        return AppModel(
            defaults: defaults,
            cloud: CloudConfigStore(defaults: defaults, fetcher: NeverFetches(), isConfigured: true),
            telemetry: TelemetryStore(defaults: defaults, sender: NeverSends(), isConfigured: false)
        )
    }

    private func model(flags: String) -> AppModel {
        model(json: #"{"flags":\#(flags)}"#)
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

    func testUpdateCheckFlagHidesVersionUIButKeepsTheConfigUsable() {
        let off = model(json: #"""
        {
            "minSupportedVersionCode": 999,
            "update": {"versionCode": 999, "versionName": "9.9.9"},
            "notice": {"id": "n1", "body": "维护"},
            "flags": {"updateCheck": false}
        }
        """#)

        XCTAssertFalse(off.isUpdateCheckAvailable)
        XCTAssertFalse(off.mustUpgrade)
        XCTAssertNil(off.pendingUpdate)
        XCTAssertEqual(off.notice?.id, "n1", "公告仍要生效，配置读取不能被自己的开关永久关死")

        XCTAssertTrue(model(flags: #"{"updateCheck": true}"#).isUpdateCheckAvailable)
        XCTAssertTrue(model(flags: "{}").isUpdateCheckAvailable, "缺省继续保持开启")
    }

    func testRechargeFlagClosesEveryRechargeEntry() {
        let appModel = model(flags: #"{"campusCard": true, "recharge": false}"#)

        let overview = OverviewViewController(model: appModel)
        overview.loadViewIfNeeded()
        let overviewRecharge = overview.view.findAnySubview(withIdentifier: "overview.recharge")
        XCTAssertNotNil(overviewRecharge)
        XCTAssertTrue(overviewRecharge!.isHidden, "首页充值按钮必须隐藏")

        let records = RecordsViewController(model: appModel)
        records.loadViewIfNeeded()
        XCTAssertNil(records.navigationItem.rightBarButtonItem, "充值记录页也不能留下充值入口")

        let campus = CampusCardViewController(model: appModel)
        campus.loadViewIfNeeded()
        let campusRecharge = campus.view.findAnySubview(withIdentifier: "campus.recharge")
        XCTAssertNotNil(campusRecharge)
        XCTAssertTrue(campusRecharge!.isHidden, "校园卡页的学校充值入口也必须隐藏")
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

/// Same reasoning as the flag tests: the notice parses fine, but that says nothing about whether it reaches
/// the screen, survives a dismissal, or disappears when it expires.
@MainActor
final class NoticeWiringTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "notice-wiring-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private struct NeverFetches: CloudConfigFetching {
        func fetch(etag: String?) async -> CloudFetch { .notModified }
    }

    private struct NeverSends: TelemetrySending {
        func send(_ payload: TelemetryPayload) async -> Bool { false }
    }

    private func model(notice: String) -> AppModel {
        defaults.set(Data(#"{"notice":\#(notice)}"#.utf8), forKey: "cloudConfig.json")
        return AppModel(
            defaults: defaults,
            cloud: CloudConfigStore(defaults: defaults, fetcher: NeverFetches(), isConfigured: true),
            telemetry: TelemetryStore(defaults: defaults, sender: NeverSends(), isConfigured: false)
        )
    }

    private let live = #"{"id":"n1","title":"学校系统维护","body":"周六 0:00–6:00 维护","level":"warning"}"#

    func testAPublishedNoticeReachesTheModel() {
        let model = model(notice: live)
        XCTAssertEqual(model.notice?.id, "n1")
        XCTAssertEqual(model.notice?.level, .warning)
    }

    func testTheBannerIsOnScreenAndVisibleWhenANoticeIsPublished() {
        let overview = OverviewViewController(model: model(notice: live))
        overview.loadViewIfNeeded()

        let banner = overview.view.findAnySubview(ofType: NoticeBannerView.self)
        XCTAssertNotNil(banner, "公告横幅必须挂在视图树上")
        XCTAssertFalse(banner!.isHidden, "有公告时横幅不该是隐藏的")
    }

    func testTheBannerStaysHiddenWithoutANotice() {
        defaults.removeObject(forKey: "cloudConfig.json")
        let overview = OverviewViewController(model: AppModel(defaults: defaults))
        overview.loadViewIfNeeded()

        let banner = overview.view.findAnySubview(ofType: NoticeBannerView.self)
        XCTAssertTrue(banner?.isHidden ?? true, "没有公告时横幅必须隐藏")
    }

    func testDismissingHidesItAndItDoesNotComeBack() {
        let appModel = model(notice: live)
        let overview = OverviewViewController(model: appModel)
        overview.loadViewIfNeeded()
        XCTAssertFalse(overview.view.findAnySubview(ofType: NoticeBannerView.self)!.isHidden)

        appModel.dismissNotice()
        XCTAssertNil(appModel.notice)
        XCTAssertTrue(overview.view.findAnySubview(ofType: NoticeBannerView.self)!.isHidden,
                      "关闭后横幅应立即消失，而不是等下次刷新")

        // A new model over the same storage: the dismissal has to have been persisted.
        XCTAssertNil(model(notice: live).notice, "重开应用后这条公告不该再出现")
    }

    func testANoticeThatCannotBeDismissedHasNoCloseButton() {
        let sticky = model(notice: #"{"id":"n2","body":"x","dismissible":false}"#)
        XCTAssertEqual(sticky.notice?.dismissible, false)

        let overview = OverviewViewController(model: sticky)
        overview.loadViewIfNeeded()
        let banner = overview.view.findAnySubview(ofType: NoticeBannerView.self)
        let closeButton = banner?.findAnySubview(ofType: UIButton.self)
        XCTAssertNotNil(closeButton, "公告横幅应保留关闭按钮供后续公告复用")
        XCTAssertTrue(closeButton!.isHidden, "不可关闭的公告不应显示关闭按钮")

        // Dismissing one that forbids it must not hide it.
        sticky.dismissNotice()
        XCTAssertEqual(sticky.notice?.id, "n2", "不可关闭的公告不应被关掉")
    }

    func testAnExpiredNoticeNeverReachesTheScreen() {
        let expired = model(notice: #"{"id":"n3","body":"x","expiresAt":1}"#)
        XCTAssertNil(expired.notice, "过期公告不该显示")
    }
}

private extension UIView {
    /// Finds a view of the given type anywhere in the tree, hidden or not.
    func findAnySubview<T: UIView>(ofType type: T.Type) -> T? {
        if let match = self as? T { return match }
        for child in subviews {
            if let match = child.findAnySubview(ofType: type) { return match }
        }
        return nil
    }

    func findAnySubview(withIdentifier identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier { return self }
        for child in subviews {
            if let match = child.findAnySubview(withIdentifier: identifier) { return match }
        }
        return nil
    }
}
