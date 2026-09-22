package com.zebwqfox.hbustpower.ui.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.model.PowerThemeStyle
import com.zebwqfox.hbustpower.ui.DetailPage
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.components.PowerCard
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.components.rememberHaptics
import com.zebwqfox.hbustpower.ui.theme.Power
import kotlinx.coroutines.launch

/** 设置 → 外观 → 主题 (iOS 1.9.0). Tapping the selected theme again plays its signature animation. */
@Composable
fun ThemePickerScreen(model: PowerViewModel, onBack: () -> Unit) {
    val colors = Power.colors
    var greeting by remember { mutableStateOf<String?>(null) }
    DetailPage("主题", onBack, Icons.AutoMirrored.Filled.ArrowBack) {
        Text(
            "换个颜色，整个界面的配色一起变。深色模式下每套主题都有自己的夜间配色。",
            color = colors.secondaryText, fontSize = 15.sp,
        )
        PowerThemeStyle.entries.forEach { style ->
            ThemeRow(
                style = style,
                selected = style == model.theme,
                onSelect = {
                    if (style == model.theme) greeting = style.greeting else model.selectTheme(style)
                },
            )
        }
        greeting?.let {
            Text(
                it, color = colors.accent, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            )
        }
        Text(
            "两套朋友主题的配色来自他们的形象，经本人同意后收录。",
            color = colors.tertiaryText, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp),
        )
    }
}

@Composable
private fun ThemeRow(style: PowerThemeStyle, selected: Boolean, onSelect: () -> Unit) {
    val colors = Power.colors
    val reduceMotion = Power.reduceMotion
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val dark = colors.isDark
    val swatch = if (dark) style.dark else style.light
    val accent = Color(swatch.accent)
    var plays by remember { mutableIntStateOf(0) }
    val wobble = remember { Animatable(0f) }
    val bounce = remember { Animatable(1f) }

    LaunchedEffect(plays) {
        if (plays == 0 || reduceMotion) return@LaunchedEffect
        when (style) {
            // A bolt jumps, a moon twinkles, a bell swings.
            PowerThemeStyle.CLASSIC -> scope.launch {
                bounce.snapTo(1.3f); bounce.animateTo(1f, spring(dampingRatio = 0.35f, stiffness = Spring.StiffnessMedium))
            }
            PowerThemeStyle.PURPLE_BIRD -> scope.launch {
                bounce.snapTo(0.7f); bounce.animateTo(1f, spring(dampingRatio = 0.5f))
            }
            PowerThemeStyle.MAPLE_YELLOW -> scope.launch {
                wobble.animateTo(0f, keyframes {
                    durationMillis = 520
                    -18f at 90; 15f at 190; -10f at 290; 6f at 390
                })
            }
        }
    }

    PowerCard(
        Modifier
            .pressable(
                onClick = { haptics.selection(); plays++; onSelect() },
                onClickLabel = if (selected) "再播放一次主题动效" else "使用该主题",
            )
            .semantics { stateDescription = if (selected) "已选中" else "未选中" },
        padding = PaddingValues(18.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(46.dp)
                    .graphicsLayer {
                        rotationZ = wobble.value
                        scaleX = bounce.value; scaleY = bounce.value
                    }
                    .clip(CircleShape)
                    .background(Color(swatch.hero))
                    .border(1.dp, accent.copy(alpha = 0.35f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(style.icon, null, tint = accent, modifier = Modifier.size(24.dp))
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(style.displayName, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(style.tagline, color = colors.secondaryText, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp))
                style.credit?.let {
                    Text(it, color = colors.tertiaryText, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
                }
            }
            if (selected) Icon(Icons.Filled.CheckCircle, "已选中", tint = accent)
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(swatch.background, swatch.surface, swatch.hero, swatch.accent, swatch.secondary, swatch.spark).forEach {
                Box(
                    Modifier
                        .weight(1f)
                        .height(18.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color(it))
                        .border(0.5.dp, colors.separator, RoundedCornerShape(6.dp))
                        .semantics { contentDescription = "" },
                )
            }
        }
    }
}

/** The symbol iOS shows for each theme, mapped to Material icons. */
private val PowerThemeStyle.icon: ImageVector
    get() = when (this) {
        PowerThemeStyle.CLASSIC -> Icons.Filled.Bolt
        PowerThemeStyle.PURPLE_BIRD -> Icons.Filled.NightsStay
        PowerThemeStyle.MAPLE_YELLOW -> Icons.Filled.NotificationsActive
    }
