package com.zebwqfox.hbustpower.ui.components

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.ui.theme.Power
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Platform haptics standing in for UIKit's impact/selection/notification generators. */
@Stable
class Haptics(private val view: View) {
    fun soft() = perform(HapticFeedbackConstants.KEYBOARD_TAP)
    fun selection() = perform(HapticFeedbackConstants.CLOCK_TICK)
    fun medium() = perform(HapticFeedbackConstants.CONTEXT_CLICK)
    fun longPress() = perform(HapticFeedbackConstants.LONG_PRESS)
    fun success() = perform(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.CONTEXT_CLICK)
    fun threshold() = perform(if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.GESTURE_THRESHOLD_ACTIVATE else HapticFeedbackConstants.CONTEXT_CLICK)
    private fun perform(constant: Int) { view.performHapticFeedback(constant) }
}

@Composable
fun rememberHaptics(): Haptics {
    val view = LocalView.current
    return remember(view) { Haptics(view) }
}

/**
 * Press language shared by buttons (0.965) and cards (0.978): quick shrink with a soft tick, interruptible
 * spring back. With animations removed only the opacity changes.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun Modifier.pressable(
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    pressedScale: Float = 0.978f,
    enabled: Boolean = true,
    role: Role = Role.Button,
    onClickLabel: String? = null,
): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val reduceMotion = Power.reduceMotion
    val haptics = rememberHaptics()
    LaunchedEffect(interaction) {
        interaction.interactions.collect { if (it is PressInteraction.Press) haptics.soft() }
    }
    val scale by animateFloatAsState(
        if (pressed && !reduceMotion) pressedScale else 1f,
        if (pressed) tween(160) else spring(dampingRatio = 0.62f, stiffness = Spring.StiffnessMediumLow),
        label = "press-scale",
    )
    val alpha by animateFloatAsState(if (pressed) 0.86f else 1f, tween(if (pressed) 120 else 260), label = "press-alpha")
    return this
        .graphicsLayer { scaleX = scale; scaleY = scale; this.alpha = if (enabled) alpha else 0.5f }
        .combinedClickable(
            interactionSource = interaction,
            indication = null,
            enabled = enabled,
            role = role,
            onClickLabel = onClickLabel,
            onLongClick = onLongClick?.let { long -> { haptics.longPress(); long() } },
            onClick = onClick,
        )
}

/** Fade + 12dp rise with a 45ms stagger, once per screen (`PowerMotion.reveal`). */
@Composable
fun Modifier.reveal(index: Int, key: Any = Unit): Modifier {
    val reduceMotion = Power.reduceMotion
    val progress = remember(key) { Animatable(if (reduceMotion) 1f else 0f) }
    LaunchedEffect(key) {
        if (!reduceMotion) {
            delay(index * 45L)
            progress.animateTo(1f, spring(dampingRatio = 1f, stiffness = Spring.StiffnessLow))
        }
    }
    return graphicsLayer {
        alpha = progress.value
        translationY = (1f - progress.value) * 12.dp.toPx()
    }
}

/** A capsule action button: prominent (filled accent) or glass-like (surface with accent text). */
@Composable
fun PowerButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    primary: Boolean = false,
    enabled: Boolean = true,
    loading: Boolean = false,
    accent: Color = Power.colors.accent,
) {
    val colors = Power.colors
    val shape = RoundedCornerShape(50)
    val background = if (primary) accent else colors.surface.copy(alpha = if (colors.isDark) 0.72f else 0.9f)
    val foreground = if (primary) (if (colors.isDark) colors.background else Color.White) else accent
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .shadow(if (primary) 10.dp else 6.dp, shape, ambientColor = accent.copy(alpha = 0.18f), spotColor = accent.copy(alpha = 0.18f))
            .clip(shape)
            .background(background)
            .border(0.6.dp, Color.White.copy(alpha = if (colors.isDark) 0.08f else 0.7f), shape)
            .pressable(onClick = onClick, pressedScale = 0.965f, enabled = enabled && !loading)
            .padding(horizontal = 20.dp, vertical = 14.dp),
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (loading) {
            CircularProgressIndicator(Modifier.size(18.dp), color = foreground, strokeWidth = 2.dp)
            Box(Modifier.width(10.dp))
        } else if (icon != null) {
            Icon(icon, null, tint = foreground, modifier = Modifier.size(20.dp))
            Box(Modifier.width(8.dp))
        }
        Text(title, color = foreground, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** Plain rounded surface card (`PowerCardView`). */
@Composable
fun PowerCard(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(22.dp),
    color: Color = Power.colors.surface,
    padding: androidx.compose.foundation.layout.PaddingValues = androidx.compose.foundation.layout.PaddingValues(16.dp),
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .shadow(if (Power.colors.isDark) 0.dp else 3.dp, shape, ambientColor = Color.Black.copy(alpha = 0.05f), spotColor = Color.Black.copy(alpha = 0.06f))
            .clip(shape)
            .background(color)
            .padding(padding),
        content = content,
    )
}

/** A tilted label with a white border, like a sticker pressed on by hand. Tap to wiggle. */
@Composable
fun Sticker(
    text: String,
    modifier: Modifier = Modifier,
    fill: Color = Power.colors.accent,
    angleRadians: Float = -0.08f,
    wiggleSignal: Int = 0,
    onClick: (() -> Unit)? = null,
) {
    val reduceMotion = Power.reduceMotion
    val haptics = rememberHaptics()
    val rotation = remember { Animatable(0f) }
    val scale = remember { Animatable(1f) }
    val scope = rememberCoroutineScope()
    val restDegrees = Math.toDegrees(angleRadians.toDouble()).toFloat()
    fun wiggle() {
        if (reduceMotion) return
        scope.launch {
            rotation.snapTo(-restDegrees * 2.8f)
            launch { scale.snapTo(1.14f); scale.animateTo(1f, spring(dampingRatio = 0.35f, stiffness = 300f)) }
            rotation.animateTo(0f, spring(dampingRatio = 0.35f, stiffness = 300f))
        }
    }
    LaunchedEffect(wiggleSignal) { if (wiggleSignal > 0) { haptics.medium(); wiggle() } }
    val shape = RoundedCornerShape(50)
    val clickable = if (onClick != null) Modifier.combinedClickable(
        interactionSource = remember { MutableInteractionSource() }, indication = null,
    ) { haptics.medium(); wiggle(); onClick() } else Modifier
    Box(
        modifier
            .graphicsLayer {
                rotationZ = restDegrees + rotation.value
                scaleX = scale.value; scaleY = scale.value
            }
            .shadow(4.dp, shape, ambientColor = Color.Black.copy(alpha = 0.14f), spotColor = Color.Black.copy(alpha = 0.14f))
            .clip(shape)
            .background(fill)
            .border(2.5.dp, Color.White, shape)
            .then(clickable)
            .padding(horizontal = 10.dp, vertical = 5.dp),
    ) {
        Text(text, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
    }
}
