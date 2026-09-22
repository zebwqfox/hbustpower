package com.zebwqfox.hbustpower.model

import com.zebwqfox.hbustpower.BuildConfig
import org.junit.Assert.*
import org.junit.Test

class ChangelogAndFirstRunTest {
    @Test fun releaseHistoryIsCompleteOrderedAndMatchesInstalledVersion() {
        assertEquals(BuildConfig.VERSION_NAME, Changelog.latest.version)
        assertEquals(Changelog.releases.size, Changelog.releases.map { it.version }.toSet().size)
        val versions = Changelog.releases.map { release ->
            assertTrue(release.sections.isNotEmpty())
            release.sections.forEach { assertTrue(it.title.isNotBlank()); assertTrue(it.items.isNotEmpty()); assertTrue(it.items.all(String::isNotBlank)) }
            release.version.split('.').map(String::toInt).fold(0) { total, n -> total * 100 + n }
        }
        assertEquals(versions.sortedDescending(), versions)
    }
    @Test fun seventhAvatarTapIsTheOnlyEasterEgg() {
        assertEquals(DeveloperProfile.avatarReplies, (1..6).map(DeveloperProfile::replyForTap))
        assertEquals(DeveloperProfile.EASTER_EGG, DeveloperProfile.replyForTap(7))
        assertEquals(DeveloperProfile.AFTER_EASTER_EGG, DeveloperProfile.replyForTap(8))
    }
    private class Store : FirstRunStore {
        var completed = 0; var deferred = 0
        override fun markCompleted() { completed++ }
        override fun markNotificationDeferred() { deferred++ }
    }
    @Test fun skipThenFinishPersistsOnce() {
        val store = Store(); val flow = FirstRunFlow(store)
        assertFalse(flow.finish())
        flow.continueWithoutPermission()
        assertTrue(flow.finish()); assertFalse(flow.finish())
        assertEquals(1, store.completed); assertEquals(1, store.deferred)
    }
    @Test fun permissionRequestCannotBeDoubleSubmittedOrSkippedWhilePending() {
        val flow = FirstRunFlow(Store())
        assertTrue(flow.requestPermission(false, true))
        assertFalse(flow.requestPermission(false, true))
        flow.continueWithoutPermission()
        assertEquals(FirstRunFlow.Step.PERMISSION, flow.step)
        flow.onPermissionResult(false)
        assertEquals(FirstRunFlow.Step.PERMISSION_DENIED, flow.step)
        flow.refreshAuthorization(true)
        assertEquals(FirstRunFlow.Step.INTRODUCTION, flow.step)
    }
    @Test fun failedPermissionLaunchCanRetryAndOldAndroidDoesNotRequestRuntimePermission() {
        val flow = FirstRunFlow(Store())
        flow.requestPermission(false, true); flow.onPermissionRequestFailed()
        assertFalse(flow.busy); assertNotNull(flow.error)
        assertTrue(flow.requestPermission(false, true))
        val oldAndroid = FirstRunFlow(Store())
        assertFalse(oldAndroid.requestPermission(false, false))
        assertEquals(FirstRunFlow.Step.PERMISSION_DENIED, oldAndroid.step)
    }
}
