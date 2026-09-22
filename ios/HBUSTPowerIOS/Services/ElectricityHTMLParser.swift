import Foundation

/// Pure parsing of the school electricity pages, kept separate from networking so it can be unit tested.
enum ElectricityHTMLParser {
    static func purchasedKWh(from html: String) -> Double? { value(named: "剩余购电", from: html) }
    static func subsidyKWh(from html: String) -> Double? { value(named: "剩余补助", from: html) }

    /// A sign-in page, as opposed to a normal page that merely mentions the authentication service in its footer.
    static func isLoginPage(finalURL: String, html: String) -> Bool {
        let url = finalURL.lowercased()
        if url.contains("login") || url.contains("/error") || html.localizedCaseInsensitiveContains("session过期") { return true }
        let hasPasswordField = html.range(of: #"type\s*=\s*["']?password"#, options: [.regularExpression, .caseInsensitive]) != nil
        return html.contains("统一身份认证") && hasPasswordField
    }

    /// The home page lost its balance and shows the authentication service instead, e.g. a script-rendered login page.
    static func isLoginPlaceholder(homeHTML html: String) -> Bool {
        purchasedKWh(from: html) == nil && html.contains("统一身份认证")
    }

    static func room(from html: String) -> String? {
        let pattern = #"<li[^>]*class=[\"'][^\"']*list-group-title[^\"']*[\"'][^>]*>(.*?)</li>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        var value = stripTags(String(html[range])).trimmingCharacters(in: .whitespacesAndNewlines)
        // The live page titles the first meter ("东10-625照明"); the room is the part before the meter type.
        for suffix in ["照明", "空调"] where value.hasSuffix(suffix) && value.count > suffix.count {
            value = String(value.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        }
        return value.isEmpty ? nil : value
    }

    static func unitPrice(from html: String) -> Double? {
        let plain = stripTags(html)
        guard let range = plain.range(of: "电费单价") else { return nil }
        let tail = String(plain[range.upperBound...].prefix(80))
        guard let numberRange = tail.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(tail[numberRange])
    }

    static func meters(from html: String) -> [MeterStatus] {
        let lines = visibleLines(from: html)
        guard let start = lines.firstIndex(of: "当前表具") else { return [] }
        var result: [MeterStatus] = []
        var index = lines.index(after: start)
        while index + 2 < lines.count {
            let name = lines[index]
            if name == "元" || name.contains("充值说明") || name == "一卡通充值" { break }
            if name.contains("照明") || name.contains("空调") {
                result.append(.init(name: name, powerStatus: lines[index + 1], communicationStatus: lines[index + 2]))
                index += 3
            } else { index += 1 }
        }
        return result
    }

    static func usageRecords(from html: String) -> [UsageRecord] {
        let lines = visibleLines(from: html)
        return recordWindows(in: lines, maxLength: 6).compactMap { date, window in
            guard let amount = window.first(where: { $0.range(of: #"^\d+(?:\.\d+)?度$"#, options: .regularExpression) != nil }),
                  let meter = window.first(where: { $0.hasPrefix("电表:") }),
                  let value = Double(amount.replacingOccurrences(of: "度", with: "")) else { return nil }
            return .init(date: date, kWh: value, meterName: meter.replacingOccurrences(of: "电表:", with: "").trimmingCharacters(in: .whitespaces))
        }
    }

    static func rechargeRecords(from html: String) -> [RechargeRecord] {
        let lines = visibleLines(from: html)
        return recordWindows(in: lines, maxLength: 9).map { date, window in
            RechargeRecord(
                date: date,
                amountText: window.first { $0.hasSuffix("元") || ($0.hasSuffix("度") && !$0.hasPrefix("电量:")) } ?? "-",
                kWhText: field("电量:", in: window),
                type: field("类型:", in: window),
                meterName: field("电表:", in: window),
                studentNumber: optionalField(["学工号:", "学号:"], in: window)
            )
        }
    }

    /// Lines after each timestamp, stopping at the next timestamp so a record with missing fields never borrows them from the next one.
    private static func recordWindows(in lines: [String], maxLength: Int) -> [(Date, [String])] {
        let starts = lines.indices.compactMap { index in date(from: lines[index]).map { (index, $0) } }
        return starts.enumerated().map { position, start in
            let nextStart = position + 1 < starts.count ? starts[position + 1].0 : lines.count
            let end = min(nextStart, start.0 + 1 + maxLength)
            return (start.1, Array(lines[(start.0 + 1)..<end]))
        }
    }

    static func date(from text: String) -> Date? { dateTimeFormatter.date(from: text) }

    private static func value(named label: String, from html: String) -> Double? {
        guard let range = html.range(of: label) else { return nil }
        let plain = stripTags(String(html[range.upperBound...].prefix(700)))
        guard let numberRange = plain.range(of: #"-?\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(plain[numberRange])
    }

    private static func field(_ prefix: String, in lines: [String]) -> String {
        lines.first(where: { $0.hasPrefix(prefix) })?.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces) ?? "-"
    }

    private static func optionalField(_ prefixes: [String], in lines: [String]) -> String? {
        for prefix in prefixes {
            guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { continue }
            let value = line.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func visibleLines(from html: String) -> [String] {
        let cleaned = html
            .replacingOccurrences(of: #"<script\b[^>]*>.*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<style\b[^>]*>.*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
        return stripTags(cleaned).replacingOccurrences(of: "&amp;", with: "&")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: #"<[^>]+>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#x5EA6;", with: "度")
    }

    // School timestamps are Beijing time in the Gregorian calendar, whatever the device's region, calendar or time zone.
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
