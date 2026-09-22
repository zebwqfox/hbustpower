import XCTest
@testable import HBUSTPowerIOS

/// The promises the privacy policy makes about this, stated as tests: on by default but stopped for good the
/// moment it is switched off, the identifier deleted with it, at most one report a day, and no field beyond the
/// declared list ever leaving the device.
@MainActor
final class TelemetryTests: XCTestCase {
    private final class RecordingSender: TelemetrySending, @unchecked Sendable {
        var accept = true
        var sent: [TelemetryPayload] = []
        func send(_ payload: TelemetryPayload) async -> Bool {
            sent.append(payload)
            return accept
        }
    }

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "telemetry-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func store(_ sender: TelemetrySending, now: @escaping @Sendable () -> TimeInterval = { 1000 }) -> TelemetryStore {
        TelemetryStore(defaults: defaults, sender: sender, isConfigured: true, now: now)
    }

    func testOnByDefault() {
        let store = store(RecordingSender())
        XCTAssertTrue(store.isEnabled)
        XCTAssertTrue(store.shouldSend())
    }

    func testSwitchingItOffStopsEverythingAndItStaysOff() async {
        let sender = RecordingSender()
        let store = store(sender)
        store.isEnabled = false

        XCTAssertFalse(store.shouldSend())
        XCTAssertFalse(store.shouldSend(force: true))
        let sent = await store.report(force: true)
        XCTAssertFalse(sent)
        XCTAssertTrue(sender.sent.isEmpty)

        // A fresh store over the same defaults must not revert to the default.
        XCTAssertFalse(self.store(sender).isEnabled)
    }

    func testAnUnconfiguredBuildNeverSends() async {
        let sender = RecordingSender()
        let store = TelemetryStore(defaults: defaults, sender: sender, isConfigured: false, now: { 1000 })
        store.isEnabled = true
        XCTAssertFalse(store.shouldSend(force: true))
        let sent = await store.report(force: true)
        XCTAssertFalse(sent)
        XCTAssertTrue(sender.sent.isEmpty)
    }

    func testTurningItOffBeforeTheFirstReportMeansNoIdentifierIsEverCreated() async {
        let store = store(RecordingSender())
        store.isEnabled = false
        _ = store.previewPayload()
        _ = await store.report(force: true)
        XCTAssertNil(defaults.string(forKey: "telemetry.installId"))
    }

    func testTheIdentifierAppearsOnlyWhenAReportIsActuallyMade() async {
        let store = store(RecordingSender())
        _ = store.previewPayload()
        XCTAssertNil(defaults.string(forKey: "telemetry.installId"), "looking is not reporting")

        _ = await store.report()
        XCTAssertFalse(defaults.string(forKey: "telemetry.installId")?.isEmpty ?? true)
    }

    func testTurningItOffForgetsTheIdentifier() {
        let store = store(RecordingSender())
        let first = store.installID()

        store.isEnabled = false
        XCTAssertNil(defaults.string(forKey: "telemetry.installId"))
        XCTAssertEqual(store.lastSentAt, 0)

        store.isEnabled = true
        XCTAssertNotEqual(first, store.installID())
    }

    func testResettingGivesANewIdentifier() {
        let store = store(RecordingSender())
        let first = store.installID()
        XCTAssertNotEqual(first, store.resetInstallID())
    }

    func testAtMostOneReportADayUnlessForced() async {
        nonisolated(unsafe) var now: TimeInterval = 1000
        let sender = RecordingSender()
        let store = store(sender, now: { now })

        var sent = await store.report()
        XCTAssertTrue(sent)
        XCTAssertEqual(sender.sent.count, 1)

        now += 3600
        sent = await store.report()
        XCTAssertFalse(sent)
        XCTAssertEqual(sender.sent.count, 1, "an hour later is the same day")

        sent = await store.report(force: true)
        XCTAssertTrue(sent)
        XCTAssertEqual(sender.sent.count, 2, "the settings switch forces one immediately")

        now += TelemetryStore.interval
        sent = await store.report()
        XCTAssertTrue(sent)
        XCTAssertEqual(sender.sent.count, 3)
    }

    func testARejectedReportDoesNotCountAsSent() async {
        let sender = RecordingSender()
        sender.accept = false
        let store = store(sender)

        let sent = await store.report()
        XCTAssertFalse(sent)
        XCTAssertEqual(store.lastSentAt, 0)
        // Still due, so the next launch tries again rather than waiting a day.
        XCTAssertTrue(store.shouldSend())
    }

    func testThePayloadCarriesOnlyTheDeclaredFields() throws {
        let data = TelemetryPayload(installID: "id").jsonData()
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(
            body.keys.sorted(),
            ["appVersionCode", "appVersionName", "channel", "installId", "locale",
             "manufacturer", "model", "osVersion", "platform"]
        )
        XCTAssertEqual(body["platform"] as? String, "ios")
    }

    func testThePreviewShowsTheSameThingsThePayloadSends() {
        let labels = TelemetryPayload(installID: "id").humanReadable().map(\.0)
        XCTAssertEqual(labels, ["安装标识", "应用版本", "系统版本", "设备型号", "语言", "渠道"])
    }

    func testTheModelIdentifierLooksLikeAModelIdentifier() {
        // On the simulator this is the host arch, but it must never be empty or a placeholder.
        XCTAssertFalse(TelemetryPayload.modelIdentifier.isEmpty)
        XCTAssertNotEqual(TelemetryPayload.modelIdentifier, "unknown")
    }
}
