package com.zebwqfox.hbustpower.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.CurrencyYen
import androidx.compose.material.icons.filled.DragHandle
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import com.zebwqfox.hbustpower.model.MeterKind
import com.zebwqfox.hbustpower.model.MeterStatus
import com.zebwqfox.hbustpower.model.PowerThemeStyle
import com.zebwqfox.hbustpower.model.StrayBirds
import com.zebwqfox.hbustpower.model.UsageInsight
import com.zebwqfox.hbustpower.model.UsageInsights
import com.zebwqfox.hbustpower.ui.LargeTitleHeader
import com.zebwqfox.hbustpower.ui.LocalPowerLayout
import com.zebwqfox.hbustpower.ui.PageColumn
import com.zebwqfox.hbustpower.ui.PowerStatus
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.RoundIconButton
import com.zebwqfox.hbustpower.ui.components.ChargeRefreshBox
import com.zebwqfox.hbustpower.ui.components.DoodleHeading
import com.zebwqfox.hbustpower.ui.components.EnergyLiquid
import com.zebwqfox.hbustpower.ui.components.LiquidPhysics
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.PowerCard
import com.zebwqfox.hbustpower.ui.components.SectionHeading
import com.zebwqfox.hbustpower.ui.components.Sticker
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.components.rememberHaptics
import com.zebwqfox.hbustpower.ui.components.rememberLiquidController
import com.zebwqfox.hbustpower.ui.components.reveal
import com.zebwqfox.hbustpower.ui.theme.Power
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

@Composable
fun OverviewScreen(
    model: PowerViewModel,
    onOpenUsage: (MeterKind?) -> Unit,
    onOpenRecords: () -> Unit,
    onLogin: () -> Unit,
    onRecharge: () -> Unit,
) {
    val snapshot = model.snapshot
    val status = model.status
    val liquid = rememberLiquidController()
    ChargeRefreshBox(
        loading = status == PowerStatus.Loading,
        onRefresh = model::refresh,
        succeeded = { model.status == PowerStatus.Ready },
        onCharged = { liquid.slosh(1.0) },
    ) {
        PageColumn(spacing = 16.dp) {
            LargeTitleHeader("电量") {
                RoundIconButton(Icons.Filled.Refresh, "刷新数据", model::refresh, enabled = status != PowerStatus.Loading)
            }
            when {
                snapshot != null -> Dashboard(model, snapshot, liquid, onOpenUsage, onOpenRecords, onLogin, onRecharge)
                status == PowerStatus.AuthenticationRequired -> Welcome(onLogin)
                else -> Connection(status, model::refresh)
            }
        }
    }
}

