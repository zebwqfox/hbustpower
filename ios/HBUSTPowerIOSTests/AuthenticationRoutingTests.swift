import XCTest
@testable import HBUSTPowerIOS

final class AuthenticationRoutingTests: XCTestCase {
    func testPublishedSchoolEntryIsExactAndDoesNotContainAnIdentity() {
        let url = ElectricityService.schoolSSOAuthURL
        XCTAssertTrue(AuthenticationScripts.isSchoolSSOEntry(url))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.map(\.name), ["resultUrl"])
        XCTAssertFalse(items.map(\.name).contains(where: { ["uid", "username", "studentId"].contains($0) }))
    }

    func testOnlyCurrentSchoolSSOOriginAndLoginPathAreAccepted() {
        XCTAssertTrue(AuthenticationScripts.isSchoolSSO(
            URL(string: "http://sso.hbust.edu.cn:28000/login/oauth/authorize")
        ))

        for raw in [
            "https://sso.hbust.edu.cn:28000/login/oauth/authorize",
            "http://sso.hbust.edu.cn/login/oauth/authorize",
            "http://sso.hbust.edu.cn.evil.invalid:28000/login/oauth/authorize",
            "http://sso.hbust.edu.cn:28000/other"
        ] {
            XCTAssertFalse(AuthenticationScripts.isSchoolSSO(URL(string: raw)), raw)
        }
    }

    func testSchoolServiceHallDenialIsRecognizedWithoutTreatingOtherErrorsAsAuthorization() {
        XCTAssertTrue(AuthenticationScripts.isSchoolSSODenialMessage("服务大厅未授权(1)"))
        XCTAssertFalse(AuthenticationScripts.isSchoolSSODenialMessage("用户名或密码错误"))
        XCTAssertFalse(AuthenticationScripts.isSchoolSSODenialMessage("连接超时"))
    }

    func testElectricityAuthorizationStillRequiresOneAppAndOneToken() {
        XCTAssertTrue(ElectricityService.isValidElectricityRedirect(
            URL(string: "http://ecard.hbust.edu.cn/berserker-base/redirect?appId=180&synjones-auth=test")!
        ))
        XCTAssertFalse(ElectricityService.isValidElectricityRedirect(
            URL(string: "http://ecard.hbust.edu.cn/berserker-base/redirect?appId=180&appId=180&synjones-auth=test")!
        ))
        XCTAssertFalse(ElectricityService.isValidElectricityRedirect(
            URL(string: "http://ecard.hbust.edu.cn.evil.invalid/berserker-base/redirect?appId=180&synjones-auth=test")!
        ))
    }
}
