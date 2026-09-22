package com.zebwqfox.hbustpower.ui.screens

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.zebwqfox.hbustpower.data.CloudConfig
import com.zebwqfox.hbustpower.ui.LargeTitleHeader
import com.zebwqfox.hbustpower.ui.PageColumn
import com.zebwqfox.hbustpower.ui.PowerStatus
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.RoundIconButton
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.theme.Power
import com.zebwqfox.hbustpower.web.WebViewFactory
import java.util.Locale

@Composable
fun CampusScreen(model: PowerViewModel, onConnect: () -> Unit) {
    val colors = Power.colors
    val card = model.campusCard
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current

    // Switched off from the published config, normally right after the card portal changes and the read breaks.
    if (!model.isFeatureEnabled(CloudConfig.FLAG_CAMPUS_CARD)) {
        PageColumn(spacing = 24.dp) {
            LargeTitleHeader("校园卡")
            FeatureUnavailable("校园卡暂时不可用", "一卡通门户改版后这里读不到余额，修好会随新版本恢复。电量查询不受影响。")
        }
        return
    }

    // Entering the tab reads; leaving cancels so stale results never overwrite newer ones.
    DisposableEffect(card) {
        card.onTabEntered()
        onDispose { card.onPageStopped() }
    }
    // Returning from the official recharge page re-queries (iOS didBecomeActive).
    DisposableEffect(owner, card) {
        var paused = false
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE) paused = true
            if (event == Lifecycle.Event.ON_RESUME && paused) { paused = false; card.refresh() }
        }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    // Signing out (without a saved login) forgets the portal session as well.
    LaunchedEffect(model.status, model.hasSavedLogin) {
        if (model.status == PowerStatus.AuthenticationRequired && !model.hasSavedLogin) card.reset(destroyPage = true)
    }

    Box {
        card.webView?.let { page ->
            AndroidView(
                factory = { WebViewFactory.attach(page, context) },
                modifier = Modifier.size(1.dp).semantics { contentDescription = "" },
                onRelease = { WebViewFactory.detach(it) },
            )
        }
        PageColumn(spacing = 24.dp) {
            LargeTitleHeader("校园卡") {
                RoundIconButton(Icons.Filled.Refresh, "刷新余额", { card.refresh() }, enabled = !card.loading)
            }
            val shape = RoundedCornerShape(30.dp)
            Column(
                Modifier
                    .fillMaxWidth()
                    .shadow(if (colors.isDark) 0.dp else 12.dp, shape, ambientColor = colors.accent.copy(alpha = 0.15f), spotColor = colors.accent.copy(alpha = 0.18f))
                    .clip(shape)
                    .background(colors.hero)
                    .border(0.8.dp, Color.White.copy(alpha = if (colors.isDark) 0.08f else 0.75f), shape)
                    .padding(horizontal = 24.dp, vertical = 32.dp)
                    .semantics(mergeDescendants = true) {
                        contentDescription = card.amount?.let { String.format(Locale.ROOT, "校园卡余额 %.2f 元", it) } ?: "校园卡余额未知"
                    },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                Icon(Icons.Filled.CreditCard, null, tint = colors.accent, modifier = Modifier.size(38.dp))
                Text("校园卡余额", color = colors.accent, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    card.amount?.let { String.format(Locale.ROOT, "¥ %.2f", it) } ?: "—",
                    fontSize = 56.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
                )
                if (card.loading) CircularProgressIndicator(Modifier.size(22.dp), color = colors.accent, strokeWidth = 2.dp)
                card.note?.let { Text(it, color = colors.secondaryText, fontSize = 13.sp, textAlign = TextAlign.Center) }
            }
            if (card.showConnect) {
                PowerButton("连接校园卡", onConnect, icon = Icons.Filled.Person)
            }
            if (model.isFeatureEnabled(CloudConfig.FLAG_RECHARGE)) {
                PowerButton(
                    "前往智慧湖科充值",
                    onClick = {
                        try {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(model.authUrl)))
                        } catch (_: ActivityNotFoundException) {
                            android.widget.Toast.makeText(context, "无法打开智慧湖科，请稍后重试。", android.widget.Toast.LENGTH_SHORT).show()
                        }
                    },
                    icon = Icons.AutoMirrored.Filled.OpenInNew,
                    primary = true,
                )
                Text(
                    "在学校官方网页中自行选择卡片充值，本应用不会代为付款。返回应用后会重新查询余额。",
                    color = colors.secondaryText, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
