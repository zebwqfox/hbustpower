package com.zebwqfox.hbustpower.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.NavigationRailItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.activity.compose.LocalActivity
import com.zebwqfox.hbustpower.model.FirstRunFlow
import com.zebwqfox.hbustpower.model.LegalDocuments
import com.zebwqfox.hbustpower.model.MeterKind
import com.zebwqfox.hbustpower.notification.PowerNotifications
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.rememberHaptics
import com.zebwqfox.hbustpower.ui.components.reveal
import com.zebwqfox.hbustpower.ui.screens.AboutScreen
import com.zebwqfox.hbustpower.ui.screens.CampusScreen
import com.zebwqfox.hbustpower.ui.screens.ChangelogScreen
import com.zebwqfox.hbustpower.ui.screens.DebugScreen
import com.zebwqfox.hbustpower.ui.screens.LegalScreen
import com.zebwqfox.hbustpower.ui.screens.LoginScreen
import com.zebwqfox.hbustpower.ui.screens.PrivacyConsentScreen
import com.zebwqfox.hbustpower.ui.screens.OverviewScreen
import com.zebwqfox.hbustpower.ui.screens.RechargeScreen
import com.zebwqfox.hbustpower.ui.screens.RecordDetailScreen
import com.zebwqfox.hbustpower.ui.screens.RecordsScreen
import com.zebwqfox.hbustpower.ui.screens.SettingsScreen
import com.zebwqfox.hbustpower.ui.screens.ThemePickerScreen
import com.zebwqfox.hbustpower.ui.screens.UsageScreen
import com.zebwqfox.hbustpower.ui.theme.Power

private enum class MainTab(val title: String) { OVERVIEW("电量"), USAGE("用量"), RECORDS("充值记录"), CAMPUS("校园卡"), SETTINGS("设置") }

@Composable
fun HbustPowerApp(model: PowerViewModel) {
    val layout = rememberPowerLayout()
    val lifecycle = LocalLifecycleOwner.current
    val context = LocalContext.current
    DisposableEffect(lifecycle, model) {
        var resumedOnce = false
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                model.firstRun.refreshAuthorization(PowerNotifications.canPost(context))
                // The first resume is startup; later ones are returns to the foreground.
                if (resumedOnce) model.onForeground()
                resumedOnce = true
            }
        }
        lifecycle.lifecycle.addObserver(observer)
        onDispose { lifecycle.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(model.firstRunCompleted, model.privacyAccepted) { model.start() }
    val reduceMotion = Power.reduceMotion
    CompositionLocalProvider(LocalPowerLayout provides layout) {
        Box(Modifier.fillMaxSize().background(Power.colors.background)) {
            AnimatedContent(
                model.firstRunCompleted,
                transitionSpec = { fadeIn(tween(if (reduceMotion) 150 else 300)) togetherWith fadeOut(tween(150)) },
                label = "first-run",
            ) { completed ->
                when {
                    !model.privacyAccepted -> ConsentGate(model)
                    completed -> MainShell(model)
                    else -> FirstRunScreen(model)
                }
            }
        }
    }
}

/** Privacy policy first: nothing runs until the user agrees, and the two documents open in place. */
@Composable
private fun ConsentGate(model: PowerViewModel) {
    val activity = LocalActivity.current
    var reading by rememberSaveable { mutableStateOf<String?>(null) }
    BackHandler(reading != null) { reading = null }
    val document = reading?.let { LegalDocuments.Document.valueOf(it) }
    if (document != null) {
        LegalScreen(document) { reading = null }
    } else {
        PrivacyConsentScreen(
            onAgree = model::acceptPrivacy,
            onDecline = { activity?.finishAndRemoveTask() },
            onOpenDocument = { reading = it.name },
        )
    }
}

