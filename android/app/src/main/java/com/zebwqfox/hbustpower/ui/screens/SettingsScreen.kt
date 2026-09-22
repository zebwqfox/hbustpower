package com.zebwqfox.hbustpower.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.SystemUpdateAlt
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Switch
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.zebwqfox.hbustpower.BuildConfig
import com.zebwqfox.hbustpower.data.CloudRefreshTrigger
import com.zebwqfox.hbustpower.model.Changelog
import com.zebwqfox.hbustpower.notification.PowerNotifications
import com.zebwqfox.hbustpower.ui.LargeTitleHeader
import com.zebwqfox.hbustpower.ui.PageColumn
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.components.GroupedRow
import com.zebwqfox.hbustpower.ui.components.GroupedSection
import com.zebwqfox.hbustpower.ui.openNotificationSettings
import com.zebwqfox.hbustpower.ui.theme.Power
import android.widget.Toast
import java.text.DateFormat
import java.util.Date
import java.util.Locale

@Composable
fun SettingsScreen(model: PowerViewModel, onOpen: (String) -> Unit, onLogin: () -> Unit) {
    val colors = Power.colors
    val context = LocalContext.current
    var dialog by rememberSaveable { mutableStateOf<String?>(null) }
    var resumes by remember { mutableIntStateOf(0) }
    val owner = LocalLifecycleOwner.current
    // Coming back from system notification settings should show the new state.
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) resumes++ }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    val notificationsReady = remember(resumes) { PowerNotifications.canPost(context) }

    // A manual check should say something either way, including "已是最新"; the launch check stays silent.
    var awaitingCheck by remember { mutableStateOf(false) }
    var updateDialog by remember { mutableStateOf(false) }
    LaunchedEffect(model.cloudState.isChecking) {
        if (model.cloudState.isChecking || !awaitingCheck) return@LaunchedEffect
        awaitingCheck = false
        val error = model.cloudState.error
        when {
            error != null -> Toast.makeText(context, error, Toast.LENGTH_SHORT).show()
            model.pendingUpdate != null -> updateDialog = true
            else -> Toast.makeText(context, "已是最新版本", Toast.LENGTH_SHORT).show()
        }
    }

    PageColumn(spacing = 22.dp) {
        LargeTitleHeader("设置")
        GroupedSection(
            "提醒",
            footer = "打开应用或回到前台更新时，电量首次低于设定值时提醒一次；回升后再次变低会重新提醒。需允许系统通知。",
            rows = listOf(
                { GroupedRow("低电量提醒", String.format(Locale.ROOT, "低于 %.0f 度", model.lowBalanceThreshold), Icons.Filled.NotificationsActive, disclosure = true) { dialog = "threshold" } },
                { GroupedRow("系统通知", if (notificationsReady) "已允许" else "未开启", Icons.Filled.Tune, disclosure = true) { openNotificationSettings(context) } },
            ),
        )
        GroupedSection(
            "外观",
            rows = listOf(
                { GroupedRow("主题", model.theme.displayName, Icons.Filled.Palette, disclosure = true) { onOpen("theme") } },
            ),
        )
        GroupedSection(
            "账户",
            rows = listOf(
                { GroupedRow("重新登录智慧湖科", icon = Icons.Filled.AccountCircle, disclosure = true, onClick = onLogin) },
                { GroupedRow("清除登录信息", icon = Icons.Filled.Delete, tint = colors.danger, titleColor = colors.danger) { dialog = "clear" } },
            ),
        )
        if (model.isUpdateCheckAvailable) {
            GroupedSection(
                "更新",
                footer = "每次启动检查一次，只读取作者站点上的一个版本信息文件，不上传任何内容；应用不会自行下载或安装，点“去下载”后在浏览器里完成。",
                rows = listOf(
                    {
                        GroupedRow(
                            "检查更新",
                            when {
                                model.cloudState.isChecking -> "正在检查…"
                                model.pendingUpdate != null -> "有新版本 ${model.pendingUpdate?.versionName}"
                                else -> lastCheckedText(model.cloudState.lastCheckedAtEpochSeconds)
                            },
                            Icons.Filled.SystemUpdateAlt, stacked = true, enabled = !model.cloudState.isChecking,
                        ) {
                            awaitingCheck = true
                            model.checkForUpdates(CloudRefreshTrigger.MANUAL)
                        }
                    },
                ),
            )
        }
        if (model.isTelemetryAvailable) {
            GroupedSection(
                "帮助改进",
                footer = "每天最多上报一次：应用版本、系统版本、设备型号和一个随机生成的安装标识。" +
                    "不含账号、宿舍号、电量或任何位置信息，也不读取设备识别码。关掉后本机标识一并删除，不影响任何功能。",
                rows = listOf(
                    {
                        GroupedRow(
                            "匿名使用统计",
                            if (model.telemetryEnabled) "已开启" else "已关闭",
                            Icons.Filled.Insights,
                            stacked = true,
                            trailing = {
                                Switch(model.telemetryEnabled, { model.updateTelemetryEnabled(it) })
                            },
                        )
                    },
                    { GroupedRow("看看会上报什么", "逐项列出，可复制", disclosure = true) { dialog = "telemetry" } },
                ),
            )
        }
        GroupedSection(
            "调试",
            rows = listOf(
                { GroupedRow("调试与诊断", "通知 · 连接 · 日志", Icons.Filled.MedicalServices, stacked = true) { onOpen("debug") } },
            ),
        )
        GroupedSection(
            "关于",
            rows = listOf(
                { GroupedRow("关于湖科电量", "开发者的话 · 更新日志", Icons.Filled.Bolt, stacked = true) { onOpen("about") } },
                { GroupedRow("更新日志", "版本 ${Changelog.latest.version}", Icons.AutoMirrored.Filled.List, stacked = true) { onOpen("changelog") } },
                { GroupedRow("隐私政策", "不上传电量数据 · 统计可关闭", Icons.Filled.PrivacyTip, stacked = true) { onOpen("legal:PRIVACY") } },
                { GroupedRow("用户服务协议", icon = Icons.Filled.Description, disclosure = true) { onOpen("legal:AGREEMENT") } },
            ),
        )
    }

    if (dialog == "telemetry") {
        AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("会上报这些") },
            text = {
                Column {
                    model.telemetryPreview().forEach { (label, value) ->
                        Text("$label：$value", modifier = Modifier.padding(vertical = 3.dp))
                    }
                    Text(
                        "发往 ${model.telemetryHost ?: "未配置"}。除此之外不上报任何内容。",
                        color = colors.secondaryText,
                        modifier = Modifier.padding(top = 10.dp),
                    )
                }
            },
            confirmButton = { TextButton({ dialog = null }) { Text("知道了") } },
            dismissButton = {
                TextButton({ model.resetTelemetryId(); dialog = null }) { Text("重置安装标识") }
            },
        )
    }

    model.pendingUpdate?.takeIf { updateDialog }?.let { update ->
        UpdateDialog(
            update = update,
            required = model.mustUpgrade,
            currentVersionName = BuildConfig.VERSION_NAME,
            onSkip = { model.skipUpdate(); updateDialog = false },
            onClose = { updateDialog = false },
            onDownload = {
                update.downloadUrl?.let { openDownload(context, it) }
                updateDialog = false
            },
        )
    }

    when (dialog) {
        "threshold" -> ThresholdDialog(model.lowBalanceThreshold, { dialog = null }) { model.updateThreshold(it); dialog = null }
        "clear" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("清除登录信息？") },
            text = { Text("下次查询时需要重新登录智慧湖科。") },
            confirmButton = { TextButton({ model.clearLogin(); dialog = null }) { Text("清除", color = colors.danger) } },
            dismissButton = { TextButton({ dialog = null }) { Text("取消") } },
        )
    }
}
@Composable
private fun ThresholdDialog(current: Double, onDismiss: () -> Unit, onSave: (Double) -> Unit) {
    var text by rememberSaveable { mutableStateOf(String.format(Locale.ROOT, "%.0f", current)) }
    val value = text.toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("低电量提醒") },
        text = {
            OutlinedTextField(
                text, { text = it }, singleLine = true,
                label = { Text("剩余电量低于多少度时提醒？") }, placeholder = { Text("例如 20") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                isError = text.isNotEmpty() && value == null,
            )
        },
        confirmButton = { TextButton({ value?.let(onSave) }, enabled = value != null) { Text("保存") } },
        dismissButton = { TextButton(onDismiss) { Text("取消") } },
    )
}

/** "今天 14:30 检查过" reads better than a raw timestamp, and "从未检查" is the honest empty state. */
private fun lastCheckedText(epochSeconds: Long): String {
    if (epochSeconds <= 0) return "从未检查"
    val formatted = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT).format(Date(epochSeconds * 1000))
    return "上次检查 $formatted"
}
