package com.zebwqfox.hbustpower.auth

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ElectricityRedirectValidatorTest {
    @Test fun acceptsExactSchoolRedirect() {
        assertTrue(ElectricityRedirectValidator.isValid(
            "http://ecard.hbust.edu.cn/berserker-base/redirect?appId=180&synjones-auth=token"
        ))
    }

    @Test fun rejectsWrongOrAmbiguousRedirects() {
        assertFalse(ElectricityRedirectValidator.isValid("javascript:alert(1)"))
        assertFalse(ElectricityRedirectValidator.isValid("https://evil.example/berserker-base/redirect?appId=180&synjones-auth=x"))
        assertFalse(ElectricityRedirectValidator.isValid("https://ecard.hbust.edu.cn/berserker-base/redirect?appId=181&synjones-auth=x"))
        assertFalse(ElectricityRedirectValidator.isValid("https://ecard.hbust.edu.cn/berserker-base/redirect?appId=180&appId=180&synjones-auth=x"))
        assertFalse(ElectricityRedirectValidator.isValid("https://ecard.hbust.edu.cn/berserker-base/redirect?appId=180&synjones-auth="))
    }
}
