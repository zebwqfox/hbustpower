package com.zebwqfox.hbustpower.data

import kotlin.test.Test
import kotlin.test.assertEquals

class CloudConfigServiceTest {
    @Test
    fun `cache buster is added without losing an existing query or fragment`() {
        assertEquals(
            "https://example.com/config.json?cacheBust=123",
            cacheBustedUrl("https://example.com/config.json", 123),
        )
        assertEquals(
            "https://example.com/config.json?channel=stable&cacheBust=123#release",
            cacheBustedUrl("https://example.com/config.json?channel=stable#release", 123),
        )
    }
}
