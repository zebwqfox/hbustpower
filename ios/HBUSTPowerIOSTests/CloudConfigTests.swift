import XCTest
@testable import HBUSTPowerIOS

/// The config comes off the network, so the parser has to survive whatever arrives: truncated files, fields of
/// the wrong type, a newer publisher writing keys this build has never heard of, and a download link pointing
/// somewhere it should not.
///
/// These mirror `android/.../CloudConfigTest.kt` case for case; the two parsers must not drift.
final class CloudConfigTests: XCTestCase {
    private let hosts = ["example.com", "dl.example.com"]

    private let full = """
    {
      "publishedAt": "2026-09-22",
      "minSupportedVersionCode": 180,
      "update": {
        "versionCode": 200,
        "versionName": "2.0.0",
        "notes": ["修了空调用量", "  ", "新增检查更新"],
        "downloadUrl": "https://dl.example.com/a.ipa",
        "sha256": "\(String(repeating: "a", count: 64))",
        "sizeBytes": 9437184
      },
      "notice": {
        "id": "n1", "title": "维护", "body": "周六维护", "level": "warning", "expiresAt": 2000
      },
      "flags": { "campusCard": false, "recharge": true }
    }
    """

    func testReadsEveryField() {
        let config = CloudConfig.parse(json: full, trustedDownloadHosts: hosts)
        XCTAssertEqual(config.publishedAt, "2026-09-22")
        XCTAssertEqual(config.minSupportedVersionCode, 180)
        let update = try! XCTUnwrap(config.update)
        XCTAssertEqual(update.versionCode, 200)
        XCTAssertEqual(update.versionName, "2.0.0")
        // Blank entries in notes would render as empty bullets.
        XCTAssertEqual(update.notes, ["修了空调用量", "新增检查更新"])
        XCTAssertEqual(update.downloadURL?.absoluteString, "https://dl.example.com/a.ipa")
        XCTAssertEqual(update.sizeBytes, 9_437_184)
        XCTAssertEqual(config.notice?.level, .warning)
    }

    func testMalformedInputNeverThrows() {
        for input in ["", "   ", "not json", "[]", "{", #"{"update": 5}"#, #"{"notice": "hello"}"#] {
            XCTAssertEqual(CloudConfig.parse(json: input, trustedDownloadHosts: hosts), .empty, "input: \(input)")
        }
    }

    func testUnknownKeysAreIgnoredSoANewerFileStillWorks() {
        let config = CloudConfig.parse(
            json: #"{"update":{"versionCode":200,"versionName":"2.0.0","rolloutPercent":50},"newSection":{"a":1}}"#,
            trustedDownloadHosts: hosts
        )
        XCTAssertEqual(config.update?.versionCode, 200)
    }

