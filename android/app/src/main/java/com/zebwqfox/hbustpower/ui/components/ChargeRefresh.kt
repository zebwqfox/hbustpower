package com.zebwqfox.hbustpower.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.ui.theme.Power
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Copy and ring rules for pull-to-charge (iOS 1.7.2 `ChargeRefreshControl`). Compose's pull-to-refresh already
 * fires on release, so the phases map directly: pulling → armed at the threshold → charging → success/failure.
 */
object ChargeRefreshRules {
    enum class Phase { IDLE, ARMED, CHARGING, SUCCESS, FAILURE }

    const val MINIMUM_CHARGING_MILLIS = 800L
    const val OUTCOME_MILLIS = 750L
    const val REDUCED_OUTCOME_MILLIS = 300L
    /** Below this fraction of the threshold an armed pull disarms again. */
    const val DISARM_FRACTION = 0.9f

    val chargingCaptions = listOf("正在连接宿舍电表…", "滋滋滋，数据充电中…", "去学校系统看一眼…")

    fun ringFill(phase: Phase, pullFraction: Float): Float = when (phase) {
        Phase.IDLE -> pullFraction.coerceIn(0f, 1f)
        Phase.ARMED -> 1f
        Phase.CHARGING -> 0.3f
        Phase.SUCCESS, Phase.FAILURE -> 1f
    }

    fun caption(phase: Phase, pullFraction: Float, chargingCaption: String): String = when (phase) {
        Phase.IDLE -> if (pullFraction < 0.05f) "" else "继续下拉，给数据充电"
        Phase.ARMED -> "松手，开始充电 ⚡"
        Phase.CHARGING -> chargingCaption
        Phase.SUCCESS -> "充满啦！"
        Phase.FAILURE -> "没充上电，稍后再试"
    }
}

