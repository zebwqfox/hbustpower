package com.zebwqfox.hbustpower.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

interface FirstRunStore {
    fun markCompleted()
    fun markNotificationDeferred()
}

/**
 * Port of iOS `FirstRunFlow`: notification permission → short introduction → finished. Denial or skipping never
 * blocks the app; returning from system settings with permission granted moves on; completion happens once.
 * The Activity performs the actual system request and reports back.
 */
class FirstRunFlow(private val store: FirstRunStore) {
    enum class Step { PERMISSION, PERMISSION_DENIED, INTRODUCTION, FINISHED }

    var step by mutableStateOf(Step.PERMISSION); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null); private set

    /**
     * Returns true when the caller should show the system permission dialog. [alreadyAllowed] covers Android 12
     * and below (no runtime dialog) and a permission granted earlier.
     */
    fun requestPermission(alreadyAllowed: Boolean, needsRuntimeRequest: Boolean): Boolean {
        if (busy || step != Step.PERMISSION) return false
        error = null
        return when {
            alreadyAllowed -> { step = Step.INTRODUCTION; false }
            needsRuntimeRequest -> { busy = true; true }
            else -> { step = Step.PERMISSION_DENIED; false }
        }
    }

    fun onPermissionResult(granted: Boolean) {
        if (!busy) return
        busy = false
        step = if (granted) Step.INTRODUCTION else Step.PERMISSION_DENIED
    }

    fun onPermissionRequestFailed() {
        busy = false
        error = "未能申请通知权限，请重试"
    }

    fun continueWithoutPermission() {
        if (busy) return
        store.markNotificationDeferred()
        step = Step.INTRODUCTION
        error = null
    }

    /** Called when returning to the app, for example from system notification settings. */
    fun refreshAuthorization(allowed: Boolean) {
        if (busy || step != Step.PERMISSION_DENIED) return
        if (allowed) step = Step.INTRODUCTION
    }

    fun back() {
        if (busy) return
        step = Step.PERMISSION
        error = null
    }

    /** Returns true only the first time, so the app starts exactly once. */
    fun finish(): Boolean {
        if (step != Step.INTRODUCTION || busy) return false
        store.markCompleted()
        step = Step.FINISHED
        return true
    }
}