    func testUpdateWithoutAUsableVersionIsDropped() {
        XCTAssertNil(CloudConfig.parse(json: #"{"update":{"versionName":"2.0.0"}}"#, trustedDownloadHosts: hosts).update)
        XCTAssertNil(CloudConfig.parse(json: #"{"update":{"versionCode":200}}"#, trustedDownloadHosts: hosts).update)
        XCTAssertNil(CloudConfig.parse(json: #"{"update":{"versionCode":0,"versionName":"x"}}"#, trustedDownloadHosts: hosts).update)
    }

    func testOnlyANewerUpdateIsOffered() {
        let config = CloudConfig.parse(json: full, trustedDownloadHosts: hosts)
        XCTAssertNil(config.updateAvailable(currentVersionCode: 200))
        XCTAssertNil(config.updateAvailable(currentVersionCode: 201))
        XCTAssertEqual(config.updateAvailable(currentVersionCode: 199)?.versionCode, 200)
    }

    func testMustUpgradeOnlyFiresBelowThePublishedFloor() {
        let config = CloudConfig.parse(json: full, trustedDownloadHosts: hosts)
        XCTAssertTrue(config.mustUpgrade(currentVersionCode: 179))
        XCTAssertFalse(config.mustUpgrade(currentVersionCode: 180))
        // Without a floor the app never tells anyone to upgrade.
        let noFloor = CloudConfig.parse(json: #"{"update":{"versionCode":200,"versionName":"x"}}"#, trustedDownloadHosts: hosts)
        XCTAssertFalse(noFloor.mustUpgrade(currentVersionCode: 1))
    }

    func testDownloadLinksOffTheAllowedHostsAreDropped() {
        let rejected = [
            "http://dl.example.com/a.ipa",           // not HTTPS
            "https://evil.com/a.ipa",                // wrong host
            "https://dl.example.com.evil.com/a.ipa", // suffix that only looks right
            "https://notexample.com/a.ipa",          // must match on a dot boundary
            "https://user@dl.example.com/a.ipa",     // credentials in the authority
            "ftp://dl.example.com/a.ipa",
            "javascript:alert(1)",
            "/a.ipa",
            "",
        ]
        for url in rejected {
            XCTAssertNil(CloudConfig.trustedDownload(url, trustedHosts: hosts), "should reject: \(url)")
            let config = CloudConfig.parse(
                json: #"{"update":{"versionCode":9,"versionName":"x","downloadUrl":"\#(url)"}}"#,
                trustedDownloadHosts: hosts
            )
            XCTAssertNil(config.update?.downloadURL, "should drop: \(url)")
        }
        XCTAssertNotNil(CloudConfig.trustedDownload("https://example.com/a.ipa", trustedHosts: hosts))
        XCTAssertNotNil(CloudConfig.trustedDownload("https://cdn.dl.example.com/a.ipa", trustedHosts: hosts))
    }

    func testNoAllowedHostsMeansNoDownloadLinkAtAll() {
        XCTAssertNil(CloudConfig.trustedDownload("https://dl.example.com/a.ipa", trustedHosts: []))
    }

    func testABadSHA256IsDroppedRatherThanShown() {
        func sha(_ value: String) -> String? {
            CloudConfig.parse(
                json: #"{"update":{"versionCode":9,"versionName":"x","sha256":"\#(value)"}}"#,
                trustedDownloadHosts: hosts
            ).update?.sha256
        }
        XCTAssertNil(sha("abc"))
        XCTAssertNil(sha(String(repeating: "z", count: 64)))
        XCTAssertEqual(sha(String(repeating: "A", count: 64)), String(repeating: "a", count: 64))
    }

    func testANoticeExpiresOnItsOwn() {
        let config = CloudConfig.parse(json: full, trustedDownloadHosts: hosts)
        XCTAssertEqual(config.activeNotice(now: 1999, dismissedIDs: [])?.id, "n1")
        XCTAssertNil(config.activeNotice(now: 2000, dismissedIDs: []))
        XCTAssertNil(config.activeNotice(now: 5000, dismissedIDs: []))
    }

    func testADismissedNoticeStaysGoneUnlessItIsNotDismissible() {
        let config = CloudConfig.parse(json: full, trustedDownloadHosts: hosts)
        XCTAssertNil(config.activeNotice(now: 100, dismissedIDs: ["n1"]))
        let sticky = CloudConfig.parse(json: #"{"notice":{"id":"n1","body":"x","dismissible":false}}"#, trustedDownloadHosts: hosts)
        XCTAssertEqual(sticky.activeNotice(now: 100, dismissedIDs: ["n1"])?.id, "n1")
    }

    func testANoticeWithoutAnIDOrBodyIsDropped() {
        XCTAssertNil(CloudConfig.parse(json: #"{"notice":{"body":"x"}}"#, trustedDownloadHosts: hosts).notice)
        XCTAssertNil(CloudConfig.parse(json: #"{"notice":{"id":"n1"}}"#, trustedDownloadHosts: hosts).notice)
        XCTAssertNil(CloudConfig.parse(json: #"{"notice":{"id":" ","body":"x"}}"#, trustedDownloadHosts: hosts).notice)
    }

    func testFlagsFailOpen() {
        let config = CloudConfig.parse(json: full, trustedDownloadHosts: hosts)
        XCTAssertFalse(config.isEnabled(CloudConfig.flagCampusCard))
        XCTAssertTrue(config.isEnabled(CloudConfig.flagRecharge))
        // Never published, and the whole config missing: both leave the feature on.
        XCTAssertTrue(config.isEnabled("somethingNew"))
        XCTAssertTrue(CloudConfig.empty.isEnabled(CloudConfig.flagCampusCard))
    }
}
