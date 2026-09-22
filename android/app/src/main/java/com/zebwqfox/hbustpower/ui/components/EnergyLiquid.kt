package com.zebwqfox.hbustpower.ui.components

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.zebwqfox.hbustpower.ui.theme.Power
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Physics of `EnergyLiquidView` (iOS `PlayfulViews.swift`), kept free of Android types so the tilt direction
 * can be unit tested. Positive tilt piles liquid to the right: the right side of the surface rises.
 */
class LiquidPhysics(private val random: Random = Random.Default) {
    var level = 0.0
        set(value) { field = value.coerceIn(0.0, 1.0) }
    var shownLevel = 0.0; private set
    var tilt = 0.0; private set
    var tiltVelocity = 0.0; private set
    var phase = 0.0; private set
    var splash = 0.6; private set
    var gravityTilt = 0.0; private set
    var dragTilt = 0.0; private set

    /** A touch disturbs the surface. */
    fun slosh(strength: Double = 0.7) {
        splash = min(1.4, splash + strength)
        tiltVelocity += (if (random.nextBoolean()) 1 else -1) * strength * 0.9
    }

    /** Horizontal finger offset in -1..1 pushes the liquid; null when released. */
    fun push(offset: Double?) {
        if (offset == null) {
            dragTilt = 0.0
            slosh(0.5)
        } else {
            dragTilt = offset.coerceIn(-1.0, 1.0) * 0.32
        }
    }

    /**
     * Android `TYPE_GRAVITY` reports the reaction to gravity, so tilting the phone left gives a positive x.
     * iOS `CMDeviceMotion.gravity.x` points at the ground (negative when tilted left), hence the sign flip.
     */
    fun setAndroidGravityX(valuesX: Float?) {
        if (valuesX == null) { gravityTilt = 0.0; return }
        val iosGravityX = -valuesX / 9.81
        gravityTilt = (iosGravityX * 0.6).coerceIn(-0.35, 0.35)
    }

    fun step(dtSeconds: Double) {
        val dt = min(0.05, dtSeconds)
        val target = gravityTilt + dragTilt
        tiltVelocity += ((target - tilt) * 38 - tiltVelocity * 5.5) * dt
        tilt += tiltVelocity * dt
        phase += dt * (2.1 + splash * 2)
        splash *= exp(-dt * 1.3)
        shownLevel += (level - shownLevel) * min(1.0, dt * 2.4)
    }

    fun settleStill() { shownLevel = level; tilt = 0.0; tiltVelocity = 0.0 }

    val amplitude: Double get() = 3.5 + splash * 9

    /** Surface height (y grows downwards) at [x] for a box of [width] x [height], in the same units. */
    fun surfaceY(x: Double, width: Double, height: Double, amplitude: Double, offset: Double, raise: Double): Double {
        val baseline = height * (1 - shownLevel) - raise
        return baseline - tilt * (x - width / 2) + amplitude * sin(x / width * PI * 2.4 + offset)
    }

    companion object {
        /** A month of forecast fills the card; without a forecast, 300 kWh does. */
        fun levelFor(predictedDays: Double?, balance: Double): Double =
            ((predictedDays?.let { it / 30 }) ?: (balance / 300)).coerceIn(0.0, 1.0)
    }
}

@Stable
class LiquidController {
    internal val physics = LiquidPhysics()
    internal var frame by mutableLongStateOf(0L)
    fun slosh(strength: Double = 0.7) = physics.slosh(strength)
    fun push(offset: Double?) = physics.push(offset)
}

@Composable
fun rememberLiquidController() = remember { LiquidController() }

/**
 * Two waves filling the balance card behind its text. Runs a frame loop only while resumed and [active]
 * (on screen); gravity is used only when [gravityEnabled] (portrait phone layout).
 */
@Composable
fun EnergyLiquid(
    controller: LiquidController,
    level: Double,
    isLow: Boolean,
    active: Boolean,
    gravityEnabled: Boolean,
    modifier: Modifier = Modifier,
) {
    val colors = Power.colors
    val reduceMotion = Power.reduceMotion
    val tint = if (isLow) colors.lighting else colors.accent
    val physics = controller.physics
    physics.level = level
    val running = active && !reduceMotion
    val lifecycle = LocalLifecycleOwner.current.lifecycle

    LaunchedEffect(running, lifecycle) {
        if (!running) {
            physics.settleStill()
            controller.frame++
            return@LaunchedEffect
        }
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            var last = 0L
            while (true) {
                withFrameNanos { now ->
                    val dt = if (last == 0L) 1.0 / 60 else (now - last) / 1e9
                    last = now
                    physics.step(dt)
                    controller.frame = now
                }
            }
        }
    }

    GravitySensor(enabled = running && gravityEnabled) { x -> physics.setAndroidGravityX(x) }

    Canvas(modifier) {
        controller.frame // read to redraw each frame
        val width = size.width.toDouble()
        val height = size.height.toDouble()
        if (width <= 0) return@Canvas
        val unit = density.toDouble()
        val amplitude = (if (running) physics.amplitude else 3.0) * unit
        fun wave(amplitude: Double, offset: Double, raise: Double, alpha: Float) {
            val path = Path().apply {
                moveTo(0f, size.height)
                var x = 0.0
                val step = 4 * unit
                while (x <= width + step) {
                    val y = physics.surfaceY(x, width, height, amplitude, offset, raise * unit)
                    lineTo(x.toFloat(), min(height, y).toFloat())
                    x += step
                }
                lineTo(size.width, size.height)
                close()
            }
            drawPath(path, tint.copy(alpha = alpha))
        }
        wave(amplitude * 0.8, physics.phase * 0.8 + 1.7, 5.0, 0.08f)
        wave(amplitude, physics.phase, 0.0, 0.13f)
    }
}

@Composable
private fun GravitySensor(enabled: Boolean, onGravityX: (Float?) -> Unit) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(enabled, lifecycle) {
        if (!enabled) {
            onGravityX(null)
            return@DisposableEffect onDispose { }
        }
        val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) = onGravityX(event.values[0])
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        fun update() {
            manager.unregisterListener(listener)
            if (sensor != null && lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
            } else onGravityX(null)
        }
        val observer = LifecycleEventObserver { _, _ -> update() }
        lifecycle.addObserver(observer)
        update()
        onDispose {
            lifecycle.removeObserver(observer)
            manager.unregisterListener(listener)
            onGravityX(null)
        }
    }
}
