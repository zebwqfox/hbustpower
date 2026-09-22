package com.zebwqfox.hbustpower.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.ui.theme.Power

/** A point on a doodle, in dp-like units before scaling. */
data class DoodlePoint(val x: Double, val y: Double)

/** A quadratic segment: control point then end point. */
data class DoodleCurve(val control: DoodlePoint, val end: DoodlePoint)

/**
 * Port of `HandDrawn.squiggle` from iOS `PlayfulViews.swift`: the same xorshift generator, seed + 7 and
 * the same bounded random double as Swift's `CGFloat.random(in:using:)`, so a heading gets the same wobble.
 */
object HandDrawn {
    fun squiggle(width: Double, height: Double, seed: Int): Pair<DoodlePoint, List<DoodleCurve>> {
        val random = SeededGenerator((seed + 7).toLong().toULong())
        val segments = maxOf(3, (width / 22).toInt())
        val start = DoodlePoint(1.0, height * 0.6)
        val curves = (1..segments).map { index ->
            val x = width * index / segments
            val wobble = random.nextDouble(-0.35, 0.35) * height
            val control = DoodlePoint(
                x - width / segments / 2,
                (if (index % 2 == 0) height * 0.15 else height * 0.95) + wobble * 0.4,
            )
            DoodleCurve(control, DoodlePoint(x - 1, height * 0.55 + wobble * 0.3))
        }
        return start to curves
    }

    fun path(width: Float, height: Float, seed: Int, scale: Float): Path {
        val (start, curves) = squiggle(width.toDouble(), height.toDouble(), seed)
        return Path().apply {
            moveTo(start.x.toFloat() * scale, start.y.toFloat() * scale)
            curves.forEach {
                quadraticTo(
                    it.control.x.toFloat() * scale, it.control.y.toFloat() * scale,
                    it.end.x.toFloat() * scale, it.end.y.toFloat() * scale,
                )
            }
        }
    }

    class SeededGenerator(seed: ULong) {
        private var state: ULong = if (seed == 0uL) 0x9E3779B97F4A7C15uL else seed

        fun next(): ULong {
            state = state xor (state shl 13)
            state = state xor (state shr 7)
            state = state xor (state shl 17)
            return state
        }

        /** Swift's `BinaryFloatingPoint.random(in: ClosedRange, using:)` for Double. */
        fun nextDouble(lower: Double, upper: Double): Double {
            val maxSignificand = 1uL shl 53
            val rand = nextBounded(maxSignificand + 1uL)
            if (rand == maxSignificand) return upper
            return (upper - lower) * (rand.toDouble() * (1.0 / maxSignificand.toDouble())) + lower
        }

        /** Lemire's nearly divisionless bounded integer, as in Swift's `RandomNumberGenerator.next(upperBound:)`. */
        private fun nextBounded(upperBound: ULong): ULong {
            var random = next()
            var (high, low) = multiplyFull(random, upperBound)
            if (low < upperBound) {
                val threshold = (0uL - upperBound) % upperBound
                while (low < threshold) {
                    random = next()
                    val product = multiplyFull(random, upperBound)
                    high = product.first
                    low = product.second
                }
            }
            return high
        }

        private fun multiplyFull(a: ULong, b: ULong): Pair<ULong, ULong> {
            val mask = 0xFFFFFFFFuL
            val aLow = a and mask
            val aHigh = a shr 32
            val bLow = b and mask
            val bHigh = b shr 32
            val lowLow = aLow * bLow
            val highLow = aHigh * bLow
            val lowHigh = aLow * bHigh
            val highHigh = aHigh * bHigh
            val cross = (lowLow shr 32) + (highLow and mask) + lowHigh
            val high = highHigh + (highLow shr 32) + (cross shr 32)
            val low = (cross shl 32) or (lowLow and mask)
            return high to low
        }
    }
}

/** A doodled underline that draws itself (0.7 s) the first time it appears. */
@Composable
fun Squiggle(seed: Int, modifier: Modifier = Modifier, color: Color = Power.colors.accent, strokeWidth: Float = 2.6f) {
    val reduceMotion = Power.reduceMotion
    var drawn by rememberSaveable(seed) { mutableStateOf(false) }
    val progress = remember { Animatable(if (drawn || reduceMotion) 1f else 0f) }
    LaunchedEffect(Unit) {
        if (!drawn && !reduceMotion) {
            kotlinx.coroutines.delay(250)
            progress.animateTo(1f, tween(700, easing = FastOutSlowInEasing))
        }
        drawn = true
    }
    val density = LocalDensity.current.density
    Canvas(modifier.height(8.dp)) {
        val path = HandDrawn.path(size.width / density, size.height / density, seed, density)
        val drawPath = if (progress.value >= 1f) path else Path().also { partial ->
            val measure = PathMeasure()
            measure.setPath(path, false)
            measure.getSegment(0f, measure.length * progress.value, partial, true)
        }
        drawPath(drawPath, color.copy(alpha = 0.55f), style = Stroke(strokeWidth * density, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** A title with a doodled underline sized to the text. */
@Composable
fun DoodleHeading(title: String, seed: Int, modifier: Modifier = Modifier, detail: String? = null) {
    Column(modifier) {
        var titleWidth by remember { mutableStateOf(0) }
        val density = LocalDensity.current
        Text(
            title,
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold, fontSize = 20.sp),
            modifier = Modifier.semantics { heading() }.onSizeChanged { titleWidth = it.width },
        )
        if (titleWidth > 0) {
            Squiggle(seed, Modifier.padding(top = 1.dp).width(with(density) { (titleWidth * 0.9f).toDp() }))
        }
        detail?.let {
            Text(it, color = Power.colors.secondaryText, fontSize = 15.sp, modifier = Modifier.padding(top = 4.dp))
        }
    }
}

/** Plain section heading with an optional detail line (`PowerTheme.heading`). */
@Composable
fun SectionHeading(title: String, modifier: Modifier = Modifier, detail: String? = null) {
    Column(modifier.fillMaxWidth()) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.semantics { heading() })
        detail?.let { Text(it, color = Power.colors.secondaryText, fontSize = 15.sp, modifier = Modifier.padding(top = 5.dp)) }
    }
}