/** iOS `FirstRunViewController`: notification permission, then a short introduction; completed once. */
@Composable
private fun FirstRunScreen(model: PowerViewModel) {
    val colors = Power.colors
    val context = LocalContext.current
    val flow = model.firstRun
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> flow.onPermissionResult(granted) }
    BackHandler(flow.step == FirstRunFlow.Step.INTRODUCTION) { flow.back() }
    val intro = flow.step == FirstRunFlow.Step.INTRODUCTION
    val (heading, detail, primary) = when (flow.step) {
        FirstRunFlow.Step.PERMISSION_DENIED -> Triple("通知未开启", "可在系统设置中开启，也可以继续使用。", "打开设置")
        FirstRunFlow.Step.INTRODUCTION -> Triple("电量，心中有数", "首页看剩余电量与预计时长，下拉刷新。", "开始使用")
        else -> Triple("低电量时提醒", flow.error ?: "开启通知，在电量更新后接收低电量提醒。", "开启通知")
    }
    PageColumn(maxWidth = 420.dp, topPadding = 64.dp, spacing = 24.dp) {
        AnimatedContent(flow.step, label = "first-run-step") { step ->
            Column(Modifier.fillMaxWidth().statusBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
                Icon(
                    if (step == FirstRunFlow.Step.INTRODUCTION) Icons.Filled.Bolt else Icons.Filled.NotificationsActive, null,
                    tint = colors.accent, modifier = Modifier.size(96.dp).reveal(0, step),
                )
                Text(
                    heading, fontSize = 34.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                    modifier = Modifier.reveal(1, step).semantics { heading(); liveRegion = LiveRegionMode.Polite },
                )
                Text(detail, color = colors.secondaryText, fontSize = 17.sp, textAlign = TextAlign.Center, modifier = Modifier.reveal(2, step))
            }
        }
        Spacer(Modifier.height(20.dp))
        PowerButton(
            primary,
            onClick = {
                when (flow.step) {
                    FirstRunFlow.Step.INTRODUCTION -> if (flow.finish()) model.completeFirstRun()
                    FirstRunFlow.Step.PERMISSION_DENIED -> openNotificationSettings(context)
                    FirstRunFlow.Step.PERMISSION -> {
                        val needsDialog = Build.VERSION.SDK_INT >= 33
                        if (flow.requestPermission(PowerNotifications.canPost(context), needsDialog)) {
                            runCatching { launcher.launch(Manifest.permission.POST_NOTIFICATIONS) }.onFailure { flow.onPermissionRequestFailed() }
                        }
                    }
                    FirstRunFlow.Step.FINISHED -> Unit
                }
            },
            primary = true, loading = flow.busy,
        )
        if (!intro) {
            TextButton(flow::continueWithoutPermission, enabled = !flow.busy, modifier = Modifier.fillMaxWidth()) {
                Text(if (flow.step == FirstRunFlow.Step.PERMISSION_DENIED) "继续" else "暂不开启", color = colors.accent, fontSize = 17.sp)
            }
        } else {
            TextButton(flow::back, enabled = !flow.busy, modifier = Modifier.fillMaxWidth()) { Text("返回", color = colors.accent, fontSize = 17.sp) }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            listOf(false, true).forEach { isIntroDot ->
                Box(
                    Modifier.padding(4.dp).size(8.dp).clip(CircleShape)
                        .background(if (isIntroDot == intro) colors.accent else colors.separator),
                )
            }
        }
    }
}

