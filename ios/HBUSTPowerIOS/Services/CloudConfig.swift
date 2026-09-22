import Foundation

/// The small JSON the app fetches from the developer's own site: what the newest build is, a notice worth
/// showing, and switches for the parts that break when the school changes its pages.
///
/// This is the iOS half of a contract shared with `android/.../data/CloudConfig.kt` and the panel's
/// `server/src/config-builder.js`. All three have to agree: a key one side writes and another ignores is
/// harmless, but a key the app expects and the panel omits silently turns a feature off.
///
/// It carries text, numbers and booleans only — never code, never a script, never anything the app runs. The
/// one thing that can send someone elsewhere is the download link, and that is dropped unless it is HTTPS on a
/// host compiled into this build, so a tampered file cannot point people at an arbitrary page.
struct CloudConfig: Equatable, Sendable {
    struct Update: Equatable, Sendable {
        let versionCode: Int
        let versionName: String
        var notes: [String] = []
        /// Nil when the published link failed the host check.
        var downloadURL: URL?
        /// Optional, so the user can verify what they downloaded.
        var sha256: String?
        var sizeBytes: Int?
    }

    struct Notice: Equatable, Sendable {
        enum Level: String, Sendable { case info, warning }

        let id: String
        var title: String = "公告"
        let body: String
        var level: Level = .info
        /// Epoch seconds. The notice goes away by itself, even if nobody remembers to take it down.
        var expiresAt: TimeInterval?
        var dismissible: Bool = true
    }

    var update: Update?
    var notice: Notice?
    var flags: [String: Bool] = [:]
    /// Builds older than this are known to be broken; the app says so instead of blocking anyone.
    var minSupportedVersionCode: Int = 0
    /// When the file was published, as written by whoever published it. Diagnostics only.
    var publishedAt: String?

    static let empty = CloudConfig()

    // Flag names, matching the panel's list.
    static let flagCampusCard = "campusCard"
    static let flagRecharge = "recharge"
    static let flagUpdateCheck = "updateCheck"

    func updateAvailable(currentVersionCode: Int) -> Update? {
        guard let update, update.versionCode > currentVersionCode else { return nil }
        return update
    }

    func mustUpgrade(currentVersionCode: Int) -> Bool {
        minSupportedVersionCode > 0 && currentVersionCode < minSupportedVersionCode
    }

    /// The notice to show right now: not expired, and not one the user already swiped away.
    func activeNotice(now: TimeInterval, dismissedIDs: Set<String>) -> Notice? {
        guard let notice else { return nil }
        if let expiresAt = notice.expiresAt, expiresAt <= now { return nil }
        if notice.dismissible && dismissedIDs.contains(notice.id) { return nil }
        return notice
    }

    /// Feature switches fail open: an unreachable or silent config leaves every feature on.
    func isEnabled(_ flag: String) -> Bool { flags[flag] ?? true }
}

extension CloudConfig {
    /// Parses the published file. Every field is optional, so an older app reading a newer file keeps working,
    /// and anything malformed yields `.empty` rather than throwing.
    ///
    /// Hand-rolled rather than `Codable` on purpose: one wrong type anywhere in a `Decodable` struct throws the
    /// whole document away, and a config that half-decodes is more useful than one that doesn't decode at all.
    static func parse(_ data: Data, trustedDownloadHosts: [String] = []) -> CloudConfig {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .empty }
        var config = CloudConfig()
        config.publishedAt = (root["publishedAt"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        config.minSupportedVersionCode = root["minSupportedVersionCode"] as? Int ?? 0

        if let node = root["update"] as? [String: Any] {
            config.update = parseUpdate(node, trustedHosts: trustedDownloadHosts)
        }
        if let node = root["notice"] as? [String: Any] {
            config.notice = parseNotice(node)
        }
        if let node = root["flags"] as? [String: Any] {
            config.flags = node.compactMapValues { $0 as? Bool }
        }
        return config
    }

    static func parse(json: String, trustedDownloadHosts: [String] = []) -> CloudConfig {
        parse(Data(json.utf8), trustedDownloadHosts: trustedDownloadHosts)
    }

    private static func parseUpdate(_ node: [String: Any], trustedHosts: [String]) -> Update? {
        guard let versionCode = node["versionCode"] as? Int, versionCode > 0,
              let versionName = (node["versionName"] as? String)?.trimmed, !versionName.isEmpty
        else { return nil }

        var update = Update(versionCode: versionCode, versionName: versionName)
        update.notes = (node["notes"] as? [Any] ?? []).compactMap {
            guard let note = ($0 as? String)?.trimmed, !note.isEmpty else { return nil }
            return note
        }
        if let raw = node["downloadURL"] as? String ?? node["downloadUrl"] as? String {
            update.downloadURL = trustedDownload(raw, trustedHosts: trustedHosts)
        }
        if let hash = (node["sha256"] as? String)?.lowercased(), isSHA256(hash) {
            update.sha256 = hash
        }
        if let size = node["sizeBytes"] as? Int, size > 0 {
            update.sizeBytes = size
        }
        return update
    }

    private static func parseNotice(_ node: [String: Any]) -> Notice? {
        guard let id = (node["id"] as? String)?.trimmed, !id.isEmpty,
              let body = (node["body"] as? String)?.trimmed, !body.isEmpty
        else { return nil }

        var notice = Notice(id: id, body: body)
        if let title = (node["title"] as? String)?.trimmed, !title.isEmpty { notice.title = title }
        if let level = (node["level"] as? String)?.lowercased(), level == "warning" { notice.level = .warning }
        if let expiry = node["expiresAt"] as? Double, expiry > 0 { notice.expiresAt = expiry }
        notice.dismissible = node["dismissible"] as? Bool ?? true
        return notice
    }

    /// HTTPS on a host this build allows — never a redirect to somewhere the config file made up.
    static func trustedDownload(_ raw: String, trustedHosts: [String]) -> URL? {
        guard !trustedHosts.isEmpty,
              let components = URLComponents(string: raw),
              components.scheme?.lowercased() == "https",
              components.user == nil, components.password == nil,
              let host = components.host?.lowercased(), !host.isEmpty,
              let url = components.url
        else { return nil }

        let allowed = trustedHosts.contains { trusted in
            let expected = trusted.lowercased().trimmed
            guard !expected.isEmpty else { return false }
            return host == expected || host.hasSuffix("." + expected)
        }
        return allowed ? url : nil
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