@Composable
private fun Dashboard(
    model: PowerViewModel,
    snapshot: ElectricitySnapshot,
    liquid: com.zebwqfox.hbustpower.ui.components.LiquidController,
    onOpenUsage: (MeterKind?) -> Unit,
    onOpenRecords: () -> Unit,
    onLogin: () -> Unit,
    onRecharge: () -> Unit,
) {
    val layout = LocalPowerLayout.current
    var stickerWiggle by remember { mutableIntStateOf(0) }
    var greeting by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(greeting) {
        if (greeting != null) { delay(2600); greeting = null }
    }
    val insights = remember(snapshot) { UsageInsights.make(snapshot, Instant.now()) }
    var planning by rememberSaveable { mutableStateOf(false) }

    val primary: @Composable () -> Unit = {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            BalanceHero(model, snapshot, liquid, stickerWiggle, onOpenUsage, { planning = true }, { greeting = it }, Modifier.reveal(0))
            Row(Modifier.reveal(1), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PowerButton(
                    "电费充值", onRecharge, icon = Icons.Filled.Add, primary = true,
                    modifier = Modifier.weight(1f),
                )
                PowerButton("算一算", { planning = true }, icon = Icons.Filled.Calculate, modifier = Modifier.weight(0.62f))
            }
        }
    }
    val secondary: @Composable () -> Unit = {
        Column {
            DoodleHeading("每天用了多少", seed = 3, detail = "最近 7 个有记录日的平均用量", modifier = Modifier.reveal(2))
            Spacer(Modifier.height(16.dp))
            MetricTiles(snapshot, onOpenUsage, Modifier.reveal(3))
            Spacer(Modifier.height(16.dp))
            PowerButton("查看用量趋势", { onOpenUsage(null) }, icon = Icons.AutoMirrored.Filled.ShowChart)
            if (insights.isNotEmpty()) {
                Spacer(Modifier.height(30.dp))
                DoodleHeading("用电小发现", seed = 11, detail = "左右滑动，长按可以复制")
                Spacer(Modifier.height(4.dp))
                InsightsRow(insights, clipToColumn = layout.isWide) { insight ->
                    when (insight.id) {
                        "ac" -> onOpenUsage(MeterKind.AIR_CONDITIONING)
                        "recharge" -> onOpenRecords()
                        "value" -> { liquid.slosh(1.2); stickerWiggle++ }
                        else -> onOpenUsage(null)
                    }
                }
            }
            Spacer(Modifier.height(30.dp))
            SectionHeading("设备状态")
            Spacer(Modifier.height(16.dp))
            MeterCard(snapshot.meters)
            Spacer(Modifier.height(16.dp))
            Text(
                greeting ?: statusLine(model.status, snapshot, pullHint = true),
                color = if (greeting != null) Power.colors.accent else Power.colors.secondaryText, fontSize = 13.sp,
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().semantics { },
            )
            if (model.status == PowerStatus.AuthenticationRequired) {
                Spacer(Modifier.height(16.dp))
                PowerButton("重新登录", onLogin, icon = Icons.Filled.Person)
            }
            if (Power.colors.style == PowerThemeStyle.PURPLE_BIRD) {
                Spacer(Modifier.height(20.dp))
                StrayBirdsCard()
            }
        }
    }

    if (planning) {
        RechargePlannerSheet(snapshot, model.roommates, model::updateRoommates) { planning = false }
    }
    if (layout.isWide) {
        EvenColumns(primary, secondary)
    } else {
        primary()
        Spacer(Modifier.height(14.dp))
        secondary()
    }
}

/**
 * Two equal columns with a 32dp gap. When a vertical hinge crosses the row, the gap is widened to cover it so
 * no control sits on the fold.
 */
@Composable
private fun EvenColumns(primary: @Composable () -> Unit, secondary: @Composable () -> Unit) {
    val fold = LocalPowerLayout.current.verticalFold
    val density = LocalDensity.current
    var rowLeft by remember { mutableStateOf(0f) }
    var rowWidth by remember { mutableStateOf(0f) }
    val gap = with(density) { 32.dp.toPx() }
    val minColumn = with(density) { 260.dp.toPx() }
    val split = fold?.let {
        val left = it.left - rowLeft - gap / 2
        val right = rowLeft + rowWidth - it.right - gap / 2
        if (rowWidth > 0 && left >= minColumn && right >= minColumn) left to right else null
    }
    Row(
        Modifier.fillMaxWidth().onGloballyPositioned {
            val bounds = it.boundsInWindow()
            rowLeft = bounds.left
            rowWidth = it.size.width.toFloat()
        },
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top,
    ) {
        if (split != null) {
            Box(Modifier.width(with(density) { split.first.toDp() })) { primary() }
            Box(Modifier.width(with(density) { split.second.toDp() })) { secondary() }
        } else {
            Box(Modifier.weight(1f)) { primary() }
            Spacer(Modifier.width(32.dp))
            Box(Modifier.weight(1f)) { secondary() }
        }
    }
}

internal fun forecastText(snapshot: ElectricitySnapshot, isLow: Boolean): String = when {
    isLow -> "电量偏低，记得及时充值"
    else -> snapshot.predictedDays?.let { String.format(Locale.ROOT, "按近期用量，约可用 %.1f 天", it) } ?: "用量记录充足后，可估算使用天数"
}

internal fun stickerFor(snapshot: ElectricitySnapshot, isLow: Boolean): Pair<String, Boolean> {
    val days = snapshot.predictedDays ?: Double.POSITIVE_INFINITY
    return when {
        isLow || days < 3 -> "该充电啦" to true
        days < 10 -> "省着点用" to false
        else -> "电量充足" to false
    }
}

