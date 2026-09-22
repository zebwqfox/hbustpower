package com.zebwqfox.hbustpower.data

import org.junit.Assert.*
import org.junit.Test

class SchoolEndpointsTest {
    @Test fun builtInEntriesPointAtTheSchoolAndCarryNoUserId() {
        // Identity comes from whoever signs in; a pinned uid would tie every install to one account.
        assertFalse(SchoolEndpoints.CHAOXING_AUTH_URL.contains("uid", ignoreCase = true))
        assertTrue(SchoolEndpoints.CHAOXING_AUTH_URL.startsWith("https://auth.chaoxing.com/"))
        assertTrue(SchoolEndpoints.CHAOXING_AUTH_URL.contains("appKey%3D"))
        assertEquals(SchoolEndpoints.CHAOXING_AUTH_URL, SchoolEndpoints.AUTH_URL)
    }

    @Test fun cleartextOnlyAllowedForExactSchoolServiceHosts() {
        assertTrue(SchoolEndpoints.isAllowedNavigation(SchoolEndpoints.HOME_URL))
        assertTrue(SchoolEndpoints.isAllowedNavigation(SchoolEndpoints.CAMPUS_PORTAL_URL))
        assertFalse(SchoolEndpoints.isAllowedNavigation("http://ecard.hbust.edu.cn.evil.test/plat"))
        assertFalse(SchoolEndpoints.isAllowedNavigation("http://passport2.chaoxing.com/mlogin"))
        assertFalse(SchoolEndpoints.isAllowedNavigation("https://user:password@ecard.hbust.edu.cn/plat"))
        assertFalse(SchoolEndpoints.isAllowedNavigation("file:///example"))
        assertFalse(SchoolEndpoints.isAllowedNavigation("http://untrusted.example.com/login"))
    }
}
