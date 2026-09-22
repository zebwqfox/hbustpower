package com.zebwqfox.hbustpower.model

import android.content.Context

/**
 * The privacy policy and user agreement shown in the app. The text is generated from the filing package
 * (`filing/03-隐私政策.md`, `filing/04-用户协议.md`) by `tools/sync-legal.py`, so the filed, published and
 * in-app versions cannot drift apart.
 */
object LegalDocuments {
    /**
     * Raise this whenever the policy text changes in a way users must see again; the consent screen
     * reappears for everyone whose stored acceptance is older.
     */
    const val CONSENT_VERSION = 4

    enum class Document(val title: String, internal val asset: String) {
        PRIVACY("隐私政策", "legal/privacy.md"),
        AGREEMENT("用户服务协议", "legal/agreement.md"),
    }

    fun text(context: Context, document: Document): String =
        context.assets.open(document.asset).bufferedReader().use { it.readText() }
}
