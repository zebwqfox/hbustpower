import XCTest
@testable import HBUSTPowerIOS

// Fixtures are hand-written to mirror the structure the parser expects from xianankd.hbust.edu.cn.
// Replace them with anonymized copies of real pages when available.
final class ElectricityHTMLParserTests: XCTestCase {
    private let homeHTML = """
    <html><body>
    <ul><li class="list-group-title active">东10-625</li></ul>
    <div><span>剩余购电</span><span class="num">194.67</span><span>度</span></div>
    <div><span>剩余补助</span><span class="num">0.00</span><span>度</span></div>
    <p>电费单价：0.57元/度</p>
    <h4>当前表具</h4>
    <div>东10-625照明</div><div>正常用电</div><div>通讯正常</div>
    <div>东10-625空调</div><div>拉闸断电</div><div>通讯正常</div>
    <div>充值说明</div>
    <footer>技术支持：统一身份认证平台</footer>
    </body></html>
    """

    private let usageHTML = """
    <script>var t = "2026-01-01 00:00:00";</script>
    <div>2026-09-16 23:59:59</div><div>5.33度</div><div>电表:东10-625照明</div>
    <div>2026-09-16 23:59:59</div><div>21.59&#x5EA6;</div><div>电表:东10-625空调</div>
    <div>2026-09-15 23:59:59</div><div>电表:东10-625照明</div>
    """

    func testHomePageValues() {
        XCTAssertEqual(ElectricityHTMLParser.purchasedKWh(from: homeHTML), 194.67)
        XCTAssertEqual(ElectricityHTMLParser.subsidyKWh(from: homeHTML), 0)
        XCTAssertEqual(ElectricityHTMLParser.unitPrice(from: homeHTML), 0.57)
        XCTAssertEqual(ElectricityHTMLParser.room(from: homeHTML), "东10-625")
        XCTAssertEqual(ElectricityHTMLParser.meters(from: homeHTML), [
            MeterStatus(name: "东10-625照明", powerStatus: "正常用电", communicationStatus: "通讯正常"),
            MeterStatus(name: "东10-625空调", powerStatus: "拉闸断电", communicationStatus: "通讯正常")
        ])
    }

    func testRoomDropsTheMeterTypeFromTheTitle() {
        let html = #"<ul><li class="list-group-title">东10-625照明</li></ul>"#
        XCTAssertEqual(ElectricityHTMLParser.room(from: html), "东10-625")
        XCTAssertEqual(ElectricityHTMLParser.room(from: #"<li class="list-group-title">照明</li>"#), "照明")
    }

    func testUsageRecordsSkipScriptsAndIncompleteEntries() {
        let records = ElectricityHTMLParser.usageRecords(from: usageHTML)
        XCTAssertEqual(records.map(\.kWh), [5.33, 21.59])
        XCTAssertEqual(records.map(\.kind), ["照明", "空调"])
    }

    func testIncompleteUsageRecordDoesNotBorrowNextAmount() {
        let html = """
        <div>2026-09-16 23:59:59</div><div>电表:东10-625照明</div>
        <div>2026-09-15 23:59:59</div><div>4.80度</div><div>电表:东10-625照明</div>
        """
        let records = ElectricityHTMLParser.usageRecords(from: html)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.kWh, 4.8)
        XCTAssertEqual(records.first?.date, ElectricityHTMLParser.date(from: "2026-09-15 23:59:59"))
    }

    func testRechargeRecordWithMissingFieldsDoesNotBorrowFromNextRecord() {
        let html = """
        <div>2026-09-10 12:00:00</div><div>50.00元</div><div>类型:一卡通充值</div>
        <div>2026-09-01 08:30:00</div><div>100.00元</div><div>电量:175.44度</div><div>类型:微信充值</div><div>电表:东10-625</div><div>学工号:2026123456</div>
        """
        let records = ElectricityHTMLParser.rechargeRecords(from: html)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].amountText, "50.00元")
        XCTAssertEqual(records[0].type, "一卡通充值")
        XCTAssertEqual(records[0].kWhText, "-")
        XCTAssertEqual(records[0].meterName, "-")
        XCTAssertNil(records[0].studentNumber)
        XCTAssertEqual(records[1].amountText, "100.00元")
        XCTAssertEqual(records[1].kWhText, "175.44度")
        XCTAssertEqual(records[1].studentNumber, "2026123456")
    }

    func testTimestampsAreBeijingTimeRegardlessOfDeviceSettings() {
        let date = ElectricityHTMLParser.date(from: "2026-09-16 23:59:59")
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_789_574_399))
        XCTAssertNil(ElectricityHTMLParser.date(from: "2026-13-01 00:00:00"))
    }

    func testLoginDetection() {
        XCTAssertFalse(ElectricityHTMLParser.isLoginPage(finalURL: "http://xianankd.hbust.edu.cn/pay/home", html: homeHTML))
        XCTAssertFalse(ElectricityHTMLParser.isLoginPlaceholder(homeHTML: homeHTML))

        let loginForm = #"<h1>统一身份认证</h1><form><input name="username"><input type="password" name="pwd"></form>"#
        XCTAssertTrue(ElectricityHTMLParser.isLoginPage(finalURL: "http://xianankd.hbust.edu.cn/pay/home", html: loginForm))
        XCTAssertTrue(ElectricityHTMLParser.isLoginPage(finalURL: "https://ecard.hbust.edu.cn/Login?next=1", html: ""))
        XCTAssertTrue(ElectricityHTMLParser.isLoginPage(finalURL: "http://xianankd.hbust.edu.cn/pay/home", html: "Session过期，请重新进入"))

        let scriptRenderedLogin = #"<title>统一身份认证</title><div id="app"></div>"#
        XCTAssertFalse(ElectricityHTMLParser.isLoginPage(finalURL: "http://xianankd.hbust.edu.cn/pay/home", html: scriptRenderedLogin))
        XCTAssertTrue(ElectricityHTMLParser.isLoginPlaceholder(homeHTML: scriptRenderedLogin))
    }
}
