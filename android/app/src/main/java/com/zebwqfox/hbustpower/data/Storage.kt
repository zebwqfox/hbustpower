package com.zebwqfox.hbustpower.data

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.edit
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** A string store for credentials (the saved electricity redirect), sealed with an Android Keystore AES key. */
interface CredentialStore {
    fun save(account: String, value: String): Boolean
    fun read(account: String): String?
    fun delete(account: String)
}

class KeystoreCredentialStore(context: Context) : CredentialStore {
    private val prefs = context.getSharedPreferences("hbust_power_secure", Context.MODE_PRIVATE)

    override fun save(account: String, value: String): Boolean = runCatching {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val sealed = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        prefs.edit(commit = true) { putString(account, Base64.encodeToString(sealed, Base64.NO_WRAP)) }
    }.isSuccess

    override fun read(account: String): String? = runCatching {
        val sealed = Base64.decode(prefs.getString(account, null) ?: return null, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, sealed, 0, IV_LENGTH))
        String(cipher.doFinal(sealed, IV_LENGTH, sealed.size - IV_LENGTH), Charsets.UTF_8)
    }.getOrNull()

    override fun delete(account: String) = prefs.edit(commit = true) { remove(account) }

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).apply {
            init(
                KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
        }.generateKey()
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val ALIAS = "hbust_power_credentials"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH = 12
    }
}

/** Non-sensitive preferences. */
class AppSettings(context: Context) {
    val prefs: SharedPreferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    init {
        // Room and balance kept for a resident notification the app no longer has; don't leave them behind.
        if (LEGACY_KEYS.any(prefs::contains)) prefs.edit { LEGACY_KEYS.forEach { remove(it) } }
    }

    var lowBalanceThreshold: Double
        get() = prefs.getString(THRESHOLD, null)?.toDoubleOrNull() ?: 20.0
        set(value) {
            if (value.isFinite() && value > 0) prefs.edit { putString(THRESHOLD, value.toString()) }
        }

    var firstRunCompleted: Boolean
        get() = prefs.getBoolean(FIRST_RUN_COMPLETE, false)
        set(value) = prefs.edit { putBoolean(FIRST_RUN_COMPLETE, value) }

    var notificationPermissionDeferred: Boolean
        get() = prefs.getBoolean(NOTIFICATION_DEFERRED, false)
        set(value) = prefs.edit { putBoolean(NOTIFICATION_DEFERRED, value) }


    /** The privacy policy version the user agreed to; 0 means never. */
    var acceptedConsentVersion: Int
        get() = prefs.getInt(CONSENT_VERSION, 0)
        set(value) = prefs.edit { putInt(CONSENT_VERSION, value) }

    /** The chosen colour scheme's id; unknown values fall back to the default theme. */
    var themeId: String?
        get() = prefs.getString(THEME, null)
        set(value) = prefs.edit { putString(THEME, value) }

    /** People sharing the bill in the recharge planner. */
    var roommates: Int
        get() = prefs.getInt(ROOMMATES, 4).coerceIn(1, 12)
        set(value) = prefs.edit { putInt(ROOMMATES, value.coerceIn(1, 12)) }

    companion object {
        const val PREFS = "hbust_power_prefs"
        private const val THRESHOLD = "low_balance_threshold"
        const val FIRST_RUN_COMPLETE = "first_run_complete"
        private const val NOTIFICATION_DEFERRED = "notification_permission_deferred"
        private const val CONSENT_VERSION = "accepted_consent_version"
        private const val THEME = "theme_style"
        private const val ROOMMATES = "roommates"
        private val LEGACY_KEYS = listOf(
            "battery_optimization_request_shown", "summary_room", "summary_balance", "summary_time",
        )
    }
}

object KeychainAccounts {
    const val REDIRECT = "electricityRedirect"
}