@Composable
private fun BalanceHero(
    model: PowerViewModel,
    snapshot: ElectricitySnapshot,
    liquid: com.zebwqfox.hbustpower.ui.components.LiquidController,
    stickerWiggle: Int,
    onOpenUsage: (MeterKind?) -> Unit,
    onPlanRecharge: () -> Unit,
    onGreeting: (String) -> Unit,
    modifier: Modifier,
) {
    val colors = Power.colors
    val context = LocalContext.current
    val layout = LocalPowerLayout.current
    var expanded by rememberSaveable { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    var onScreen by remember { mutableStateOf(true) }
    val isLow = snapshot.purchasedKWh < model.lowBalanceThreshold
    val room = snapshot.room ?: "我的宿舍"
    val balance = String.format(Locale.ROOT, "%.2f", snapshot.purchasedKWh)
    val forecast = forecastText(snapshot, isLow)
    val (stickerText, stickerWarm) = stickerFor(snapshot, isLow)
    val lighting = snapshot.recentAverage(MeterKind.LIGHTING)
    val air = snapshot.recentAverage(MeterKind.AIR_CONDITIONING)
    val explanation = if (lighting != null && air != null && lighting + air > 0) {
        String.format(Locale.ROOT, "近期日均 %.2f 度。剩余电量 ÷ 日均用量，即为预计天数；实际时长会随用电变化。", lighting + air)
    } else "有照明和空调的用量记录后，会根据剩余电量与日均用量估算可用天数。"
    val details = listOfNotNull(
        snapshot.subsidyKWh?.let { String.format(Locale.ROOT, "补助 %.2f 度", it) },
        snapshot.unitPrice?.let { String.format(Locale.ROOT, "电价 %.2f 元/度", it) },
    ).joinToString("  ·  ")
    val summary = "$room 剩余 $balance 度，$forecast"
    val shape = RoundedCornerShape(30.dp)

    Box(modifier.fillMaxWidth().padding(top = 8.dp, end = 6.dp)) {
        Box(
            Modifier
                .fillMaxWidth()
                .onGloballyPositioned { onScreen = it.boundsInWindow().height > 0f }
                .shadow(if (colors.isDark) 0.dp else 12.dp, shape, ambientColor = colors.accent.copy(alpha = 0.15f), spotColor = colors.accent.copy(alpha = 0.18f))
                .clip(shape)
                .background(colors.hero)
                .border(0.8.dp, Color.White.copy(alpha = if (colors.isDark) 0.08f else 0.75f), shape)
                .pointerInput(Unit) { detectHorizontalPush(liquid) }
                .pressable(
                    onClick = {
                        liquid.slosh(0.6)
                        expanded = !expanded
                    },
                    onLongClick = { menu = true },
                    onClickLabel = if (expanded) "收起估算说明" else "展开估算说明",
                )
                .semantics(mergeDescendants = true) {
                    contentDescription = "$stickerText。$room，剩余电量 $balance 度。$forecast。$details"
                    stateDescription = if (expanded) explanation else "估算说明已收起"
                },
        ) {
            EnergyLiquid(
                controller = liquid,
                level = LiquidPhysics.levelFor(snapshot.predictedDays, snapshot.purchasedKWh),
                isLow = isLow,
                active = onScreen,
                gravityEnabled = layout.isPortraitPhone,
                modifier = Modifier.matchParentSize(),
            )
            Column(
                Modifier.fillMaxWidth().animateContentSize().padding(start = 24.dp, end = 24.dp, top = 24.dp, bottom = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(room, color = colors.accent, fontSize = 15.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.Center)
                Spacer(Modifier.height(22.dp))
                Text("剩余电量", color = colors.accent, fontSize = 15.sp)
                Spacer(Modifier.height(9.dp))
                Row(verticalAlignment = Alignment.Bottom) {
                    Crossfade(balance, label = "balance") { value ->
                        Text(value, color = colors.accent, fontSize = 58.sp, lineHeight = 64.sp, fontWeight = FontWeight.Medium, maxLines = 1)
                    }
                    Spacer(Modifier.width(7.dp))
                    Text("度", color = colors.accent, fontSize = 20.sp, modifier = Modifier.padding(bottom = 10.dp))
                }
                Spacer(Modifier.height(9.dp))
                Text(
                    forecast, color = if (isLow) colors.lighting else colors.accent, fontSize = 17.sp,
                    fontWeight = FontWeight.Medium, textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(20.dp))
                Text(if (expanded) "收起估算说明 ↑" else "轻点查看用量估算 ↓", color = colors.accent, fontSize = 12.sp)
                AnimatedVisibility(expanded, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                    Text(
                        explanation, color = colors.accent, fontSize = 15.sp, textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 9.dp),
                    )
                }
                if (details.isNotEmpty()) {
                    HorizontalDivider(Modifier.padding(top = 9.dp, bottom = 14.dp), thickness = 0.5.dp, color = colors.accent.copy(alpha = 0.15f))
                    Text(details, color = colors.secondaryText, fontSize = 12.sp, textAlign = TextAlign.Center)
                }
            }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(
                    text = { Text("复制电量") }, leadingIcon = { Icon(Icons.Filled.ContentCopy, null) },
                    onClick = { menu = false; copyText(context, summary) },
                )
                DropdownMenuItem(
                    text = { Text("分享电量卡片") }, leadingIcon = { Icon(Icons.Filled.Share, null) },
                    onClick = {
                        menu = false
                        ShareCard.share(context, room, snapshot.purchasedKWh, forecast, isLow)
                    },
                )
                DropdownMenuItem(
                    text = { Text("算算充多少") }, leadingIcon = { Icon(Icons.Filled.Calculate, null) },
                    onClick = { menu = false; onPlanRecharge() },
                )
                DropdownMenuItem(
                    text = { Text("查看用量趋势") }, leadingIcon = { Icon(Icons.AutoMirrored.Filled.ShowChart, null) },
                    onClick = { menu = false; onOpenUsage(null) },
                )
                DropdownMenuItem(
                    text = { Text("刷新") }, leadingIcon = { Icon(Icons.Filled.Refresh, null) },
                    enabled = model.status != PowerStatus.Loading,
                    onClick = { menu = false; model.refresh() },
                )
            }
        }
        Sticker(
            stickerText,
            fill = if (stickerWarm) colors.lighting else colors.accent,
            angleRadians = 0.12f,
            wiggleSignal = stickerWiggle,
            onClick = { liquid.slosh(0.9); onGreeting(colors.style.greeting) },
            modifier = Modifier.align(Alignment.TopEnd).offset(x = 6.dp, y = (-8).dp),
        )
    }
}

