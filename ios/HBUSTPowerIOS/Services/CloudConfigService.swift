import Foundation

/// Where the config lives, which hosts may serve a download, and where reports go. All compiled in through
/// `Config/Base.xcconfig` → `Info.plist`, the same way the school app key is.
enum CloudEndpoints {
    private static func infoValue(_ key: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // The checked-in placeholder must never be mistaken for a real address.
        return value.hasPrefix("REPLACE_WITH") ? "" : value
    }

    static var configURL: URL? {
        guard let url = URL(string: infoValue("CloudConfigURL")), url.scheme == "https", url.host != nil else {
            return nil
        }
        return url
    }

    static var downloadHosts: [String] {
        infoValue("CloudDownloadHosts")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// No address compiled in means the whole feature stays quiet: no requests, no update UI.
    static var isConfigured: Bool { configURL != nil }

    /// For the diagnostics screen; the host alone says which build points where.
    static var configHost: String? { configURL?.host }

    /// The published policy page. iOS has no bundled copy the way Android does, so settings links out to the
    /// same document the filing materials point at.
    static var privacyPolicyURL: URL? {
        guard let url = URL(string: infoValue("PrivacyPolicyURL")), url.scheme == "https" else { return nil }
        return url
    }
}

/// What a fetch produced: fresh content, an unchanged file, or nothing because it did not work.
enum CloudFetch: Equatable, Sendable {
    case fresh(Data, etag: String?)
    case notModified
    case failed(String)
}

protocol CloudConfigFetching: Sendable {
    func fetch(etag: String?) async -> CloudFetch
}

/// Fetches the config over plain HTTPS with no cookies, no credentials and no identifying parameters: the
/// request says nothing about who is asking beyond what any HTTPS request must reveal. An `ETag` keeps the
/// daily check down to a few hundred bytes, and the response is capped so a wrong URL cannot pull something
/// large onto someone's cellular plan.
struct HTTPCloudConfigFetcher: CloudConfigFetching {
    static let maxBytes = 64 * 1024

    var url: URL?
    var session: URLSession

    init(url: URL? = CloudEndpoints.configURL, session: URLSession? = nil) {
        self.url = url
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            // Nothing about this request should be remembered between launches, and nothing about the user
            // should ride along with it.
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 10
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetch(etag: String?) async -> CloudFetch {
        guard let url else { return .failed("未配置更新地址") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(TelemetryPayload.userAgent, forHTTPHeaderField: "User-Agent")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed("响应格式不正确") }
            switch http.statusCode {
            case 304: return .notModified
            case 200:
                guard data.count <= Self.maxBytes else { return .failed("更新信息过大") }
                return .fresh(data, etag: http.value(forHTTPHeaderField: "ETag"))
            default:
                return .failed("服务器返回 \(http.statusCode)")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
