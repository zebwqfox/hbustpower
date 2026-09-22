package com.zebwqfox.hbustpower.ui.screens

import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.zebwqfox.hbustpower.data.SchoolEndpoints
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.RoundIconButton
import com.zebwqfox.hbustpower.ui.theme.Power
import com.zebwqfox.hbustpower.web.WebViewFactory

/**
 * Port of iOS `RechargeViewController`: the school's own /pay/home in a WebView sharing the session cookies.
 * Payment is entirely the user's action on the official page; closing only refreshes, it never assumes success.
 */
@Composable
fun RechargeScreen(model: PowerViewModel, onClose: () -> Unit) {
    val colors = Power.colors
    val context = LocalContext.current
    var title by remember { mutableStateOf("官方电费充值") }
    var progress by remember { mutableFloatStateOf(0f) }
    var canBack by remember { mutableStateOf(false) }
    var canForward by remember { mutableStateOf(false) }
    val page = remember { WebViewFactory.create(context, detachable = false) }
    var finished by remember { mutableStateOf(false) }

    fun finish() {
        if (finished) return
        finished = true
        model.cookies.flush()
        model.refresh()
        onClose()
    }

    DisposableEffect(page) {
        page.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val uri = request.url
                return when (uri.scheme?.lowercase()) {
                    "http", "https" -> !SchoolEndpoints.isAllowedNavigation(uri.toString())
                    "about" -> false
                    else -> {
                        // Payment apps are opened by the system; the user completes payment there.
                        try { context.startActivity(Intent(Intent.ACTION_VIEW, uri)) } catch (_: ActivityNotFoundException) { }
                        true
                    }
                }
            }
            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                canBack = view.canGoBack(); canForward = view.canGoForward()
            }
            override fun onPageFinished(view: WebView, url: String?) {
                title = view.title?.takeIf { it.isNotBlank() && !it.startsWith("http") } ?: "官方电费充值"
                canBack = view.canGoBack(); canForward = view.canGoForward()
            }
        }
        page.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, newProgress: Int) { progress = newProgress / 100f }
        }
        page.loadUrl(SchoolEndpoints.RECHARGE_URL)
        onDispose {
            model.cookies.flush()
            page.stopLoading()
            page.destroy()
        }
    }

    BackHandler { if (page.canGoBack()) page.goBack() else finish() }

    Column(Modifier.fillMaxSize().background(colors.background).windowInsetsPadding(WindowInsets.safeDrawing)) {
        Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
            Box(Modifier.align(Alignment.CenterStart)) { RoundIconButton(Icons.Filled.Close, "关闭", ::finish) }
            Text(
                title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.align(Alignment.Center).padding(horizontal = 64.dp),
            )
        }
        if (progress < 1f) LinearProgressIndicator({ progress }, Modifier.fillMaxWidth().height(2.dp), color = colors.accent)
        else Box(Modifier.height(2.dp))
        AndroidView({ page }, Modifier.weight(1f).fillMaxWidth())
        Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            IconButton({ page.goBack() }, enabled = canBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "后退") }
            IconButton({ page.goForward() }, enabled = canForward) { Icon(Icons.AutoMirrored.Filled.ArrowForward, "前进") }
            IconButton({ page.reload() }) { Icon(Icons.Filled.Refresh, "刷新页面") }
        }
    }
}
