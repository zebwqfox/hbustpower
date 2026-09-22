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
    const val CONSENT_VERSION = 3

    enum class Document(val title: String, internal val asset: String) {
        PRIVACY("隐私政策", "legal/privacy.md"),
        AGREEMENT("用户服务协议", "legal/agreement.md"),
    }

    fun text(context: Context, document: Document): String =
        context.assets.open(document.asset).bufferedReader().use { it.readText() }

    /** Short summary shown on the consent screen before the full text is opened. */
    val consentSummary = listOf(
        "本应用没有服务器，不收集你的个人信息，也不会把任何数据上传给开发者。",
        "登录使用学校指定的学习通认证，密码仅填入超星官方页面，应用不保存密码。",
        "授权链接与会话仅加密保存在本机，卸载即删除；可在设置中随时清除。",
        "只申请网络和通知两项权限，通知用于电量低于你设定值时提醒一次。",
        "未集成统计、广告、推送等第三方 SDK。",
    )
}