/**
 * @param loading whether a refresh is in flight.
 * @param succeeded read once the refresh ends, to show the green or the orange outcome.
 * @param onCharged called after a successful charge is shown, e.g. to slosh the balance card.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChargeRefreshBox(
    loading: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
    succeeded: () -> Boolean = { true },
    onCharged: () -> Unit = {},
    content: @Composable BoxScope.() -> Unit,
) {
    val state = rememberPullToRefreshState()
    val haptics = rememberHaptics()
    val reduceMotion = Power.reduceMotion
    val scope = rememberCoroutineScope()
    val outcome by rememberUpdatedState(succeeded)
    val charged by rememberUpdatedState(onCharged)
    var phase by remember { mutableStateOf(ChargeRefreshRules.Phase.IDLE) }
    var holding by remember { mutableStateOf(false) }
    var chargingCaption by remember { mutableStateOf(ChargeRefreshRules.chargingCaptions.first()) }
    var startedAt by remember { mutableStateOf(0L) }
    var pointersDown by remember { mutableIntStateOf(0) }
    var chargeId by remember { mutableIntStateOf(0) }
    val sparks = remember { SparkField() }

    // Arm at the threshold, disarm when pulled back, both with their own feedback.
    LaunchedEffect(state) {
        snapshotFlow { state.distanceFraction }.collect { fraction ->
            when {
                phase == ChargeRefreshRules.Phase.IDLE && fraction >= 1f && pointersDown > 0 -> {
                    phase = ChargeRefreshRules.Phase.ARMED
                    haptics.medium()
                    if (!reduceMotion) sparks.burst(10)
                }
                phase == ChargeRefreshRules.Phase.ARMED && fraction < ChargeRefreshRules.DISARM_FRACTION -> {
                    phase = ChargeRefreshRules.Phase.IDLE
                    haptics.selection()
                }
            }
        }
    }

    LaunchedEffect(chargeId, loading) {
        if (phase == ChargeRefreshRules.Phase.CHARGING) {
            if (loading) return@LaunchedEffect
            val elapsed = System.currentTimeMillis() - startedAt
            if (!reduceMotion) delay((ChargeRefreshRules.MINIMUM_CHARGING_MILLIS - elapsed).coerceAtLeast(0))
            val success = outcome()
            phase = if (success) ChargeRefreshRules.Phase.SUCCESS else ChargeRefreshRules.Phase.FAILURE
            if (success) {
                haptics.success()
                if (!reduceMotion) sparks.burst(18)
                charged()
            } else {
                haptics.medium()
            }
            delay(if (reduceMotion) ChargeRefreshRules.REDUCED_OUTCOME_MILLIS else ChargeRefreshRules.OUTCOME_MILLIS)
        } else if (phase != ChargeRefreshRules.Phase.SUCCESS && phase != ChargeRefreshRules.Phase.FAILURE) {
            return@LaunchedEffect
        }
        // Collapse only once the finger is up, and keep the outcome visible while the indicator slides away.
        snapshotFlow { pointersDown }.first { it == 0 }
        holding = false
        snapshotFlow { state.distanceFraction }.first { it <= 0.01f }
        phase = ChargeRefreshRules.Phase.IDLE
    }

    // Steady sparks while charging.
    LaunchedEffect(phase, reduceMotion) {
        if (phase != ChargeRefreshRules.Phase.CHARGING || reduceMotion) return@LaunchedEffect
        while (true) {
            sparks.burst(2)
            delay(140)
        }
    }
    val lines = ChargeRefreshRules.chargingCaptions + Power.colors.style.chargingLine
    LaunchedEffect(phase, lines) {
        if (phase != ChargeRefreshRules.Phase.CHARGING) return@LaunchedEffect
        var index = lines.indices.random()
        while (true) {
            chargingCaption = lines[index]
            delay(1100)
            index = (index + 1) % lines.size
        }
    }

    val indicatorHeight = 56.dp
    val indicatorPx = with(LocalDensity.current) { indicatorHeight.toPx() }
    PullToRefreshBox(
        isRefreshing = holding,
        onRefresh = {
            if (phase != ChargeRefreshRules.Phase.IDLE && phase != ChargeRefreshRules.Phase.ARMED) return@PullToRefreshBox
            startedAt = System.currentTimeMillis()
            chargeId++
            holding = true
            phase = ChargeRefreshRules.Phase.CHARGING
            haptics.threshold()
            scope.launch { if (!reduceMotion) sparks.burst(6) }
            onRefresh()
        },
        state = state,
        modifier = modifier.pointerInput(Unit) {
            awaitPointerEventScope {
                while (true) {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    pointersDown = event.changes.count { it.pressed }
                }
            }
        },
        indicator = {
            ChargeIndicator(
                phase = phase,
                fraction = state.distanceFraction,
                caption = ChargeRefreshRules.caption(phase, state.distanceFraction, chargingCaption),
                sparks = sparks,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .height(indicatorHeight)
                    .graphicsLayer {
                        alpha = (state.distanceFraction * 1.6f).coerceIn(0f, 1f)
                        translationY = state.distanceFraction.coerceAtMost(1.4f) * indicatorPx - indicatorPx
                    },
            )
        },
    ) {
        Box(Modifier.graphicsLayer { translationY = state.distanceFraction.coerceAtMost(1.4f) * indicatorPx * 0.9f }) {
            content()
        }
    }
}

@Composable
private fun ChargeIndicator(
    phase: ChargeRefreshRules.Phase,
    fraction: Float,
    caption: String,
    sparks: SparkField,
    modifier: Modifier,
) {
    val colors = Power.colors
    val reduceMotion = Power.reduceMotion
    val charging = phase == ChargeRefreshRules.Phase.CHARGING && !reduceMotion
    val transition = rememberInfiniteTransition(label = "charge")
    val spin by transition.animateFloat(0f, 360f, infiniteRepeatable(tween(900, easing = LinearEasing)), label = "spin")
    val pulse by transition.animateFloat(0.82f, 1.18f, infiniteRepeatable(tween(400), RepeatMode.Reverse), label = "pulse")
    val glow by transition.animateFloat(0.15f, 0.9f, infiniteRepeatable(tween(600), RepeatMode.Reverse), label = "glow")
    val fill = ChargeRefreshRules.ringFill(phase, fraction)
    val hot = phase == ChargeRefreshRules.Phase.ARMED || phase == ChargeRefreshRules.Phase.CHARGING
    val ringColor = when (phase) {
        ChargeRefreshRules.Phase.SUCCESS -> colors.good
        ChargeRefreshRules.Phase.FAILURE -> colors.lighting
        else -> if (hot) colors.spark else colors.accent
    }
    val captionColor = when (phase) {
        ChargeRefreshRules.Phase.SUCCESS -> colors.good
        ChargeRefreshRules.Phase.FAILURE -> colors.lighting
        else -> colors.secondaryText
    }
    val boltScale = when {
        reduceMotion -> 1f
        phase == ChargeRefreshRules.Phase.IDLE -> 0.6f + fraction.coerceIn(0f, 1f) * 0.4f
        phase == ChargeRefreshRules.Phase.ARMED -> 1f
        charging -> pulse
        else -> 1f
    }
    val armedBounce = remember { Animatable(1f) }
    LaunchedEffect(phase) {
        if (phase == ChargeRefreshRules.Phase.ARMED && !reduceMotion) {
            armedBounce.snapTo(1.35f)
            armedBounce.animateTo(1f, spring(dampingRatio = 0.4f, stiffness = Spring.StiffnessMedium))
        } else armedBounce.snapTo(1f)
    }
    // A failed charge shakes its head.
    val shake = remember { Animatable(0f) }
    LaunchedEffect(phase) {
        if (phase == ChargeRefreshRules.Phase.FAILURE && !reduceMotion) {
            shake.animateTo(0f, keyframes {
                durationMillis = 450
                -6f at 70; 6f at 150; -4f at 230; 4f at 310; -2f at 390
            })
        } else shake.snapTo(0f)
    }
    val checkScale = remember { Animatable(0.2f) }
    LaunchedEffect(phase) {
        if (phase == ChargeRefreshRules.Phase.SUCCESS) {
            if (reduceMotion) checkScale.snapTo(1f)
            else {
                checkScale.snapTo(0.2f)
                delay(80)
                checkScale.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium))
            }
        } else checkScale.snapTo(0.2f)
    }
    // Keep the particle field ticking while anything is on screen.
    LaunchedEffect(Unit) {
        var last = 0L
        while (true) {
            withFrameNanos { now ->
                val dt = if (last == 0L) 1f / 60 else ((now - last) / 1e9).toFloat()
                last = now
                sparks.step(dt)
            }
        }
    }
    val stretch = if (reduceMotion) 1f else 1f + ((fraction - 1f) * 0.3f).coerceIn(0f, 0.12f)

    Row(
        modifier,
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(34.dp)
                .graphicsLayer {
                    scaleX = stretch; scaleY = stretch
                    translationX = shake.value * density
                },
            contentAlignment = Alignment.Center,
        ) {
            Canvas(Modifier.size(34.dp)) {
                val stroke = 3.5.dp.toPx()
                val inset = stroke / 2
                val arcSize = Size(size.width - stroke, size.height - stroke)
                if (hot && !reduceMotion) {
                    // The glow breathes while charging and sits steady when armed.
                    drawCircle(ringColor.copy(alpha = 0.18f * if (charging) glow else 0.7f), radius = size.minDimension / 2 + 5.dp.toPx())
                }
                drawArc(colors.accent.copy(alpha = 0.15f), 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                // Only the arc spins; the bolt stays upright.
                rotate(if (charging) spin else 0f) {
                    drawArc(ringColor, -90f, 360f * fill, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
                }
                sparks.draw(this, Offset(size.width / 2, size.height / 2), listOf(ringColor, colors.spark, colors.accent))
            }
            if (phase == ChargeRefreshRules.Phase.SUCCESS) {
                Icon(
                    Icons.Filled.Check, null, tint = colors.good,
                    modifier = Modifier.size(17.dp).graphicsLayer { scaleX = checkScale.value; scaleY = checkScale.value },
                )
            } else {
                val rise = if (reduceMotion || phase != ChargeRefreshRules.Phase.IDLE) 0f else (1f - fraction.coerceIn(0f, 1f)) * 6f
                Icon(
                    Icons.Filled.Bolt, null, tint = ringColor,
                    modifier = Modifier
                        .size(17.dp)
                        .graphicsLayer {
                            val scale = boltScale * armedBounce.value
                            scaleX = scale; scaleY = scale
                            translationY = rise * density
                            alpha = if (phase == ChargeRefreshRules.Phase.IDLE) 0.35f + fraction.coerceIn(0f, 1f) * 0.65f else 1f
                        },
                )
            }
        }
        Spacer(Modifier.width(10.dp))
        Text(
            caption, color = captionColor, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        )
    }
}

/** A tiny particle field for the charge sparks; positions are in pixels relative to the ring centre. */
class SparkField(private val random: Random = Random.Default) {
    private class Spark(var x: Float, var y: Float, var vx: Float, var vy: Float, var life: Float, val tint: Int)

