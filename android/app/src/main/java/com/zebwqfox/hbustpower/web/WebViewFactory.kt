package com.zebwqfox.hbustpower.web

import android.annotation.SuppressLint
import android.content.Context
import android.content.MutableContextWrapper
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView

/**
 * WebViews that outlive a single screen (the login page adopted by the campus card tab keeps its
 * sessionStorage) are built on a [MutableContextWrapper] around the application context, and borrow the
 * Activity only while attached.
 */
object WebViewFactory {
    @Volatile private var cachedUserAgent: String? = null

    /** The system WebView's own mobile user agent, shared by native requests (iOS 1.6.2 keeps them identical). */
    fun userAgent(context: Context): String = cachedUserAgent ?: runCatching {
        WebSettings.getDefaultUserAgent(context.applicationContext)
    }.getOrDefault(FALLBACK_USER_AGENT).also { cachedUserAgent = it }

    @SuppressLint("SetJavaScriptEnabled")
    fun create(context: Context, detachable: Boolean): WebView {
        val host = if (detachable) MutableContextWrapper(context.applicationContext) else context
        return WebView(host).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.javaScriptCanOpenWindowsAutomatically = true
            // window.open and target=_blank load in this same view, as the iOS createWebViewWith handler does.
            settings.setSupportMultipleWindows(false)
            settings.userAgentString = userAgent(context)
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            CookieManager.getInstance().setAcceptCookie(true)
            CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        }
    }

    /** Detaches from any old parent and points a detachable WebView at [activityContext]. */
    fun attach(webView: WebView, activityContext: Context): WebView {
        (webView.parent as? ViewGroup)?.removeView(webView)
        (webView.context as? MutableContextWrapper)?.baseContext = activityContext
        return webView
    }

    fun detach(webView: WebView) {
        (webView.parent as? ViewGroup)?.removeView(webView)
        (webView.context as? MutableContextWrapper)?.let { it.baseContext = it.applicationContext }
    }

    private const val FALLBACK_USER_AGENT =
        "Mozilla/5.0 (Linux; Android 16; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"
}
