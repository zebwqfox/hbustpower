package com.zebwqfox.hbustpower.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Functions
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.model.DailyUsagePoint
import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import com.zebwqfox.hbustpower.model.MeterKind
import com.zebwqfox.hbustpower.ui.LargeTitleHeader
import com.zebwqfox.hbustpower.ui.LocalPowerLayout
import com.zebwqfox.hbustpower.ui.PageColumn
import com.zebwqfox.hbustpower.ui.PowerStatus
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.RoundIconButton
import com.zebwqfox.hbustpower.ui.components.ChargeRefreshBox
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.PowerCard
import com.zebwqfox.hbustpower.ui.components.SectionHeading
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.components.rememberHaptics
import com.zebwqfox.hbustpower.ui.components.reveal
import com.zebwqfox.hbustpower.ui.theme.Power
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow

/** Chart scale helpers from `UsageChartView.swift`. */
object UsageChartScale {
    fun niceMaximum(value: Double): Double {
        val roughStep = max(1.0, value) / 3
        val magnitude = 10.0.pow(floor(log10(roughStep)))
        val normalized = roughStep / magnitude
        val step = when {
            normalized <= 1 -> 1.0
            normalized <= 2 -> 2.0
            normalized <= 2.5 -> 2.5
            normalized <= 5 -> 5.0
            else -> 10.0
        }
        return step * magnitude * 3
    }

    fun axisLabel(value: Double): String = when {
        value == 0.0 -> "0"
        value >= 10 -> String.format(Locale.ROOT, "%.0f", value)
        else -> String.format(Locale.ROOT, "%.1f", value)
    }
}

/** Week figures shown under the chart; previous week only counts when it has as many recorded days. */
data class UsageWeek(val current: List<DailyUsagePoint>, val previous: List<DailyUsagePoint>) {
    val lighting = current.sumOf { it.lighting }
    val airConditioning = current.sumOf { it.airConditioning }
    val total = lighting + airConditioning
    val dayCount = max(1, current.size)
    val periodName = if (current.size == 7) "近 7 日" else "近 ${current.size} 日"
    val peak = current.maxByOrNull { it.lighting + it.airConditioning }
    val changePercent: Double? = previous.sumOf { it.lighting + it.airConditioning }
        .takeIf { previous.size == current.size && it > 0 }
        ?.let { (total - it) / it * 100 }

    companion object {
        fun from(snapshot: ElectricitySnapshot): UsageWeek {
            val all = snapshot.dailyPoints()
            val current = all.takeLast(7)
            return UsageWeek(current, all.dropLast(current.size).takeLast(7))
        }
    }
}

