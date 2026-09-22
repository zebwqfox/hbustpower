package com.zebwqfox.hbustpower.ui

import com.zebwqfox.hbustpower.ui.components.LiquidPhysics
import com.zebwqfox.hbustpower.ui.components.ChargeRefreshRules
import org.junit.Assert.*
import org.junit.Test

class InteractionRulesTest {
    @Test fun leftTiltRaisesLeftSurfaceAndRightDragRaisesRightSurface() {
        val liquid = LiquidPhysics()
        liquid.setAndroidGravityX(4.9f)
        repeat(300) { liquid.step(1.0 / 60) }
        assertTrue(liquid.tilt < 0)
        assertTrue(liquid.surfaceY(0.0, 300.0, 200.0, 0.0, 0.0, 0.0) < liquid.surfaceY(300.0, 300.0, 200.0, 0.0, 0.0, 0.0))
        liquid.setAndroidGravityX(null); liquid.push(1.0)
        repeat(300) { liquid.step(1.0 / 60) }
        assertTrue(liquid.tilt > 0)
    }
    @Test fun pullPhasesFollowTheirOwnCopyAndRingFill() {
        val rules = ChargeRefreshRules
        assertEquals("", rules.caption(ChargeRefreshRules.Phase.IDLE, 0.01f, "charging"))
        assertEquals("继续下拉，给数据充电", rules.caption(ChargeRefreshRules.Phase.IDLE, 0.5f, "charging"))
        assertEquals("松手，开始充电 ⚡", rules.caption(ChargeRefreshRules.Phase.ARMED, 1.1f, "charging"))
        assertEquals("charging", rules.caption(ChargeRefreshRules.Phase.CHARGING, 1f, "charging"))
        assertEquals("充满啦！", rules.caption(ChargeRefreshRules.Phase.SUCCESS, 0.1f, "charging"))
        assertEquals("没充上电，稍后再试", rules.caption(ChargeRefreshRules.Phase.FAILURE, 0.1f, "charging"))
        // The ring fills with the pull, drops back while spinning, and is whole for either outcome.
        assertEquals(1f, rules.ringFill(ChargeRefreshRules.Phase.IDLE, 1.2f))
        assertEquals(0.55f, rules.ringFill(ChargeRefreshRules.Phase.IDLE, 0.55f))
        assertEquals(0.3f, rules.ringFill(ChargeRefreshRules.Phase.CHARGING, 1f))
        assertEquals(1f, rules.ringFill(ChargeRefreshRules.Phase.SUCCESS, 0f))
        assertEquals(1f, rules.ringFill(ChargeRefreshRules.Phase.FAILURE, 0f))
        assertTrue(ChargeRefreshRules.MINIMUM_CHARGING_MILLIS >= 800)
        assertTrue(ChargeRefreshRules.DISARM_FRACTION < 1f)
    }

    @Test fun wideAndCompactLayoutsHaveCorrectContentBounds() {
        assertFalse(PowerLayoutInfo(599f, 800f).isWide)
        assertTrue(PowerLayoutInfo(600f, 800f).isWide)
        assertFalse(PowerLayoutInfo(700f, 400f).isPortraitPhone)
        assertEquals(1.0, LiquidPhysics.levelFor(40.0, 5.0), 0.0)
        assertEquals(0.5, LiquidPhysics.levelFor(null, 150.0), 0.0)
    }
}
