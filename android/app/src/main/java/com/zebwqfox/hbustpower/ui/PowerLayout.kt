package com.zebwqfox.hbustpower.ui

import android.app.Activity
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toComposeRect
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.theme.Power

/**
 * Layout decisions made from window size classes, never device model, orientation or raw pixels
 * (Android large-screen guidance; iOS `PowerLayout`). Medium/Expanded width → two columns.
 */
data class PowerLayoutInfo(
    val widthDp: Float,
    val heightDp: Float,
    /** A vertical, separating hinge (half-opened book posture or a physical gap), in window pixels. */
    val verticalFold: Rect? = null,
) {
    val isWide: Boolean get() = widthDp >= 600f
    val isShort: Boolean get() = heightDp < 480f
    /** Compact width and regular height: the only layout where sensor axes match the screen. */
    val isPortraitPhone: Boolean get() = !isWide && !isShort
    val maxContentWidth: Dp get() = if (isWide) 980.dp else 620.dp
    /** Short windows (landscape phones, small split screens) keep the chart compact even when they are wide. */
    val chartHeight: Dp get() = when { isShort -> 170.dp; isWide -> 280.dp; else -> 198.dp }
}

val LocalPowerLayout = staticCompositionLocalOf { PowerLayoutInfo(400f, 800f) }

/** Space reserved below page content for the floating bottom bar (zero with a navigation rail). */
val LocalBottomBarSpace = staticCompositionLocalOf { 0.dp }

@Composable
fun rememberPowerLayout(): PowerLayoutInfo {
    val density = LocalDensity.current
    val size = LocalWindowInfo.current.containerSize
    val activity = LocalActivity.current
    var fold by remember { mutableStateOf<Rect?>(null) }
    LaunchedEffect(activity) {
        if (activity == null) return@LaunchedEffect
        WindowInfoTracker.getOrCreate(activity).windowLayoutInfo(activity).collect { info ->
            fold = info.displayFeatures.filterIsInstance<FoldingFeature>().firstOrNull {
                it.orientation == FoldingFeature.Orientation.VERTICAL &&
                    (it.state == FoldingFeature.State.HALF_OPENED || it.isSeparating)
            }?.bounds?.toComposeRect()
        }
    }
    return with(density) { PowerLayoutInfo(size.width.toDp().value, size.height.toDp().value, fold) }
}

/** Width-centred readable column; horizontal padding respects uneven safe-drawing insets on each side. */
@Composable
fun PageColumn(
    modifier: Modifier = Modifier,
    maxWidth: Dp = LocalPowerLayout.current.maxContentWidth,
    topPadding: Dp = 12.dp,
    spacing: Dp = 16.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(
        modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal)),
        contentAlignment = Alignment.TopCenter,
    ) {
        Column(
            Modifier
                .widthIn(max = maxWidth + 48.dp)
                .fillMaxWidth()
                .padding(PaddingValues(start = 24.dp, end = 24.dp, top = topPadding, bottom = 28.dp + LocalBottomBarSpace.current)),
            verticalArrangement = Arrangement.spacedBy(spacing),
            content = content,
        )
    }
}

/** A top-level tab page: large title, round actions, pull-to-charge handled by the caller. */
@Composable
fun LargeTitleHeader(title: String, actions: @Composable RowScope.() -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().statusBarsPadding().padding(top = 8.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title, fontSize = 34.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f).semantics { heading() },
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), content = actions)
    }
}

@Composable
fun RoundIconButton(icon: ImageVector, label: String, onClick: () -> Unit, enabled: Boolean = true, tint: Color = Power.colors.accent) {
    val colors = Power.colors
    Box(
        Modifier
            .size(48.dp)
            .shadow(8.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.1f), spotColor = Color.Black.copy(alpha = 0.1f))
            .clip(CircleShape)
            .background(colors.surface)
            .pressable(onClick = onClick, pressedScale = 0.92f, enabled = enabled, onClickLabel = label),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, label, tint = if (enabled) tint else colors.tertiaryText)
    }
}

/** A pushed page: back button, centred title and its own scrolling content. */
@Composable
fun DetailPage(
    title: String,
    onBack: () -> Unit,
    backIcon: ImageVector,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize().background(Power.colors.background)) {
        Box(
            Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal))
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Box(Modifier.align(Alignment.CenterStart)) { RoundIconButton(backIcon, "返回", onBack, tint = Power.colors.accent) }
            Text(
                title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                modifier = Modifier.align(Alignment.Center).padding(horizontal = 64.dp).semantics { heading() },
            )
            Row(Modifier.align(Alignment.CenterEnd), content = actions)
        }
        PageColumn(Modifier.weight(1f), content = content)
    }
}

@Composable
fun VerticalSpace(height: Dp) = Spacer(Modifier.height(height))
