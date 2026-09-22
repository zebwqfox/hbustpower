package com.zebwqfox.hbustpower.ui.screens

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.data.CloudConfig
import com.zebwqfox.hbustpower.ui.theme.Power
import java.util.Locale

/**
 * The notice the developer published, shown as a card at the top of 电量. It is text only, it can be closed for
 * good, and it disappears on its own once `expiresAt` passes even if nothing new is published.
 */
@Composable
fun NoticeBanner(notice: CloudConfig.Notice?, onDismiss: () -> Unit) {
    val colors = Power.colors
    // AnimatedVisibility re-runs its content while the exit animation plays, and by then `notice` is already
    // null. Without holding on to the last one, closing the card empties it instantly and the animation just
    // shrinks a blank box. Keep it so the card itself fades out.
    var lastShown by remember { mutableStateOf<CloudConfig.Notice?>(null) }
    if (notice != null) lastShown = notice

    AnimatedVisibility(
        visible = notice != null,
        enter = if (Power.reduceMotion) fadeIn() else fadeIn() + expandVertically(),
        exit = if (Power.reduceMotion) fadeOut() else fadeOut() + shrinkVertically(),
    ) {
        val current = lastShown ?: return@AnimatedVisibility
        val warning = current.level == CloudConfig.Notice.Level.WARNING
        val tint = if (warning) colors.danger else colors.accent
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(tint.copy(alpha = if (colors.isDark) 0.16f else 0.08f))
                .border(1.dp, tint.copy(alpha = 0.28f), RoundedCornerShape(18.dp))
                .padding(start = 14.dp, top = 12.dp, bottom = 12.dp, end = 4.dp)
                .semantics { liveRegion = LiveRegionMode.Polite },
            verticalAlignment = Alignment.Top,
        ) {
            Icon(
                if (warning) Icons.Filled.WarningAmber else Icons.Filled.Campaign,
                null, tint = tint, modifier = Modifier.size(20.dp).padding(top = 2.dp),
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(current.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Text(current.body, fontSize = 14.sp, color = colors.secondaryText, lineHeight = 20.sp)
            }
            if (current.dismissible) {
                IconButton(onDismiss, Modifier.size(36.dp)) {
                    Icon(Icons.Filled.Close, "关闭公告", tint = colors.tertiaryText, modifier = Modifier.size(18.dp))
                }
            } else {
                Spacer(Modifier.width(10.dp))
            }
        }
    }
}

/**
 * Offers the new version. Downloading and installing is the user's own step: the dialog only opens the link in a
 * browser, so the app never fetches, stores or installs a package by itself.
 */
@Composable
fun UpdateDialog(
    update: CloudConfig.Update,
    required: Boolean,
    currentVersionName: String,
    onSkip: () -> Unit,
    onClose: () -> Unit,
    onDownload: () -> Unit,
) {
    val colors = Power.colors
    AlertDialog(
        // A required upgrade still closes: the app keeps working, the notice just comes back.
        onDismissRequest = onClose,
        title = { Text(if (required) "请更新到新版本" else "发现新版本 ${update.versionName}") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "当前 $currentVersionName，最新 ${update.versionName}" +
                        (update.sizeBytes?.let { " · ${readableSize(it)}" } ?: ""),
                    fontSize = 13.sp, color = colors.secondaryText,
                )
                if (required) {
                    Text("学校页面已经改版，这个版本可能读不到数据。", fontSize = 14.sp, color = colors.danger)
                }
                update.notes.forEach { note ->
                    Row(verticalAlignment = Alignment.Top) {
                        Text("·", fontSize = 14.sp, color = colors.accent)
                        Spacer(Modifier.width(8.dp))
                        Text(note, fontSize = 14.sp, lineHeight = 20.sp)
                    }
                }
                if (update.downloadUrl == null) {
                    Text("这份更新没有附带可用的下载地址，请到项目页面获取。", fontSize = 13.sp, color = colors.secondaryText)
                }
            }
        },
        confirmButton = {
            TextButton(onDownload, enabled = update.downloadUrl != null) { Text("去下载") }
        },
        dismissButton = {
            TextButton(if (required) onClose else onSkip) { Text(if (required) "稍后" else "跳过这个版本") }
        },
    )
}

/** Hands the link to the browser; the app has no download or install permission of its own. */
fun openDownload(context: Context, url: String) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(context, "没有可用的浏览器", Toast.LENGTH_SHORT).show()
    }
}

private fun readableSize(bytes: Long): String =
    if (bytes >= 1024 * 1024) String.format(Locale.ROOT, "%.1f MB", bytes / 1024.0 / 1024.0)
    else String.format(Locale.ROOT, "%d KB", bytes / 1024)

/**
 * Shown in place of a feature the developer switched off, normally because the school changed a page and the
 * old path now fails. Switches fail open, so this only appears when the config explicitly says `false`.
 */
@Composable
fun FeatureUnavailable(title: String, detail: String) {
    val colors = Power.colors
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(colors.surface)
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Filled.WarningAmber, null, tint = colors.secondaryText, modifier = Modifier.size(30.dp))
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        Text(detail, fontSize = 14.sp, color = colors.secondaryText, lineHeight = 20.sp)
    }
}
