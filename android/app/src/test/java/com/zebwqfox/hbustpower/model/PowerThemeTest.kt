package com.zebwqfox.hbustpower.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors `HBUSTPowerIOSTests/PowerThemeTests.swift`. */
class PowerThemeTest {
    @Test fun everyThemeIsDistinctAndDescribed() {
        val styles = PowerThemeStyle.entries
        assertEquals(3, styles.size)
        assertEquals(styles.size, styles.map { it.id }.toSet().size)
        assertEquals(styles.size, styles.map { it.displayName }.toSet().size)
        styles.forEach {
            assertFalse(it.displayName.isBlank())
            assertFalse(it.tagline.isBlank())
            assertFalse(it.greeting.isBlank())
            assertFalse(it.chargingLine.isBlank())
        }
        // The friends' themes say where the colours come from; the default one has nothing to credit.
        assertNull(PowerThemeStyle.CLASSIC.credit)
        assertNotNull(PowerThemeStyle.PURPLE_BIRD.credit)
        assertNotNull(PowerThemeStyle.MAPLE_YELLOW.credit)
    }

    @Test fun themesUseDifferentAccentsInBothAppearances() {
        val light = PowerThemeStyle.entries.map { it.light.accent }
        val dark = PowerThemeStyle.entries.map { it.dark.accent }
        assertEquals(light.size, light.toSet().size)
        assertEquals(dark.size, dark.toSet().size)
        // Dark schemes must not reuse the light background, or text would vanish.
        PowerThemeStyle.entries.forEach { assertTrue(it.dark.background != it.light.background) }
    }

    @Test fun unknownOrMissingIdFallsBackToTheDefault() {
        assertEquals(PowerThemeStyle.CLASSIC, PowerThemeStyle.of(null))
        assertEquals(PowerThemeStyle.CLASSIC, PowerThemeStyle.of("nope"))
        assertEquals(PowerThemeStyle.PURPLE_BIRD, PowerThemeStyle.of("purpleBird"))
        // Ids are what gets persisted, so they must stay stable.
        assertEquals(listOf("classic", "purpleBird", "mapleYellow"), PowerThemeStyle.entries.map { it.id })
    }

    @Test fun strayBirdsLinesAreAttributedAndCycle() {
        assertTrue(StrayBirds.ATTRIBUTION.contains("飞鸟集"))
        assertTrue(StrayBirds.lines.size >= 10)
        assertEquals(StrayBirds.lines.size, StrayBirds.lines.toSet().size)
        assertEquals(StrayBirds.lines[1], StrayBirds.after(StrayBirds.lines[0]))
        assertEquals(StrayBirds.lines[0], StrayBirds.after(StrayBirds.lines.last()))
        assertTrue(StrayBirds.lines.contains(StrayBirds.ofThisLaunch))
        assertTrue(StrayBirds.after("不在列表里的句子") in StrayBirds.lines)
    }
}
