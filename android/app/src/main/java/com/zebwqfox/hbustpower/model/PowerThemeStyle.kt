package com.zebwqfox.hbustpower.model

/**
 * Colour schemes (iOS 1.9.0 `PowerThemeStyle`). The two extra ones are modelled on friends' fursuits:
 * 紫鸟紫 (black fur, violet markings, amber eyes) and 枫烻黄 (grey fur, yellow markings, red collar with a bell).
 * Colours are stored as 0xAARRGGBB so this stays free of Compose types and can be unit tested.
 */
enum class PowerThemeStyle(
    val id: String,
    val displayName: String,
    val tagline: String,
    /** Where the colours come from; null for the app's own scheme. */
    val credit: String?,
    val greeting: String,
    /** An extra line the pull-to-charge indicator may show in this theme. */
    val chargingLine: String,
    val light: Palette,
    val dark: Palette,
) {
    CLASSIC(
        id = "classic",
        displayName = "湖科蓝",
        tagline = "云白配清蓝，App 原本的样子",
        credit = null,
        greeting = "⚡ 电力满满",
        chargingLine = "电流正在赶来…",
        light = Palette(0xFFF6F9FE, 0xFFFFFFFF, 0xFF1F57C2, 0xFFDBECFF, 0xFFAB6621, 0xFFFFA80D),
        dark = Palette(0xFF0A0F1A, 0xFF141C2B, 0xFF85B8FF, 0xFF16294A, 0xFFF0BA66, 0xFFFFCC4D),
    ),
    PURPLE_BIRD(
        id = "purpleBird",
        displayName = "紫鸟紫",
        tagline = "夜色里的紫与琥珀色的眼睛",
        credit = "配色来自朋友「紫鸟紫」",
        greeting = "🌙 夜里也在偷偷发电",
        chargingLine = "夜色里悄悄充电…",
        light = Palette(0xFFF9F7FE, 0xFFFFFFFF, 0xFF5C2EC7, 0xFFE6DEFC, 0xFFC7730D, 0xFF8C4DF2),
        dark = Palette(0xFF0E0B16, 0xFF1D182A, 0xFFB89BFF, 0xFF291F4D, 0xFFFFC259, 0xFFCCA8FF),
    ),
    MAPLE_YELLOW(
        id = "mapleYellow",
        displayName = "枫烻黄",
        tagline = "灰黄配色，脖子上挂着金铃铛",
        credit = "配色来自朋友「枫烻黄」",
        greeting = "🔔 叮——铃铛响了一下",
        chargingLine = "铃铛一响，电就来了…",
        light = Palette(0xFFFEFBF5, 0xFFFFFFFF, 0xFF996B05, 0xFFFFF0C7, 0xFFB82921, 0xFFF2B30D),
        dark = Palette(0xFF131108, 0xFF252117, 0xFFFFD147, 0xFF382E12, 0xFFFF806B, 0xFFFFD94D),
    ),
    ;

    /** One appearance of a theme; only the colours that actually change between themes live here. */
    data class Palette(
        val background: Long,
        val surface: Long,
        val accent: Long,
        /** The balance card's tint. */
        val hero: Long,
        /** The warm secondary: lighting figures, low-balance warnings and stickers. */
        val secondary: Long,
        /** Sparks and the charging ring; always bright enough to read as "electric". */
        val spark: Long,
    )

    companion object {
        val default = CLASSIC
        fun of(id: String?): PowerThemeStyle = entries.firstOrNull { it.id == id } ?: default
    }
}

/**
 * Lines from Tagore's *Stray Birds* (1916) in 郑振铎's 1922 Chinese translation; both are out of copyright.
 * Shown once per launch in the 紫鸟紫 theme, always with the attribution.
 */
object StrayBirds {
    const val ATTRIBUTION = "摘自《飞鸟集》· 泰戈尔"

    val lines = listOf(
        "夏天的飞鸟，飞到我的窗前唱歌，又飞去了。",
        "世界上的一队小小的漂泊者呀，请留下你们的足印在我的文字里。",
        "如果你因失去了太阳而流泪，那么你也将失去群星了。",
        "我今晨坐在窗前，世界如一个路人似的，停留了一会，向我点点头又走过去了。",
        "休息与工作的关系，正如眼睑与眼睛的关系。",
        "瀑布歌唱道：我得到自由时便有了歌声了。",
        "我的心把她的波浪在世界的海岸上冲激着，以热泪在上边写着她的题记：我爱你。",
        "群星不怕显得像萤火那样。",
        "使生如夏花之绚烂，死如秋叶之静美。",
        "这寡独的黄昏，幕着雾与雨，我在我的心的孤寂里，感觉到它的叹息。",
        "我们把世界看错了，反说它欺骗我们。",
        "夜秘密地把花开放了，却让白日去领受谢词。",
        "小草呀，你的足步虽小，但是你拥有你足下的土地。",
        "错误经不起失败，但是真理却不怕失败。",
        "只管走过去，不必逗留着采了花朵来保存，因为一路上花朵自会继续开放的。",
    )

    /** One line per launch, so the home screen greets you with something new each time you open the app. */
    val ofThisLaunch: String by lazy { lines.random() }

    /** Used when the reader taps for another one. */
    fun after(current: String): String {
        val index = lines.indexOf(current)
        return if (index < 0) ofThisLaunch else lines[(index + 1) % lines.size]
    }
}