/** Only horizontal drags (|vx| > |vy| × 1.3) push the liquid; vertical drags keep scrolling the page. */
private suspend fun androidx.compose.ui.input.pointer.PointerInputScope.detectHorizontalPush(
    liquid: com.zebwqfox.hbustpower.ui.components.LiquidController,
) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        var dx = 0f
        var dy = 0f
        var pushing = false
        while (true) {
            val event = awaitPointerEvent()
            val change = event.changes.firstOrNull { it.id == down.id } ?: break
            if (!change.pressed) break
            if (!pushing) {
                if (change.isConsumed) break
                val delta = change.positionChange()
                dx += delta.x
                dy += delta.y
                if (abs(dx) > viewConfiguration.touchSlop || abs(dy) > viewConfiguration.touchSlop) {
                    if (abs(dx) > abs(dy) * 1.3f) pushing = true else break
                }
            }
            if (pushing) {
                liquid.push(((change.position.x - down.position.x) / (size.width / 2f)).toDouble())
                change.consume()
            }
        }
        if (pushing) liquid.push(null)
    }
}

@Composable
private fun MetricTiles(snapshot: ElectricitySnapshot, onOpenUsage: (MeterKind?) -> Unit, modifier: Modifier) {
    val colors = Power.colors
    val vertical = LocalDensity.current.fontScale >= 1.6f
    val tiles: @Composable (Modifier) -> Unit = { tileModifier ->
        MetricTile("照明", Icons.Outlined.Lightbulb, colors.lighting, snapshot.recentAverage(MeterKind.LIGHTING), tileModifier) { onOpenUsage(MeterKind.LIGHTING) }
    }
    val ac: @Composable (Modifier) -> Unit = { tileModifier ->
        MetricTile("空调", Icons.Filled.AcUnit, colors.cooling, snapshot.recentAverage(MeterKind.AIR_CONDITIONING), tileModifier) { onOpenUsage(MeterKind.AIR_CONDITIONING) }
    }
    if (vertical) {
        Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) { tiles(Modifier.fillMaxWidth()); ac(Modifier.fillMaxWidth()) }
    } else {
        Row(modifier, horizontalArrangement = Arrangement.spacedBy(12.dp)) { tiles(Modifier.weight(1f)); ac(Modifier.weight(1f)) }
    }
}