@Composable
private fun MainShell(model: PowerViewModel) {
    val colors = Power.colors
    val haptics = rememberHaptics()
    val layout = LocalPowerLayout.current
    var selected by rememberSaveable { mutableIntStateOf(0) }
    val routes = rememberSaveable(saver = listSaver({ it.toList() }, { it.toMutableStateList() })) { mutableStateListOf<String>() }
    var overlay by rememberSaveable { mutableStateOf<String?>(null) }
    var usageFocus by rememberSaveable { mutableStateOf<String?>(null) }
    var usageFocusToken by rememberSaveable { mutableIntStateOf(0) }

    fun select(index: Int) {
        if (index != selected) haptics.selection()
        selected = index
        routes.clear()
    }
    fun openUsage(kind: MeterKind?) {
        if (kind != null) { usageFocus = kind.name; usageFocusToken++ }
        select(MainTab.USAGE.ordinal)
    }
    fun openRecharge() {
        // A refresh can temporarily move a valid session out of Ready. The recharge page uses the
        // shared WebView cookies directly, so do not turn a tap into a silent no-op during that window.
        overlay = "recharge"
    }
    val openLogin = { overlay = "login" }

    // Overlays with their own web history register a later BackHandler, which takes precedence.
    BackHandler(overlay != null) { overlay = null }
    BackHandler(overlay == null && (routes.isNotEmpty() || selected != 0)) {
        if (routes.isNotEmpty()) routes.removeAt(routes.lastIndex) else select(0)
    }

    val pageContent: @Composable () -> Unit = {
        val route = routes.lastOrNull()
        AnimatedContent(route ?: "tab:$selected", transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) }, label = "page") { key ->
            val pop = { if (routes.isNotEmpty()) routes.removeAt(routes.lastIndex) }
            val push = { name: String -> routes.add(name); Unit }
            when {
                key == "about" -> AboutScreen(onBack = pop, onOpen = push)
                key == "changelog" -> ChangelogScreen(onBack = pop)
                key == "debug" -> DebugScreen(model, onBack = pop)
                key == "theme" -> ThemePickerScreen(model, onBack = pop)
                key.startsWith("legal:") -> LegalScreen(LegalDocuments.Document.valueOf(key.removePrefix("legal:")), onBack = pop)
                key.startsWith("record:") -> RecordDetailScreen(model, key.removePrefix("record:").toInt(), onBack = pop)
                else -> when (MainTab.entries[selected]) {
                    MainTab.OVERVIEW -> OverviewScreen(model, ::openUsage, { select(MainTab.RECORDS.ordinal) }, openLogin, ::openRecharge)
                    MainTab.USAGE -> UsageScreen(model, usageFocus?.let(MeterKind::valueOf), usageFocusToken)
                    MainTab.RECORDS -> RecordsScreen(model, { routes.add("record:$it") }, openLogin, ::openRecharge)
                    MainTab.CAMPUS -> CampusScreen(model) { overlay = "campus-login" }
                    MainTab.SETTINGS -> SettingsScreen(model, push, openLogin)
                }
            }
        }
    }
    val page: @Composable () -> Unit = { Box(Modifier.fillMaxSize()) { pageContent(); StatusBarScrim() } }
    val icons = listOf(Icons.Filled.Bolt, Icons.Filled.BarChart, Icons.Filled.History, Icons.Filled.CreditCard, Icons.Filled.Settings)

    Box(Modifier.fillMaxSize()) {
        if (layout.isWide) {
            // Wide windows (unfolded, tablets, desktop windows): a rail keeps both columns usable.
            Row(Modifier.fillMaxSize()) {
                NavigationRail(
                    containerColor = colors.background,
                    modifier = Modifier
                        .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Start + WindowInsetsSides.Vertical))
                        // Five destinations do not fit a landscape phone's height, so the rail scrolls.
                        .verticalScroll(rememberScrollState()),
                ) {
                    Spacer(Modifier.height(12.dp))
                    MainTab.entries.forEachIndexed { index, tab ->
                        NavigationRailItem(
                            selected = selected == index, onClick = { select(index) },
                            icon = { Icon(icons[index], null) }, label = { Text(tab.title) },
                            colors = NavigationRailItemDefaults.colors(selectedIconColor = colors.accent, selectedTextColor = colors.accent, indicatorColor = colors.hero),
                        )
                    }
                }
                Box(Modifier.weight(1f).consumeWindowInsets(WindowInsets.safeDrawing.only(WindowInsetsSides.Start))) { page() }
            }
        } else {
            Column(Modifier.fillMaxSize()) {
                Box(Modifier.weight(1f).consumeWindowInsets(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom))) { page() }
                NavigationBar(containerColor = colors.surface.copy(alpha = 0.96f)) {
                    MainTab.entries.forEachIndexed { index, tab ->
                        NavigationBarItem(
                            selected = selected == index, onClick = { select(index) },
                            icon = { Icon(icons[index], null) }, label = { Text(tab.title, maxLines = 1) },
                            colors = NavigationBarItemDefaults.colors(selectedIconColor = colors.accent, selectedTextColor = colors.accent, indicatorColor = colors.hero),
                        )
                    }
                }
            }
        }

        AnimatedVisibility(
            overlay != null,
            enter = if (Power.reduceMotion) fadeIn() else slideInVertically { it / 3 } + fadeIn(),
            exit = if (Power.reduceMotion) fadeOut() else slideOutVertically { it / 3 } + fadeOut(),
        ) {
            val current = overlay
            Box(Modifier.fillMaxSize().background(colors.background)) {
                when (current) {
                    "login", "campus-login" -> LoginScreen(
                        model, campus = current == "campus-login",
                        onClose = { overlay = null },
                    )
                    "recharge" -> RechargeScreen(model) { overlay = null }
                }
            }
        }
    }
}

/** Keeps scrolled content from running under the transparent status bar. */
@Composable
private fun StatusBarScrim() {
    Box(
        Modifier
            .fillMaxWidth()
            .windowInsetsTopHeight(WindowInsets.statusBars)
            .background(Power.colors.background),
    )
}

private fun <T> List<T>.toMutableStateList() = mutableStateListOf<T>().also { it.addAll(this) }
