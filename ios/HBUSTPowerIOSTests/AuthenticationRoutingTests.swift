import XCTest
@testable import HBUSTPowerIOS

final class AuthenticationRoutingTests: XCTestCase {
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
