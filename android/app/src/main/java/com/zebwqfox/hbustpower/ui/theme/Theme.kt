package com.zebwqfox.hbustpower.ui.theme

import android.app.Activity
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.zebwqfox.hbustpower.model.PowerThemeStyle
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

/** Mirrors `Views/PowerTheme.swift`: cloud white, clear blue, and a warm lighting accent. */
@Immutable
data class PowerPalette(
    val background: Color,
    val surface: Color,
    val accent: Color,
    val hero: Color,
    val lighting: Color,
    val cooling: Color,
    /** Sparks and the charging ring; always bright enough to read as "electric". */
    val spark: Color,
    val good: Color,
    val danger: Color,
    val loginAccent: Color,
    val secondaryText: Color,
    val tertiaryText: Color,
    val separator: Color,
    val isDark: Boolean,
    val style: PowerThemeStyle = PowerThemeStyle.CLASSIC,
)

/** Fixed parts of the palette; only the theme-driven colours come from [PowerThemeStyle]. */
private fun palette(style: PowerThemeStyle, dark: Boolean): PowerPalette {
    val colors = if (dark) style.dark else style.light
    return PowerPalette(
        background = Color(colors.background),
        surface = Color(colors.surface),
        accent = Color(colors.accent),
        hero = Color(colors.hero),
        lighting = Color(colors.secondary),
        cooling = Color(colors.accent),
        spark = Color(colors.spark),
        good = if (dark) Color(0xFF4CD27A) else Color(0xFF2E9E4F),
        danger = if (dark) Color(0xFFFF6B61) else Color(0xFFE5392F),
        loginAccent = if (dark) Color(0xFF6FA3FA) else Color(0xFF4085F7),
        secondaryText = if (dark) Color(0xFFA9B1C0) else Color(0xFF6E7380),
        tertiaryText = if (dark) Color(0xFF6B7384) else Color(0xFFA3A7B0),
        separator = if (dark) Color(0x33FFFFFF) else Color(0x1F3C3C43),
        isDark = dark,
        style = style,
    )
}

val LightPalette = palette(PowerThemeStyle.CLASSIC, dark = false)
val DarkPalette = palette(PowerThemeStyle.CLASSIC, dark = true)

val LocalPowerPalette = staticCompositionLocalOf { LightPalette }

/** True when the system animator duration scale is 0, which Android uses for "remove animations". */
val LocalReduceMotion = staticCompositionLocalOf { false }

object Power {
    val colors: PowerPalette
        @Composable get() = LocalPowerPalette.current
    val reduceMotion: Boolean
        @Composable get() = LocalReduceMotion.current
}

@Composable
fun HbustPowerTheme(style: PowerThemeStyle = PowerThemeStyle.CLASSIC, content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val palette = remember(style, dark) { palette(style, dark) }
    val colors = if (dark) {
        darkColorScheme(
            primary = palette.accent, onPrimary = Color(0xFF06204A),
            background = palette.background, onBackground = Color(0xFFF2F6FF),
            surface = palette.surface, onSurface = Color(0xFFF2F6FF),
            surfaceVariant = Color(0xFF20344E), onSurfaceVariant = palette.secondaryText,
            surfaceContainer = palette.surface, surfaceContainerHigh = Color(0xFF1B2638),
            secondaryContainer = palette.hero, onSecondaryContainer = palette.accent,
            error = palette.danger,
        )
    } else {
        lightColorScheme(
            primary = palette.accent, onPrimary = Color.White,
            background = palette.background, onBackground = Color(0xFF111318),
            surface = palette.surface, onSurface = Color(0xFF111318),
            surfaceVariant = Color(0xFFE7ECF4), onSurfaceVariant = palette.secondaryText,
            surfaceContainer = palette.surface, surfaceContainerHigh = Color(0xFFF0F3F9),
            secondaryContainer = palette.hero, onSecondaryContainer = palette.accent,
            error = palette.danger,
        )
    }
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? Activity)?.window ?: return@SideEffect
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = !dark
                isAppearanceLightNavigationBars = !dark
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.isNavigationBarContrastEnforced = false
            }
        }
    }
    CompositionLocalProvider(
        LocalPowerPalette provides palette,
        LocalReduceMotion provides rememberReduceMotion(),
    ) {
        MaterialTheme(colorScheme = colors) {
            // Plain Text outside a Surface would otherwise stay black in dark mode.
            CompositionLocalProvider(LocalContentColor provides colors.onBackground, content = content)
        }
    }
}

@Composable
private fun rememberReduceMotion(): Boolean {
    val context = LocalContext.current
    fun read() = runCatching {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }.getOrDefault(false)
    var reduce by remember { mutableStateOf(read()) }
    DisposableEffect(context) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) { reduce = read() }
        }
        context.contentResolver.registerContentObserver(
            Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer,
        )
        onDispose { context.contentResolver.unregisterContentObserver(observer) }
    }
    return reduce
}