@Composable
private fun MetricTile(title: String, icon: ImageVector, tint: Color, value: Double?, modifier: Modifier, onOpen: () -> Unit) {
    val colors = Power.colors
    val context = LocalContext.current
    var menu by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(22.dp)
    Box(modifier) {
        Column(
            Modifier
                .fillMaxWidth()
                .shadow(if (colors.isDark) 0.dp else 6.dp, shape, ambientColor = Color.Black.copy(alpha = 0.06f), spotColor = Color.Black.copy(alpha = 0.08f))
                .clip(shape)
                .background(colors.surface.copy(alpha = if (colors.isDark) 0.85f else 0.92f))
                .border(0.6.dp, Color.White.copy(alpha = if (colors.isDark) 0.06f else 0.8f), shape)
                .pressable(onClick = onOpen, onLongClick = { if (value != null) menu = true }, onClickLabel = "查看该项用量趋势")
                .semantics(mergeDescendants = true) {
                    contentDescription = "${title}每日平均用量，" + (value?.let { String.format(Locale.ROOT, "%.2f 度每天", it) } ?: "暂无数据")
                }
                .padding(20.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text(title, color = colors.secondaryText, fontSize = 15.sp)
            }
            Spacer(Modifier.height(16.dp))
            Text(value?.let { String.format(Locale.ROOT, "%.2f", it) } ?: "—", fontSize = 30.sp, fontWeight = FontWeight.Medium, maxLines = 1)
            Spacer(Modifier.height(4.dp))
            Text("度 / 天  ↗", color = colors.secondaryText, fontSize = 12.sp)
        }
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            DropdownMenuItem(
                text = { Text("复制日均用量") }, leadingIcon = { Icon(Icons.Filled.ContentCopy, null) },
                onClick = { menu = false; value?.let { copyText(context, String.format(Locale.ROOT, "${title}日均 %.2f 度", it)) } },
            )
            DropdownMenuItem(
                text = { Text("查看${title}趋势") }, leadingIcon = { Icon(Icons.Filled.BarChart, null) },
                onClick = { menu = false; onOpen() },
            )
        }
    }
}