@Composable
fun UsageScreen(model: PowerViewModel, focus: MeterKind?, focusToken: Int) {
    val colors = Power.colors
    val haptics = rememberHaptics()
    var showLighting by rememberSaveable { mutableStateOf(true) }
    var showAir by rememberSaveable { mutableStateOf(true) }
    var selected by rememberSaveable { mutableIntStateOf(-1) }
    LaunchedEffect(focusToken) {
        if (focus != null) {
            showLighting = focus == MeterKind.LIGHTING
            showAir = focus == MeterKind.AIR_CONDITIONING
            selected = -1
        }
    }
    val snapshot = model.snapshot
    val week = remember(snapshot) { snapshot?.let(UsageWeek::from) }
    val points = week?.current.orEmpty()
    if (selected > points.lastIndex) selected = -1

    ChargeRefreshBox(loading = model.status == PowerStatus.Loading, onRefresh = model::refresh, succeeded = { model.status == PowerStatus.Ready }) {
        PageColumn(spacing = 18.dp) {
            LargeTitleHeader("用量") {
                RoundIconButton(Icons.Filled.Refresh, "刷新数据", model::refresh, enabled = model.status != PowerStatus.Loading)
            }
            PowerCard(Modifier.reveal(0), shape = RoundedCornerShape(24.dp), padding = PaddingValues(start = 14.dp, end = 14.dp, top = 16.dp, bottom = 13.dp)) {
                Text("近 7 日用量", fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    LegendPill("照明", colors.lighting, showLighting) {
                        if (!showLighting || showAir) { showLighting = !showLighting; haptics.selection() }
                    }
                    LegendPill("空调", colors.cooling, showAir) {
                        if (!showAir || showLighting) { showAir = !showAir; haptics.selection() }
                    }
                }
                Spacer(Modifier.height(10.dp))
                UsageChart(points, showLighting, showAir, selected.takeIf { it >= 0 }) {
                    if (it != selected) { selected = it; haptics.selection() }
                }
                Spacer(Modifier.height(10.dp))
                val point = points.getOrNull(selected)
                Text(
                    point?.let {
                        String.format(Locale.ROOT, "%s · 合计 %.2f 度\n照明 %.2f 度   空调 %.2f 度", formatMonthDay(it.day), it.lighting + it.airConditioning, it.lighting, it.airConditioning)
                    } ?: "轻点或横向滑动图表，查看当天用量",
                    color = colors.accent, fontSize = 15.sp,
                )
                AnimatedVisibility(point != null) {
                    PowerButton("查看整周", { selected = -1 }, icon = Icons.AutoMirrored.Filled.Undo, modifier = Modifier.padding(top = 10.dp))
                }
                Spacer(Modifier.height(10.dp))
                Text(rangeNote(snapshot, points), color = colors.secondaryText, fontSize = 12.sp)
            }

            val large = LocalDensity.current.fontScale >= 1.6f
            val totals: @Composable (Modifier, Boolean) -> Unit = { modifier, lighting ->
                PowerCard(modifier) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(if (lighting) Icons.Filled.Lightbulb else Icons.Filled.AcUnit, null, tint = if (lighting) colors.lighting else colors.cooling, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(7.dp))
                        Text("${week?.periodName ?: "近 7 日"}${if (lighting) "照明" else "空调"}", color = colors.secondaryText, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        week?.let { String.format(Locale.ROOT, "%.2f 度", if (lighting) it.lighting else it.airConditioning) } ?: "—",
                        fontSize = 22.sp, fontWeight = FontWeight.Bold, maxLines = 1,
                    )
                }
            }
            if (large) {
                totals(Modifier.reveal(1), true); totals(Modifier, false)
            } else {
                Row(Modifier.reveal(1), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    totals(Modifier.weight(1f), true); totals(Modifier.weight(1f), false)
                }
            }

            PowerCard(Modifier.reveal(2)) {
                val share = week?.takeIf { it.total > 0 }
                val content: @Composable () -> Unit = {
                    Text(
                        share?.let { String.format(Locale.ROOT, "%.0f%%", it.airConditioning / it.total * 100) } ?: "—",
                        color = colors.cooling, fontSize = 34.sp, fontWeight = FontWeight.Bold,
                    )
                }
                val text: @Composable () -> Unit = {
                    Column {
                        Text("近 7 日用电来自空调", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                        Text(
                            when {
                                week == null -> "连接学校账户后查看用量"
                                share == null -> "暂无用量"
                                else -> String.format(Locale.ROOT, "空调 %.2f 度 / 总计 %.2f 度", share.airConditioning, share.total)
                            },
                            color = colors.secondaryText, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
                if (large) { content(); text() } else {
                    Row(verticalAlignment = Alignment.CenterVertically) { content(); Spacer(Modifier.width(14.dp)); text() }
                }
            }

            Spacer(Modifier.height(4.dp))
            SectionHeading("这周的用电情况", detail = "最近有记录的日期")
            PowerCard(padding = PaddingValues(0.dp)) {
                InsightLine(Icons.Filled.Functions, "近 7 日日均", week?.let { String.format(Locale.ROOT, "%.2f 度/天", it.total / it.dayCount) } ?: "—", Color.Unspecified, large)
                HorizontalDivider(thickness = 0.5.dp, color = colors.separator)
                val change = week?.changePercent
                InsightLine(
                    Icons.AutoMirrored.Filled.TrendingUp, "较前 7 日",
                    when {
                        week == null -> "—"
                        change == null -> "数据不足"
                        else -> String.format(Locale.ROOT, "%s %.1f%%", if (change >= 0) "↑" else "↓", abs(change))
                    },
                    when {
                        change == null || change == 0.0 -> colors.secondaryText
                        change > 0 -> colors.danger
                        else -> colors.good
                    },
                    large,
                )
                HorizontalDivider(thickness = 0.5.dp, color = colors.separator)
                InsightLine(
                    Icons.Filled.CalendarMonth, "用量最高日",
                    week?.peak?.let { String.format(Locale.ROOT, "%s · %.2f 度", formatMonthDay(it.day), it.lighting + it.airConditioning) } ?: "—",
                    Color.Unspecified, large,
                )
            }
            Text(
                snapshot?.let { statusLine(model.status, it, pullHint = false) } ?: statusText(model.status),
                color = colors.secondaryText, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

internal fun statusText(status: PowerStatus): String = when (status) {
    PowerStatus.Idle -> "尚未更新"
    PowerStatus.Loading -> "正在连接学校电费系统…"
    PowerStatus.Ready -> "数据已更新"
    PowerStatus.AuthenticationRequired -> "需要登录智慧湖科"
    is PowerStatus.Error -> status.message
}

private fun rangeNote(snapshot: ElectricitySnapshot?, points: List<DailyUsagePoint>): String {
    if (snapshot == null || points.isEmpty()) return "暂无用量数据"
    val today = LocalDate.now(ZoneId.of("Asia/Shanghai"))
    return if (points.any { it.day == today }) {
        "今日数据截至 ${formatTime(snapshot.fetchedAt)} · 日均按 ${points.size} 个自然日计算"
    } else "日均按图中 ${points.size} 个自然日计算"
}

@Composable
private fun InsightLine(icon: ImageVector, title: String, value: String, valueColor: Color, stacked: Boolean) {
    val colors = Power.colors
    val line: @Composable () -> Unit = {
        Text(value, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = valueColor, maxLines = 1)
    }
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 15.dp).semantics(mergeDescendants = true) { }, verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = colors.accent, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(10.dp))
        if (stacked) {
            Column(Modifier.weight(1f)) { Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold); line() }
        } else {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            line()
        }
    }
}

@Composable
private fun LegendPill(label: String, color: Color, selected: Boolean, onClick: () -> Unit) {
    val colors = Power.colors
    val shape = CircleShape
    Row(
        Modifier
            .clip(shape)
            .background(colors.surface.copy(alpha = 0.9f))
            .border(0.8.dp, (if (selected) color else colors.separator).copy(alpha = if (selected) 0.35f else 1f), shape)
            .pressable(onClick = onClick, pressedScale = 0.965f, onClickLabel = "切换该系列并重新缩放图表")
            .semantics { stateDescription = if (selected) "已显示" else "已隐藏" }
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(if (selected) color else colors.tertiaryText))
        Spacer(Modifier.width(5.dp))
        Text(label, fontSize = 12.sp, color = if (selected) color else colors.secondaryText, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun UsageChart(
    points: List<DailyUsagePoint>,
    showLighting: Boolean,
    showAir: Boolean,
    selected: Int?,
    onSelect: (Int) -> Unit,
) {
    val colors = Power.colors
    val measurer = rememberTextMeasurer()
    val reduceMotion = Power.reduceMotion
    val lightingAlpha by animateFloatAsState(if (showLighting) 1f else 0f, tween(if (reduceMotion) 0 else 280), label = "lighting")
    val airAlpha by animateFloatAsState(if (showAir) 1f else 0f, tween(if (reduceMotion) 0 else 280), label = "air")
    val today = LocalDate.now(ZoneId.of("Asia/Shanghai"))
    val axisStyle = TextStyle(fontSize = 11.sp, color = colors.secondaryText)
    val lightingTotal = points.sumOf { it.lighting }
    val airTotal = points.sumOf { it.airConditioning }
    val visibleNames = listOfNotNull("照明".takeIf { showLighting }, "空调".takeIf { showAir }).joinToString("和")
    val description = selected?.let(points::getOrNull)?.let {
        String.format(Locale.ROOT, "%s，照明 %.2f 度，空调 %.2f 度，合计 %.2f 度", formatMonthDay(it.day), it.lighting, it.airConditioning, it.lighting + it.airConditioning)
    } ?: String.format(Locale.ROOT, "当前显示%s，照明合计 %.2f 度，空调合计 %.2f 度", visibleNames, lightingTotal, airTotal)

    Canvas(
        Modifier
            .fillMaxWidth()
            // Keyed on size inputs so folding or resizing redraws instead of stretching.
            .height(LocalPowerLayout.current.chartHeight)
            .semantics {
                contentDescription = "照明和空调用量图表"
                stateDescription = description
                customActions = listOf(
                    CustomAccessibilityAction("后一天") { if (points.isNotEmpty()) onSelect(minOf(points.lastIndex, (selected ?: -1) + 1)); true },
                    CustomAccessibilityAction("前一天") { if (points.isNotEmpty()) onSelect(maxOf(0, (selected ?: points.size) - 1)); true },
                )
            }
            .pointerInput(points.size) {
                fun indexAt(x: Float): Int {
                    val left = 36.dp.toPx()
                    val width = maxOf(1f, size.width - 42.dp.toPx())
                    return ((x - left) / (width / points.size)).toInt().coerceIn(0, points.lastIndex)
                }
                awaitEachGesture {
                    if (points.isEmpty()) return@awaitEachGesture
                    val down = awaitFirstDown(requireUnconsumed = false)
                    var dx = 0f
                    var dy = 0f
                    var dragging = false
                    var moved = false
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id } ?: break
                        if (!change.pressed) {
                            if (!moved && !change.isConsumed) onSelect(indexAt(change.position.x))
                            break
                        }
                        val delta = change.positionChange()
                        dx += delta.x
                        dy += delta.y
                        if (!dragging && (abs(dx) > viewConfiguration.touchSlop || abs(dy) > viewConfiguration.touchSlop)) {
                            moved = true
                            // Horizontal selects days; vertical is left to the page scroll.
                            if (abs(dx) > abs(dy)) dragging = true else break
                        }
                        if (dragging) {
                            change.consume()
                            onSelect(indexAt(change.position.x))
                        }
                    }
                }
            },
    ) {
        if (points.isEmpty()) {
            val layout = measurer.measure("暂无用量记录", TextStyle(fontSize = 15.sp, color = colors.secondaryText))
            drawText(layout, topLeft = Offset((size.width - layout.size.width) / 2, (size.height - layout.size.height) / 2))
            return@Canvas
        }
        val visible = points.flatMap { listOfNotNull(it.lighting.takeIf { showLighting }, it.airConditioning.takeIf { showAir }) }
        val maximum = UsageChartScale.niceMaximum(visible.maxOrNull() ?: 1.0)
        val plotLeft = 36.dp.toPx()
        val plotTop = 8.dp.toPx()
        val plotWidth = maxOf(1f, size.width - 42.dp.toPx())
        val plotHeight = maxOf(1f, size.height - 42.dp.toPx())
        val plotBottom = plotTop + plotHeight
        for (index in 0..3) {
            val y = plotBottom - plotHeight * index / 3f
            drawLine(colors.separator.copy(alpha = if (index == 0) 0.9f else 0.45f), Offset(plotLeft, y), Offset(plotLeft + plotWidth, y), 0.5.dp.toPx())
            val label = measurer.measure(UsageChartScale.axisLabel(maximum * index / 3), axisStyle)
            drawText(label, topLeft = Offset(plotLeft - label.size.width - 7.dp.toPx(), y - label.size.height / 2f))
        }
        val group = plotWidth / points.size
        val visibleCount = (if (showLighting) 1 else 0) + (if (showAir) 1 else 0)
        val barWidth = minOf(14.dp.toPx(), group * if (visibleCount == 1) 0.34f else 0.22f)
        fun bar(value: Double, x: Float, color: Color, alpha: Float) {
            if (alpha <= 0f) return
            val height = maxOf(if (value > 0) 4.dp.toPx() else 0f, (plotHeight * (value / maximum)).toFloat())
            drawRoundRect(
                color.copy(alpha = color.alpha * alpha), Offset(x, plotBottom - height), Size(barWidth, height),
                CornerRadius(minOf(barWidth / 2, 5.dp.toPx())),
            )
        }
        points.forEachIndexed { index, point ->
            val center = plotLeft + group * (index + 0.5f)
            if (selected == index) {
                drawRoundRect(colors.accent.copy(alpha = 0.09f), Offset(center - group / 2 + 1, plotTop), Size(group - 2, plotHeight), CornerRadius(9.dp.toPx()))
            }
            val emphasis = if (selected == null || selected == index) 1f else 0.35f
            if (showLighting && showAir) {
                bar(point.lighting, center - barWidth - 2.dp.toPx(), colors.lighting.copy(alpha = emphasis), lightingAlpha)
                bar(point.airConditioning, center + 2.dp.toPx(), colors.cooling.copy(alpha = emphasis), airAlpha)
            } else if (showLighting) {
                bar(point.lighting, center - barWidth / 2, colors.lighting.copy(alpha = emphasis), lightingAlpha)
            } else {
                bar(point.airConditioning, center - barWidth / 2, colors.cooling.copy(alpha = emphasis), airAlpha)
            }
            val text = if (point.day == today) "今天" else "${point.day.monthValue}/${point.day.dayOfMonth}"
            val label = measurer.measure(text, axisStyle)
            if (label.size.width < group - 2 || index == 0 || index == points.lastIndex || (index % 2 == 0 && index < points.size - 2)) {
                drawText(label, topLeft = Offset(center - label.size.width / 2f, plotBottom + 9.dp.toPx()))
            }
        }
    }
}
