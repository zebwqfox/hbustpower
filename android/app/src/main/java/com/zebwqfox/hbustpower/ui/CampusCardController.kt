package com.zebwqfox.hbustpower.ui

import android.graphics.Bitmap
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.viewModelScope
import com.zebwqfox.hbustpower.data.DemoData
import com.zebwqfox.hbustpower.data.Diagnostics
import com.zebwqfox.hbustpower.data.SchoolEndpoints
import com.zebwqfox.hbustpower.web.WebScripts
import com.zebwqfox.hbustpower.web.WebViewFactory
import com.zebwqfox.hbustpower.web.evaluate
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Port of iOS `CampusCardViewController`'s logic. Reads through the portal's own authenticated client in a
 * hidden WebView. After authorisation the very same WebView is adopted (sessionStorage belongs to it), with a
 * 25 s overall timeout and 500 ms readiness polling. Nothing from the portal session is logged.
 */
class CampusCardController(private val model: PowerViewModel, private val scripts: WebScripts) {
    var amount by mutableStateOf<Double?>(null); private set
    var cardCount by mutableStateOf(0); private set
    var note by mutableStateOf<String?>(null); private set
    var loading by mutableStateOf(false); private set
    var showConnect by mutableStateOf(true); private set

    /** The hidden page; the campus tab attaches it (1 px, invisible) so timers keep running. */
    var webView by mutableStateOf<WebView?>(null); private set

    private var generation = 0
    private var readJob: Job? = null
    private var watchdog: Job? = null
    private var portalEstablished = false
    private var adoptedReadPending = false

    fun onTabEntered() {
        if (adoptedReadPending) {
            adoptedReadPending = false
            return
        }
        refresh()
    }

    fun adoptPortal(portal: WebView) {
        cancel()
        webView?.takeIf { it !== portal }?.let { WebViewFactory.detach(it); it.destroy() }
        portal.webViewClient = client
        webView = portal
        portalEstablished = true
        adoptedReadPending = true
        Diagnostics.record("校园卡：接管已授权页面")
        refresh(reusePage = true)
    }

    fun refresh(reusePage: Boolean = false) {
        cancel()
        if (model.demoMode) {
            display(DemoData.CAMPUS_CARD_BALANCE, 1)
            note = "离线演示数据"
            return
        }
        note = if (amount != null) "更新中，显示上次余额" else null
        showConnect = false
        loading = true
        val page = webView ?: model.newAuthWebView().also { it.webViewClient = client; webView = it }
        if (!reusePage) {
            page.loadUrl(if (portalEstablished) SchoolEndpoints.CAMPUS_PORTAL_URL else model.authUrl)
        }
        Diagnostics.record("校园卡：" + if (reusePage) "继续授权页面" else if (portalEstablished) "刷新已有会话" else "恢复官方授权")
        val expected = generation
        val scope = model.viewModelScope
        watchdog = scope.launch {
            delay(25_000)
            if (generation == expected) failed("查询超时")
        }
        readJob = scope.launch {
            repeat(40) {
                delay(500)
                if (generation != expected) return@launch
                val url = page.url
                if (SchoolEndpoints.isLoginForm(url)) {
                    portalEstablished = false
                    failed("需要学习通授权")
                    return@launch
                }
                if (!SchoolEndpoints.isCampusPortal(url) || page.evaluate(scripts.campusReady) != true) return@repeat
                page.evaluate(scripts.campusReadStart)
                repeat(40) {
                    delay(250)
                    if (generation != expected) return@launch
                    val raw = page.evaluate(scripts.campusResult) as? String ?: return@repeat
                    val result = runCatching { JSONObject(raw) }.getOrNull()
                    val value = result?.optJSONObject("value")
                    val sum = value?.optDouble("amount", Double.NaN) ?: Double.NaN
                    val count = value?.optInt("count", 0) ?: 0
                    if (result?.optBoolean("ok") == true && sum.isFinite() && count > 0) {
                        portalEstablished = true
                        display(sum, count)
                    } else {
                        failed("余额接口未返回有效数据")
                    }
                    return@launch
                }
                failed("余额接口未返回有效数据")
                return@launch
            }
            if (generation == expected) failed("校园卡页面未就绪")
        }
    }

    /** Leaving the tab cancels reads so stale results never overwrite newer state. */
    fun cancel() {
        generation++
        readJob?.cancel()
        watchdog?.cancel()
        if (loading) {
            loading = false
            showConnect = amount == null
        }
    }

    fun onPageStopped() {
        cancel()
        webView?.stopLoading()
    }

    /** Sign-out, or demo mode ending: forget the portal session and the shown balance. */
    fun reset(destroyPage: Boolean) {
        cancel()
        portalEstablished = false
        adoptedReadPending = false
        amount = null
        cardCount = 0
        note = null
        showConnect = true
        if (destroyPage) webView?.let { WebViewFactory.detach(it); it.destroy() }
        if (destroyPage) webView = null
    }

    private fun display(value: Double, count: Int) {
        watchdog?.cancel()
        Diagnostics.record("校园卡：余额读取完成")
        amount = value
        cardCount = count
        note = if (count > 1) "$count 张校园卡合计" else null
        loading = false
        showConnect = false
    }

    private fun failed(reason: String) {
        generation++
        readJob?.cancel()
        watchdog?.cancel()
        Diagnostics.record("校园卡：$reason")
        loading = false
        showConnect = true
        note = if (amount != null) "余额未更新，可重新连接校园卡。" else "暂时无法读取余额，请连接校园卡后重试。"
    }

    private val client = object : WebViewClient() {
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
            !SchoolEndpoints.isAllowedNavigation(request.url.toString())

        override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) = Unit

        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            if (request.isForMainFrame && loading) failed("校园卡网络连接失败")
        }
    }
}