@Composable
private fun InsightsRow(insights: List<UsageInsight>, clipToColumn: Boolean, onOpen: (UsageInsight) -> Unit) {
    val bleed = if (clipToColumn) 0.dp else 24.dp
    LazyRow(
        Modifier
            .fillMaxWidth()
            .layout { measurable, constraints ->
                // Cards run past the page margins on phones, but never across the other column on wide layouts.
                val extra = bleed.roundToPx() * 2
                val placeable = measurable.measure(constraints.copy(minWidth = constraints.maxWidth + extra, maxWidth = constraints.maxWidth + extra))
                layout(constraints.maxWidth, placeable.height) { placeable.place(-extra / 2, 0) }
            },
        contentPadding = PaddingValues(start = bleed, end = bleed, top = 12.dp, bottom = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        itemsIndexed(insights, key = { _, it -> it.id }) { index, insight ->
            InsightCard(insight, if (index % 2 == 0) 0.1f else -0.09f, Modifier.reveal(index, insight)) { onOpen(insight) }
        }
    }
}

@Composable
private fun InsightCard(insight: UsageInsight, stickerAngle: Float, modifier: Modifier, onOpen: () -> Unit) {
    val colors = Power.colors
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val reduceMotion = Power.reduceMotion
    val bounce = remember { Animatable(1f) }
    var menu by remember { mutableStateOf(false) }
    val tint = when (insight.tone) {
        UsageInsight.Tone.GOOD -> colors.good
        UsageInsight.Tone.HEADS -> colors.lighting
        UsageInsight.Tone.NEUTRAL -> colors.accent
    }
    val icon = insightIcon(insight)
    val shape = RoundedCornerShape(22.dp)
    Box(modifier.width(164.dp)) {
        Column(
            Modifier
                .fillMaxWidth()
                .graphicsLayer { scaleX = bounce.value; scaleY = bounce.value }
                .shadow(if (colors.isDark) 0.dp else 3.dp, shape, ambientColor = Color.Black.copy(alpha = 0.05f), spotColor = Color.Black.copy(alpha = 0.06f))
                .clip(shape)
                .background(colors.surface)
                .pressable(
                    onClick = {
                        haptics.soft()
                        if (!reduceMotion) scope.launch {
                            bounce.snapTo(0.94f)
                            bounce.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium))
                        }
                        onOpen()
                    },
                    onLongClick = { menu = true },
                )
                .semantics(mergeDescendants = true) {
                    contentDescription = listOfNotNull(insight.sticker, insight.caption, insight.value).joinToString("，")
                }
                .padding(16.dp),
        ) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp))
            Spacer(Modifier.height(12.dp))
            Text(insight.value, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            Spacer(Modifier.height(4.dp))
            Text(insight.caption, color = colors.secondaryText, fontSize = 13.sp, minLines = 2)
        }
        insight.sticker?.let {
            Sticker(it, fill = tint, angleRadians = stickerAngle, modifier = Modifier.align(Alignment.TopEnd).offset(x = 4.dp, y = (-10).dp))
        }
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            DropdownMenuItem(
                text = { Text("复制") }, leadingIcon = { Icon(Icons.Filled.ContentCopy, null) },
                onClick = { menu = false; copyText(context, "${insight.caption}：${insight.value}") },
            )
        }
    }
}

private fun insightIcon(insight: UsageInsight): ImageVector = when (insight.id) {
    "week" -> when (insight.tone) {
        UsageInsight.Tone.GOOD -> Icons.AutoMirrored.Filled.TrendingDown
        UsageInsight.Tone.HEADS -> Icons.AutoMirrored.Filled.TrendingUp
        UsageInsight.Tone.NEUTRAL -> Icons.Filled.DragHandle
    }
    "streak" -> Icons.Filled.LocalFireDepartment
    "peak" -> Icons.Filled.Bolt
    "ac" -> Icons.Filled.AcUnit
    "value" -> Icons.Filled.CurrencyYen
    "recharge" -> Icons.Filled.History
    else -> Icons.Filled.Bolt
}

@Composable
private fun MeterCard(meters: List<MeterStatus>) {
    val colors = Power.colors
    PowerCard(padding = PaddingValues(0.dp)) {
        if (meters.isEmpty()) {
            SectionHeading("暂无设备信息", Modifier.padding(20.dp), detail = "学校返回设备状态后会显示在这里")
        }
        meters.forEachIndexed { index, meter ->
            if (index > 0) HorizontalDivider(thickness = 0.5.dp, color = colors.separator)
            val kind = MeterKind.fromMeterName(meter.name)
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 18.dp)
                    .semantics(mergeDescendants = true) { contentDescription = "${meter.name}，${meter.powerStatus}，${meter.communicationStatus}" },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    if (kind == MeterKind.AIR_CONDITIONING) Icons.Filled.AcUnit else Icons.Outlined.Lightbulb, null,
                    tint = if (kind == MeterKind.AIR_CONDITIONING) colors.cooling else colors.lighting,
                    modifier = Modifier.width(26.dp),
                )
                Spacer(Modifier.width(12.dp))
                SectionHeading(meter.name, detail = "${meter.powerStatus} · ${meter.communicationStatus}")
            }
        }
    }
}

/** One line of 《飞鸟集》 per launch; tap for the next, long-press to copy (iOS 1.9.0, 紫鸟紫 only). */
@Composable
private fun StrayBirdsCard() {
    val colors = Power.colors
    val context = LocalContext.current
    var line by rememberSaveable { mutableStateOf(StrayBirds.ofThisLaunch) }
    PowerCard(
        Modifier.pressable(
            onClick = { line = StrayBirds.after(line) },
            onLongClick = { copyText(context, line + System.lineSeparator() + StrayBirds.ATTRIBUTION) },
            onClickLabel = "换一句",
        ),
        padding = PaddingValues(20.dp),
    ) {
        Text(line, fontSize = 15.sp, lineHeight = 26.sp)
        Spacer(Modifier.height(10.dp))
        Text(StrayBirds.ATTRIBUTION, color = colors.tertiaryText, fontSize = 12.sp)
    }
}

