package com.zebwqfox.hbustpower.ui.screens

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.zebwqfox.hbustpower.BuildConfig
import com.zebwqfox.hbustpower.data.Diagnostics
import com.zebwqfox.hbustpower.data.SchoolEndpoints
import com.zebwqfox.hbustpower.notification.PowerNotifications
import com.zebwqfox.hbustpower.ui.DetailPage
import com.zebwqfox.hbustpower.ui.PowerStatus
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.RoundIconButton
import com.zebwqfox.hbustpower.ui.components.GroupedRow
import com.zebwqfox.hbustpower.ui.components.GroupedSection
import com.zebwqfox.hbustpower.ui.openNotificationSettings
import com.zebwqfox.hbustpower.ui.theme.Power
import java.time.ZonedDateTime
import java.util.Locale

private data class DebugRow(val title: String, val detail: String, val action: (() -> Unit)? = null)
private data class DebugSection(val title: String, val footer: String?, val rows: List<DebugRow>)

@Composable
fun DebugScreen(model: PowerViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val events by Diagnostics.events.collectAsState()
    var version by remember { mutableIntStateOf(0) }
    var result by remember { mutableStateOf("选择一项测试，结果会显示在这里。") }
    var copied by remember { mutableStateOf(false) }
    val reduceMotion = Power.reduceMotion

    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) version++ }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        result = "当前权限：" + (if (granted) "已允许。" else "已拒绝。请前往系统设置开启。")
        Diagnostics.record("检查通知权限：" + if (granted) "已允许" else "已拒绝")
        version++
    }

    fun runTest(block: () -> String) {
        result = try { block() } catch (error: Exception) {
            Diagnostics.record("调试操作失败：" + Diagnostics.errorSummary(error))
            error.message ?: "测试失败"
        }
        version++
    }

    // Re-read permission state whenever the screen resumes, for example after visiting system settings.
    val runtimeGranted = remember(version) { PowerNotifications.runtimePermissionGranted(context) }
    val appEnabled = remember(version) { NotificationManagerCompat.from(context).areNotificationsEnabled() }
    val snapshot = model.snapshot
    val statusText = when (model.status) {
        PowerStatus.Idle -> "等待启动"
        PowerStatus.Loading -> "正在连接"
        PowerStatus.Ready -> if (model.demoMode) "已取得演示电量" else "已取得电量"
        PowerStatus.AuthenticationRequired -> "需要登录"
        is PowerStatus.Error -> "连接失败（详见刷新结果）"
    }
    val sections = listOf(
        DebugSection(
            "通知状态", "Android 13 起需要通知运行时权限；渠道被关闭时横幅和声音不会出现。勿扰模式也会影响显示。", listOf(
                DebugRow("系统权限", if (Build.VERSION.SDK_INT < 33) "无需运行时授权（Android 12 及以下）" else if (runtimeGranted) "已允许" else "未允许"),
                DebugRow("应用通知 · 低电量渠道 · 测试渠道",
                    "${onOff(appEnabled)} · ${onOff(PowerNotifications.channelEnabled(context, PowerNotifications.LOW_BALANCE_CHANNEL))} · ${onOff(PowerNotifications.channelEnabled(context, PowerNotifications.TEST_CHANNEL))}"),
                DebugRow("测试通知", "待发送 ${model.debugNotifications.pendingCount} 条 · 通知栏保留 ${model.debugNotifications.deliveredCount} 条"),
                DebugRow("申请通知权限", "尚未允许时显示系统授权弹窗") {
                    if (Build.VERSION.SDK_INT >= 33 && !runtimeGranted) permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    else { result = "当前权限：" + if (PowerNotifications.canPost(context)) "已允许。" else "通知被关闭，请前往系统设置开启。"; version++ }
                },
                DebugRow("打开系统通知设置", "修改横幅、声音和锁屏显示") { openNotificationSettings(context) },
            ),
        ),
        DebugSection(
            "通知测试", "低电量样式使用虚构的 12.50 度，仅测试通知显示。实际提醒仍在电量刷新后判断，测试不会修改真实电量或去重记录。", listOf(
                DebugRow("立即发送", "在应用前台检查通知") { runTest { model.debugNotifications.send(0); "系统已接受。请检查横幅或通知栏。" } },
                DebugRow("10 秒后发送", "点击后切到后台或锁屏") { runTest { model.debugNotifications.send(10); "已安排，将在 10 秒后发送。现在可以切到后台或锁屏。" } },
                DebugRow("测试低电量样式", "模拟低于 20 度的提醒文案") { runTest { model.debugNotifications.send(0, lowBalance = true); "系统已接受。请检查横幅或通知栏。" } },
                DebugRow("清除测试通知", "取消待发送测试，并移除已投递测试") { runTest { model.debugNotifications.clearTests(); "测试通知已清除。" } },
                DebugRow("最近操作", result),
            ) + if (!BuildConfig.DEBUG) emptyList() else listOf(
                DebugRow("模拟低电量检查", "用 ${String.format(Locale.ROOT, "%.2f", model.lowBalanceThreshold - 0.01)} 度走真实提醒逻辑，不改变已显示的电量") {
                    model.simulateLowBalanceCheck(model.lowBalanceThreshold - 0.01) { result = it; version++ }
                },
                DebugRow("模拟电量回升", "用 ${String.format(Locale.ROOT, "%.2f", model.lowBalanceThreshold + 50)} 度重置提醒状态") {
                    model.simulateLowBalanceCheck(model.lowBalanceThreshold + 50) { result = it; version++ }
                },
            ),
        ),
        DebugSection(
            "连接与数据", "刷新会读取学校真实数据，并执行正常低电量检查（演示模式不发提醒）。", listOf(
                DebugRow("当前状态", statusText),
                DebugRow("运行模式", if (model.demoMode) "离线演示" else "学校数据"),
                DebugRow("本机登录凭据", if (model.hasSavedLogin) "已保存（有效性以连接结果为准）" else "未保存"),
                DebugRow("学校会话 Cookie", "${model.cookies.count(SchoolEndpoints.sessionCookieUrls)} 条"),
                DebugRow("最近刷新", model.lastRefreshResult + (model.lastRefreshDurationMillis?.let { String.format(Locale.ROOT, " · %.2f 秒", it / 1000.0) } ?: "")),
                DebugRow("数据时间", snapshot?.let { formatDateTime(it.fetchedAt) } ?: "尚无数据"),
                DebugRow("电量与提醒值", (snapshot?.let { String.format(Locale.ROOT, "剩余 %.2f 度", it.purchasedKWh) } ?: "剩余未知") + String.format(Locale.ROOT, " · 低于 %.0f 度提醒", model.lowBalanceThreshold)),
                DebugRow("低电量提醒状态", model.reminderDiagnostic),
                DebugRow("数据条数", "设备 ${snapshot?.meters?.size ?: 0} · 用量 ${snapshot?.usageRecords?.size ?: 0} · 充值 ${snapshot?.rechargeRecords?.size ?: 0}"),
                DebugRow("重新读取电量", if (model.status == PowerStatus.Loading) "正在刷新，请稍候" else "重新连接学校系统") { model.refresh() },
            ),
        ),
        DebugSection(
            "运行环境", null, listOf(
                DebugRow("应用版本", "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"),
                DebugRow("系统与设备", "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) · ${Build.MANUFACTURER} ${Build.MODEL}"),
                DebugRow("减少动态效果", if (reduceMotion) "已开启（动画时长缩放为 0）" else "未开启"),
            ),
        ),
        DebugSection(
            "本次运行日志", "最多保留 60 条，重启清空。右上角可复制诊断报告；不包含账户、宿舍号、授权链接或 Cookie 内容。", listOf(
                DebugRow("最近事件", events.reversed().joinToString("\n").ifEmpty { "暂无事件" }),
            ),
        ),
    )

    DetailPage(
        "调试与诊断", onBack, Icons.AutoMirrored.Filled.ArrowBack,
        actions = {
            RoundIconButton(Icons.Filled.ContentCopy, "复制诊断报告", {
                val report = sections.joinToString("\n\n") { section ->
                    section.title + "\n" + section.rows.filter { it.action == null && it.title != "最近操作" }
                        .joinToString("\n") { "${it.title}: ${it.detail}" }
                }
                copyText(context, "湖科电量诊断 · ${formatDateTime(ZonedDateTime.now().toInstant())}\n\n$report")
                result = "诊断报告已复制。"
                copied = true
            })
        },
    ) {
        sections.forEach { section ->
            GroupedSection(section.title, section.footer, rows = section.rows.map { row ->
                { GroupedRow(row.title, row.detail, stacked = true, onClick = row.action) }
            })
        }
    }

    if (copied) {
        AlertDialog(
            onDismissRequest = { copied = false },
            title = { Text("已复制诊断报告") },
            text = { Text("可粘贴到反馈中，方便排查问题。") },
            confirmButton = { TextButton({ copied = false }) { Text("好") } },
        )
    }
}

private fun onOff(value: Boolean) = if (value) "开" else "关"