    private val sparks = mutableListOf<Spark>()
    private var version by mutableIntStateOf(0)

    fun burst(count: Int) {
        repeat(count) {
            val angle = random.nextDouble(0.0, Math.PI * 2)
            val speed = 40f + random.nextFloat() * 70f
            sparks += Spark(0f, 0f, (cos(angle) * speed).toFloat(), (sin(angle) * speed).toFloat(), 1f, random.nextInt(3))
        }
        version++
    }

    fun step(seconds: Float) {
        if (sparks.isEmpty()) return
        val dt = seconds.coerceAtMost(0.05f)
        sparks.forEach { spark ->
            spark.x += spark.vx * dt
            spark.y += spark.vy * dt + 60f * dt * dt
            spark.vy += 90f * dt
            spark.life -= dt * 1.6f
        }
        sparks.removeAll { it.life <= 0f }
        version++
    }

    fun draw(scope: androidx.compose.ui.graphics.drawscope.DrawScope, centre: Offset, palette: List<Color>) {
        version // read so the canvas redraws with the field
        val density = scope.density
        sparks.forEach { spark ->
            val color = palette[spark.tint % palette.size]
            scope.drawCircle(
                color.copy(alpha = spark.life.coerceIn(0f, 1f) * 0.9f),
                radius = (1f + spark.life * 1.6f) * density,
                center = Offset(centre.x + spark.x * density * 0.35f, centre.y + spark.y * density * 0.35f),
            )
        }
    }
}
