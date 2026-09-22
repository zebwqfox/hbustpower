package com.zebwqfox.hbustpower.data

import java.net.URI

/**
 * School entry points from iOS `ElectricityService.swift` / `AuthenticationScripts.swift` (1.7.1).
 * The authorisation link no longer carries a uid: the identity is whoever signs in. Both entries are the
 * ones the school publishes, shipped in the app exactly as the iOS build does.
 */
object SchoolEndpoints {
    const val ELECTRICITY_HOST = "xianankd.hbust.edu.cn"
    const val ECARD_HOST = "ecard.hbust.edu.cn"

    const val HOME_URL = "http://xianankd.hbust.edu.cn/pay/home"
    const val USAGE_URL = "http://xianankd.hbust.edu.cn/use/record"
    const val RECORDS_URL = "http://xianankd.hbust.edu.cn/pay/record"

    /** The amount form lives on /pay/home; /pay/prepay only accepts the submission and 404s on GET. */
    const val RECHARGE_URL = HOME_URL
    const val CAMPUS_PORTAL_URL = "http://ecard.hbust.edu.cn/plat"
    const val PRIVACY_POLICY_URL = "https://homewh.chaoxing.com/agree/privacyPolicy?appId=900001"
    const val USER_AGREEMENT_URL = "https://homewh.chaoxing.com/agree/userAgreement?appId=900001"

    /** The 学习通 entry the school configured for this app; identity comes from whoever signs in. */
    const val CHAOXING_AUTH_URL =
        "https://auth.chaoxing.com/connect/oauth2/authorize?" +
            "appid=50a29846d03b4717a867534162983482&" +
            "redirect_uri=http%3A%2F%2Fecard.hbust.edu.cn%2Fberserker-auth%2Fcas%2Flogin%2Fchaoxing%3F" +
            "targetUrl%3Dhttp%253A%252F%252Fecard.hbust.edu.cn%252Fplat%253Fname%253DloginTransit%2526source%253Dh5%26" +
            "fidEnc%3D47b2091e0a42b962%26mappId%3D6312211%26" +
            "mappIdEnc%3Ddd8f03b5452dfa36f5d0c01c4bbc43bd%26wfwEnc%3D5D42DB954FB3413292028505161D21F0%26" +
            "appId%3D50a29846d03b4717a867534162983482%26appKey%3D7s1f6B0V23za1HL6&" +
            "response_type=code&scope=snsapi_base&state=127819"

    /** Compatibility alias for passive session checks; interactive logins offer school SSO first. */
    const val AUTH_URL = CHAOXING_AUTH_URL

    /** Cookie-bearing URLs used when counting session cookies for diagnostics. */
    val sessionCookieUrls = listOf("http://$ELECTRICITY_HOST/", "http://$ECARD_HOST/", "https://$ECARD_HOST/")

    fun isLoginForm(url: String?): Boolean = parse(url)?.let {
        it.scheme == "https" && it.host.equals("passport2.chaoxing.com", ignoreCase = true) && it.path == "/mlogin"
    } ?: false

    fun isCampusPortal(url: String?): Boolean = parse(url)?.let {
        it.scheme in setOf("http", "https") && it.host.equals(ECARD_HOST, ignoreCase = true) &&
            (it.path == "/plat" || it.path.startsWith("/plat/"))
    } ?: false

    /** Hosts where captcha, weak-password changes and second-factor checks stay in the visible official page. */
    fun isOfficialAuthHost(url: String?): Boolean = parse(url)?.host?.lowercase() in setOf("passport2.chaoxing.com", "auth.chaoxing.com")

    fun isSchoolHost(url: String?): Boolean = parse(url)?.host?.lowercase()?.let { it == "hbust.edu.cn" || it.endsWith(".hbust.edu.cn") } ?: false

    /** Enforce the cleartext exception even on API 23, which ignores networkSecurityConfig. */
    fun isAllowedNavigation(url: String?): Boolean = parse(url)?.let {
        it.userInfo == null && (it.scheme == "https" ||
            (it.scheme == "http" && it.host.lowercase() in setOf(ECARD_HOST, ELECTRICITY_HOST)))
    } ?: false

    private fun parse(url: String?): URI? = url?.let { runCatching { URI(it) }.getOrNull() }?.takeIf { it.host != null }
}