internal fun statusLine(status: PowerStatus, snapshot: ElectricitySnapshot, pullHint: Boolean): String {
    val updated = "更新于 " + formatTime(snapshot.fetchedAt)
    return when (status) {
        PowerStatus.Loading -> "正在更新… · $updated"
        PowerStatus.AuthenticationRequired -> "登录已过期 · 当前显示上次数据"
        is PowerStatus.Error -> "更新失败，下拉重试 · $updated"
        else -> if (pullHint) "$updated · 下拉刷新" else updated
    }
}

@Composable
private fun Connection(status: PowerStatus, onRetry: () -> Unit) {
    val colors = Power.colors
    val short = LocalPowerLayout.current.isShort
    Column(
        Modifier.fillMaxWidth().padding(top = if (short) 36.dp else 100.dp, bottom = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        if (status is PowerStatus.Error) {
            Text("暂时无法更新", fontSize = 22.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.reveal(0))
            Text(
                "${status.message}\n检查网络后再试一次。", color = colors.secondaryText,
                fontSize = 17.sp, textAlign = TextAlign.Center, modifier = Modifier.reveal(1),
            )
            PowerButton("重新连接", onRetry, icon = Icons.Filled.Refresh, primary = true, modifier = Modifier.reveal(2))
        } else {
            CircularProgressIndicator(color = colors.accent)
            Text("正在读取电量", fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
            Text("正在恢复连接，请稍候…", color = colors.secondaryText, fontSize = 17.sp, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun Welcome(onLogin: () -> Unit) {
    val colors = Power.colors
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        PowerIllustration(Modifier.reveal(0))
        Text(
            "宿舍用电，\n心里有数。", fontSize = 34.sp, lineHeight = 42.sp, fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().reveal(1).semantics { heading() },
        )
        Text(
            "看看还剩多少电、还能用多久。\n照明与空调用量，一眼看清。", color = colors.secondaryText, fontSize = 17.sp,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().reveal(2),
        )
        Spacer(Modifier.height(14.dp))
        PowerButton("登录智慧湖科", onLogin, icon = Icons.Filled.Person, primary = true, modifier = Modifier.reveal(3))
    }
}

/** Drag a sticker: it follows the finger with edge resistance, neighbours respond, then everything springs home. */
@Composable
private fun PowerIllustration(modifier: Modifier) {
    val colors = Power.colors
    val reduceMotion = Power.reduceMotion
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val short = LocalPowerLayout.current.isShort
    var hint by remember { mutableStateOf("轻点或拖动，感受一点电力") }
    val tiles = remember {
        listOf(
            Triple(Icons.Outlined.Lightbulb, Offset(-86f, -59f), -0.22f),
            Triple(Icons.Filled.AcUnit, Offset(87f, 32f), 0.18f),
            Triple(Icons.Filled.NightsStay, Offset(60f, -82f), 0.12f),
        )
    }
    val tileOffsets = remember { tiles.map { Animatable(Offset.Zero, Offset.VectorConverter) } }
    val disc = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    val discScale = remember { Animatable(1f) }
    val names = listOf("照明", "空调", "安心用电")
    val tileHints = listOf("照明用量，清清楚楚", "空调用电，单独看清", "剩余电量，随时心中有数")
    val tint = listOf(colors.lighting, colors.cooling, colors.accent)
    val springSpec = spring<Offset>(dampingRatio = 0.78f, stiffness = Spring.StiffnessMediumLow)
    fun settleAll() {
        if (reduceMotion) {
            scope.launch { tileOffsets.forEach { it.snapTo(Offset.Zero) }; disc.snapTo(Offset.Zero) }
            return
        }
        tileOffsets.forEach { scope.launch { it.animateTo(Offset.Zero, springSpec) } }
        scope.launch { disc.animateTo(Offset.Zero, springSpec) }
    }
    fun bounded(distance: Float): Float {
        val limit = 72f
        if (abs(distance) <= limit) return distance
        val excess = abs(distance) - limit
        return (if (distance < 0) -1 else 1) * (limit + (excess * 0.35f * limit) / (limit + excess * 0.35f))
    }

    Box(modifier.fillMaxWidth().height(if (short) 170.dp else 240.dp)) {
        Box(Modifier.align(Alignment.Center).offset(y = (-10).dp)) {
            Box(
                Modifier
                    .size(144.dp)
                    .graphicsLayer {
                        translationX = disc.value.x * density; translationY = disc.value.y * density
                        scaleX = discScale.value; scaleY = discScale.value
                    }
                    .shadow(16.dp, CircleShape, ambientColor = colors.accent.copy(alpha = 0.2f), spotColor = colors.accent.copy(alpha = 0.2f))
                    .clip(CircleShape)
                    .background(colors.hero)
                    .border(1.dp, Color.White.copy(alpha = if (colors.isDark) 0.1f else 0.8f), CircleShape)
                    .pressable(onClickLabel = "点亮电力插画", onClick = {
                        hint = "一点电力，点亮宿舍日常"
                        if (!reduceMotion) {
                            tileOffsets.forEachIndexed { index, animatable ->
                                scope.launch {
                                    animatable.snapTo(Offset(if (index == 0) -12f else 12f, -12f))
                                    animatable.animateTo(Offset.Zero, springSpec)
                                }
                            }
                        }
                    }),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Bolt, "点亮电力插画", tint = colors.accent, modifier = Modifier.size(68.dp))
            }
            tiles.forEachIndexed { index, (icon, rest, angle) ->
                val shape = RoundedCornerShape(18.dp)
                Box(
                    Modifier
                        .align(Alignment.Center)
                        .offset(x = rest.x.dp, y = rest.y.dp)
                        .graphicsLayer {
                            translationX = tileOffsets[index].value.x * density
                            translationY = tileOffsets[index].value.y * density
                            rotationZ = Math.toDegrees(angle.toDouble()).toFloat()
                        }
                        .size(56.dp)
                        .shadow(8.dp, shape, ambientColor = Color.Black.copy(alpha = 0.1f), spotColor = Color.Black.copy(alpha = 0.1f))
                        .clip(shape)
                        .background(colors.surface.copy(alpha = 0.92f))
                        .border(0.8.dp, Color.White.copy(alpha = if (colors.isDark) 0.08f else 0.9f), shape)
                        .pointerInput(index) {
                            var origin = Offset.Zero
                            detectDragGestures(
                                onDragStart = {
                                    haptics.soft()
                                    origin = tileOffsets[index].value
                                    scope.launch { tileOffsets.forEach { it.stop() }; disc.stop() }
                                },
                                onDrag = { change, amount ->
                                    change.consume()
                                    origin += Offset(amount.x / density, amount.y / density)
                                    val x = bounded(origin.x)
                                    val y = bounded(origin.y)
                                    scope.launch {
                                        tileOffsets[index].snapTo(Offset(x, y))
                                        if (!reduceMotion) {
                                            disc.snapTo(Offset(x * 0.07f, y * 0.07f))
                                            tileOffsets.forEachIndexed { other, animatable ->
                                                if (other != index) animatable.snapTo(Offset(x * -0.08f, y * -0.08f))
                                            }
                                        }
                                    }
                                },
                                onDragEnd = { hint = "松开，电力回到自己的位置"; settleAll() },
                                onDragCancel = { settleAll() },
                            )
                        }
                        .pressable(onClickLabel = "让电力图标回应", onClick = {
                            hint = tileHints[index]
                            if (!reduceMotion) scope.launch {
                                discScale.snapTo(1.065f)
                                discScale.animateTo(1f, spring(dampingRatio = 0.8f))
                            }
                        })
                        .semantics { contentDescription = "${names[index]}互动贴纸" },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(icon, null, tint = tint[index], modifier = Modifier.size(26.dp))
                }
            }
        }
        Text(
            hint, color = colors.secondaryText, fontSize = 12.sp, textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth(),
        )
    }
}

@Suppress("unused")
private fun percent(value: Double) = (value * 100).roundToInt()
