package com.zebwqfox.hbustpower.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import com.zebwqfox.hbustpower.model.Changelog
import com.zebwqfox.hbustpower.notification.PowerNotifications
import com.zebwqfox.hbustpower.ui.LargeTitleHeader
import com.zebwqfox.hbustpower.ui.PageColumn
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.components.GroupedRow
import com.zebwqfox.hbustpower.ui.components.GroupedSection
import com.zebwqfox.hbustpower.ui.openNotificationSettings
import com.zebwqfox.hbustpower.ui.theme.Power
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
            footer = "登录授权仅保存在本机，由 Android Keystore 加密；应用不保存密码。",
            rows = listOf(
                { GroupedRow("重新登录智慧湖科", icon = Icons.Filled.AccountCircle, disclosure = true, onClick = onLogin) },
                { GroupedRow("清除登录信息", icon = Icons.Filled.Delete, tint = colors.danger, titleColor = colors.danger) { dialog = "clear" } },
            ),
        )
        GroupedSection(
            "调试",
            footer = "离线演示用示例数据展示界面，不会访问学校系统，也不会发送提醒。",
            rows = listOf(
                { GroupedRow("调试与诊断", "通知 · 连接 · 日志", Icons.Filled.MedicalServices, stacked = true) { onOpen("debug") } },
                {
                    GroupedRow("离线演示", if (model.demoMode) "已开启" else "关闭", Icons.Filled.Science, disclosure = true) {
                        if (model.demoMode) model.exitDemo() else model.enterDemo()
                    }
                },
            ),
        )
        GroupedSection(
            "关于",
            rows = listOf(
                { GroupedRow("关于湖科电量", "开发者的话 · 更新日志", Icons.Filled.Bolt, stacked = true) { onOpen("about") } },
                { GroupedRow("更新日志", "版本 ${Changelog.latest.version}", Icons.AutoMirrored.Filled.List, stacked = true) { onOpen("changelog") } },
                { GroupedRow("隐私政策", "不收集个人信息 · 无服务器", Icons.Filled.PrivacyTip, stacked = true) { onOpen("legal:PRIVACY") } },
                { GroupedRow("用户服务协议", icon = Icons.Filled.Description, disclosure = true) { onOpen("legal:AGREEMENT") } },
            ),
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
