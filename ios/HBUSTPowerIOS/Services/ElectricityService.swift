import Foundation

enum ElectricityError: LocalizedError {
    case authenticationRequired, invalidRedirect, invalidResponse, parseFailed

    var errorDescription: String? {
        switch self {
        case .authenticationRequired: "登录状态已失效"
        case .invalidRedirect: "没有取得有效的电费授权"
        case .invalidResponse: "学校系统暂时无法连接"
        case .parseFailed: "没有找到宿舍电量数据"
        }
    }
}

actor ElectricityService {
    // The amount form lives on /pay/home. /pay/prepay only accepts the form submission
    // and returns 404 when opened directly with GET.
    static let rechargeURL = URL(string: "http://xianankd.hbust.edu.cn/pay/home")!

    static let chaoxingAuthURL = URL(string:
        "https://auth.chaoxing.com/connect/oauth2/authorize?" +
        "appid=50a29846d03b4717a867534162983482&" +
        "redirect_uri=http%3A%2F%2Fecard.hbust.edu.cn%2Fberserker-auth%2Fcas%2Flogin%2Fchaoxing%3F" +
        "targetUrl%3Dhttp%253A%252F%252Fecard.hbust.edu.cn%252Fplat%253Fname%253DloginTransit%2526source%253Dh5%26" +
        "fidEnc%3D47b2091e0a42b962%26mappId%3D6312211%26" +
        "mappIdEnc%3Ddd8f03b5452dfa36f5d0c01c4bbc43bd%26wfwEnc%3D5D42DB954FB3413292028505161D21F0%26" +
        "appId%3D50a29846d03b4717a867534162983482%26appKey%3DREPLACE_WITH_YOUR_SCHOOL_APP_KEY&" +
        "response_type=code&scope=snsapi_base&state=127819"
    )!

    // Compatibility alias for passive session checks.
    static let authURL = chaoxingAuthURL

    private let homeURL = URL(string: "http://xianankd.hbust.edu.cn/pay/home")!
    private let useURL = URL(string: "http://xianankd.hbust.edu.cn/use/record")!
    private let recordURL = URL(string: "http://xianankd.hbust.edu.cn/pay/record")!
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 20
        configuration.httpAdditionalHeaders = [
            "User-Agent": AuthenticationScripts.mobileUserAgent,
            "Referer": "http://xianankd.hbust.edu.cn/pay/home"
        ]
        session = URLSession(configuration: configuration)
    }

    func establishSession(with redirectURL: URL) async throws -> ElectricitySnapshot {
        guard Self.isValidElectricityRedirect(redirectURL),
              let parts = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false),
              let token = parts.queryItems?.first(where: { $0.name == "synjones-auth" })?.value,
              !token.isEmpty else { throw ElectricityError.invalidRedirect }
        let (data, response) = try await session.data(from: redirectURL)
        try validate(response: response, data: data)
        return try await fetchDashboard()
    }

    func fetchCurrentSession() async throws -> ElectricitySnapshot {
        try await fetchDashboard()
    }

    static func isValidElectricityRedirect(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme ?? ""), url.host?.lowercased() == "ecard.hbust.edu.cn",
              url.path == "/berserker-base/redirect",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let appIDs = parts.queryItems?.filter { $0.name == "appId" } ?? []
        let tokens = parts.queryItems?.filter { $0.name == "synjones-auth" } ?? []
        return appIDs.count == 1 && appIDs.first?.value == "180" && tokens.count == 1 && !(tokens.first?.value ?? "").isEmpty
    }

    private func fetchDashboard() async throws -> ElectricitySnapshot {
        let homeHTML = try await fetchHTML(homeURL)
        guard let purchased = ElectricityHTMLParser.purchasedKWh(from: homeHTML) else {
            if ElectricityHTMLParser.isLoginPlaceholder(homeHTML: homeHTML) { throw ElectricityError.authenticationRequired }
            throw ElectricityError.parseFailed
        }
        async let usageHTML = fetchHTML(useURL)
        async let recordHTML = fetchHTML(recordURL)
        let (resolvedUsageHTML, resolvedRecordHTML) = try await (usageHTML, recordHTML)
        return ElectricitySnapshot(
            room: ElectricityHTMLParser.room(from: homeHTML),
            purchasedKWh: purchased,
            subsidyKWh: ElectricityHTMLParser.subsidyKWh(from: homeHTML),
            unitPrice: ElectricityHTMLParser.unitPrice(from: homeHTML),
            meters: ElectricityHTMLParser.meters(from: homeHTML),
            usageRecords: ElectricityHTMLParser.usageRecords(from: resolvedUsageHTML),
            rechargeRecords: ElectricityHTMLParser.rechargeRecords(from: resolvedRecordHTML),
            fetchedAt: .now
        )
    }

    private func fetchHTML(_ url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        guard let html = decodeHTML(data) else { throw ElectricityError.invalidResponse }
        return html
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ElectricityError.invalidResponse }
        if [401, 403].contains(http.statusCode) { throw ElectricityError.authenticationRequired }
        guard (200...399).contains(http.statusCode) else { throw ElectricityError.invalidResponse }
        if ElectricityHTMLParser.isLoginPage(finalURL: http.url?.absoluteString ?? "", html: decodeHTML(data) ?? "") {
            throw ElectricityError.authenticationRequired
        }
    }

    private func decodeHTML(_ data: Data) -> String? {
        String(data: data, encoding: .utf8) ?? String(data: data, encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))))
    }
}
