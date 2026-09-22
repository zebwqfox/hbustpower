package com.zebwqfox.hbustpower.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.BuildConfig
import com.zebwqfox.hbustpower.R
import com.zebwqfox.hbustpower.model.Changelog
import com.zebwqfox.hbustpower.model.DeveloperProfile
import com.zebwqfox.hbustpower.ui.DetailPage
import com.zebwqfox.hbustpower.ui.components.DoodleHeading
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.PowerCard
import com.zebwqfox.hbustpower.ui.components.Squiggle
import com.zebwqfox.hbustpower.ui.components.Sticker
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.components.rememberHaptics
import com.zebwqfox.hbustpower.ui.theme.Power
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

@Composable
fun AboutScreen(onBack: () -> Unit, onOpen: (String) -> Unit) {
    val colors = Power.colors
    val context = LocalContext.current
    DetailPage("关于", onBack, Icons.AutoMirrored.Filled.ArrowBack) {
        AboutHeader()
        Spacer(Modifier.height(18.dp))
        DoodleHeading("开发者的话", seed = 5)
        PaperNote(DeveloperProfile.note, "— ${DeveloperProfile.NAME}")
        Spacer(Modifier.height(18.dp))
        DoodleHeading("最近更新", seed = 9, detail = "轻点展开看看这一版改了什么")
        Column {
            val recent = Changelog.releases.take(3)
            recent.forEachIndexed { index, release ->
                ReleaseRow(release, isLatest = index == 0, isLast = index == recent.lastIndex)
            }
        }
        PowerButton("查看全部 ${Changelog.releases.size} 个版本的更新日志", { onOpen("changelog") }, icon = Icons.AutoMirrored.Filled.List)
        Spacer(Modifier.height(12.dp))
        DeveloperProfile.feedbackUrl?.let { url ->
            PowerButton("给开发者反馈", { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } }, icon = Icons.Filled.Forum, primary = true)
        }
        PowerButton("遇到问题？看看诊断信息", { onOpen("debug") }, icon = Icons.Filled.MedicalServices)
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            TextButton({ onOpen("legal:PRIVACY") }) { Text("《隐私政策》", color = colors.accent, fontSize = 13.sp) }
            TextButton({ onOpen("legal:AGREEMENT") }) { Text("《用户服务协议》", color = colors.accent, fontSize = 13.sp) }
        }
        Spacer(Modifier.height(14.dp))
        // Shown once the filing number is granted; empty by default so nothing is claimed before then.
        val filingNumber = stringResource(R.string.icp_filing_number)
        if (filingNumber.isNotBlank()) {
            Text(
                filingNumber, color = colors.secondaryText, fontSize = 13.sp, textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp),
            )
        }
        Text(
            "${DeveloperProfile.FOOTER}\n版本 ${BuildConfig.VERSION_NAME}（${BuildConfig.VERSION_CODE}）",
            color = colors.tertiaryText, fontSize = 12.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun AboutHeader() {
    val colors = Power.colors
    val haptics = rememberHaptics()
    val reduceMotion = Power.reduceMotion
    val scope = rememberCoroutineScope()
    var taps by rememberSaveable { mutableIntStateOf(0) }
    var burst by remember { mutableIntStateOf(0) }
    val shake = remember { Animatable(0f) }
    fun wiggle() {
        if (reduceMotion) return
        scope.launch {
            shake.snapTo(0f)
            shake.animateTo(0f, keyframes {
                durationMillis = 500
                -10.3f at 100; 8f at 200; -4.6f at 300; 2.3f at 400
            })
        }
    }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.height(112.dp).width(200.dp)) {
            Box(
                Modifier
                    .align(Alignment.TopCenter)
                    .size(104.dp)
                    .graphicsLayer { rotationZ = shake.value }
                    .pressable(
                        onClick = {
                            taps++
                            if (taps == 7) {
                                haptics.success()
                                wiggle()
                                if (!reduceMotion) burst++
                            } else {
                                wiggle()
                            }
                        },
                        onClickLabel = "打个招呼",
                    )
                    .semantics { contentDescription = "${DeveloperProfile.NAME}的头像" },
            ) {
                DoodledRing(Modifier.size(104.dp))
                Image(
                    painterResource(R.drawable.developer_avatar), null, contentScale = ContentScale.Crop,
                    modifier = Modifier.size(104.dp).clip(CircleShape).background(colors.hero),
                )
                BoltBurst(burst, Modifier.align(Alignment.Center))
            }
            Sticker(
                "独立开发", angleRadians = 0.14f,
                modifier = Modifier.align(Alignment.TopCenter).offset(x = 52.dp, y = 76.dp),
            )
        }
        Spacer(Modifier.height(16.dp))
        var nameWidth by remember { mutableIntStateOf(0) }
        Text(DeveloperProfile.NAME, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.onSizeChanged { nameWidth = it.width })
        if (nameWidth > 0) {
            Squiggle(21, Modifier.padding(top = 6.dp).width(with(LocalDensity.current) { (nameWidth * 1.35f).toDp() }))
        }
        Spacer(Modifier.height(8.dp))
        val tagline = if (taps == 0) DeveloperProfile.TAGLINE else DeveloperProfile.replyForTap(taps)
        AnimatedContent(tagline, transitionSpec = { fadeIn(tween(if (reduceMotion) 0 else 200)) togetherWith fadeOut(tween(if (reduceMotion) 0 else 200)) }, label = "tagline") {
            Text(
                it, color = colors.secondaryText, fontSize = 15.sp, textAlign = TextAlign.Center,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
    }
}

/** Two loose, slightly different arcs, like a ring drawn in one quick stroke. */
@Composable
private fun DoodledRing(modifier: Modifier) {
    val accent = Power.colors.accent
    Canvas(modifier) {
        val stroke = 2.5.dp.toPx()
        repeat(2) { turn ->
            val radius = size.width / 2 + 7.dp.toPx() + turn * 2.5.dp.toPx()
            val startDegrees = Math.toDegrees(-0.4 + turn * 2.9).toFloat()
            val center = Offset(size.width / 2 + turn * density, size.height / 2 - turn * density)
            drawArc(
                accent.copy(alpha = 0.45f), startDegrees, Math.toDegrees(Math.PI * 1.55).toFloat(), false,
                topLeft = Offset(center.x - radius, center.y - radius), size = Size(radius * 2, radius * 2),
                style = Stroke(stroke, cap = StrokeCap.Round),
            )
        }
    }
}

/** The easter egg: lightning bolts thrown out of the avatar, falling under gravity. */
@Composable
private fun BoltBurst(trigger: Int, modifier: Modifier) {
    if (trigger == 0) return
    val lighting = Power.colors.lighting
    val painter = rememberVectorPainter(Icons.Filled.Bolt)
    val progress = remember(trigger) { Animatable(0f) }
    val particles = remember(trigger) {
        List(24) {
            val angle = Random.nextDouble(0.0, Math.PI * 2)
            val speed = 220f + Random.nextFloat() * 160f - 80f
            Triple(Offset(cos(angle).toFloat() * speed, sin(angle).toFloat() * speed), Random.nextFloat() * 360f, 0.5f + Random.nextFloat() * 0.8f)
        }
    }
    androidx.compose.runtime.LaunchedEffect(trigger) { progress.animateTo(1f, tween(1300, easing = LinearEasing)) }
    Canvas(modifier.size(1.dp)) {
        val t = progress.value * 1.3f
        if (progress.value >= 1f) return@Canvas
        particles.forEach { (velocity, spin, scale) ->
            val x = velocity.x * t * density
            val y = (velocity.y * t + 130f * t * t) * density
            val alpha = (1f - 0.8f * t).coerceIn(0f, 1f)
            val particleScale = (scale - 0.5f * t).coerceAtLeast(0.1f)
            val w = 22.dp.toPx() * particleScale
            val h = 26.dp.toPx() * particleScale
            translate(x - w / 2, y - h / 2) {
                rotate(spin + 172f * t, Offset(w / 2, h / 2)) {
                    with(painter) { draw(Size(w, h), alpha = alpha, colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(lighting)) }
                }
            }
        }
    }
}

/** A slightly tilted note card with a strip of tape and a dashed edge. */
@Composable
private fun PaperNote(text: String, signature: String) {
    val colors = Power.colors
    val accent = colors.accent
    Box(Modifier.fillMaxWidth().padding(start = 2.dp, end = 2.dp)) {
        Column(
            Modifier
                .padding(top = 10.dp, bottom = 4.dp)
                .fillMaxWidth()
                .graphicsLayer { rotationZ = Math.toDegrees(-0.012).toFloat() }
                .shadow(10.dp, RoundedCornerShape(6.dp), ambientColor = Color.Black.copy(alpha = 0.08f), spotColor = Color.Black.copy(alpha = 0.08f))
                .clip(RoundedCornerShape(6.dp))
                .background(colors.surface)
                .drawBehind {
                    val inset = 7.dp.toPx()
                    drawRoundRect(
                        accent.copy(alpha = 0.22f), Offset(inset, inset), Size(size.width - inset * 2, size.height - inset * 2),
                        CornerRadius(3.dp.toPx()),
                        style = Stroke(1.2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 5.dp.toPx()))),
                    )
                }
                .padding(start = 22.dp, end = 22.dp, top = 26.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(text, fontSize = 17.sp, lineHeight = 28.sp)
            Text(signature, color = accent, fontSize = 16.sp, fontStyle = FontStyle.Italic, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.End, modifier = Modifier.fillMaxWidth())
        }
        Box(
            Modifier
                .align(Alignment.TopCenter)
                .size(84.dp, 22.dp)
                .graphicsLayer { rotationZ = Math.toDegrees(0.06).toFloat() }
                .background(colors.lighting.copy(alpha = 0.28f)),
        )
    }
}

/** One stop on the release timeline; tap to reveal what changed. */
@Composable
private fun ReleaseRow(release: Changelog.Release, isLatest: Boolean, isLast: Boolean) {
    val colors = Power.colors
    val haptics = rememberHaptics()
    var expanded by rememberSaveable(release.version) { mutableStateOf(false) }
    val chevron by animateFloatAsState(if (expanded) 180f else 0f, label = "chevron")
    val detail = (listOf(release.summary) + release.sections.flatMap { it.items }.map { "· $it" }).joinToString("\n")
    Row(
        Modifier
            .fillMaxWidth()
            .pressable(onClick = { expanded = !expanded; haptics.selection() }, onClickLabel = "展开更新内容")
            .semantics(mergeDescendants = true) {
                contentDescription = "版本 ${release.version}，${release.title}" + if (isLatest) "，最新" else ""
                stateDescription = if (expanded) detail else "已收起"
            }
            .drawBehind {
                if (!isLast) {
                    val x = 4.dp.toPx() + 7.dp.toPx()
                    drawLine(colors.accent.copy(alpha = 0.2f), Offset(x, 12.dp.toPx() + 30.dp.toPx()), Offset(x, size.height + 6.dp.toPx()), 2.dp.toPx())
                }
            }
            .padding(vertical = 12.dp),
    ) {
        Box(
            Modifier
                .padding(start = 4.dp, top = 6.dp)
                .size(14.dp)
                .clip(CircleShape)
                .background(colors.accent)
                .padding(2.5.dp)
                .clip(CircleShape)
                .background(if (isLatest) colors.accent else colors.surface),
        )
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f).padding(end = 4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(release.version, color = colors.accent, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(10.dp))
                Text(release.title, fontSize = 17.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f, fill = false))
                if (isLatest) {
                    Spacer(Modifier.width(10.dp))
                    Sticker("NEW", fill = colors.lighting, angleRadians = -0.1f)
                }
                Spacer(Modifier.weight(1f))
                Icon(Icons.Filled.ExpandMore, null, tint = colors.tertiaryText, modifier = Modifier.graphicsLayer { rotationZ = chevron })
            }
            AnimatedVisibility(expanded, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                Text(detail, color = colors.secondaryText, fontSize = 15.sp, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}

@Composable
fun ChangelogScreen(onBack: () -> Unit) {
    val colors = Power.colors
    DetailPage("更新日志", onBack, Icons.AutoMirrored.Filled.ArrowBack) {
        DoodleHeading("每一版都改了什么", seed = 17, detail = "从新到旧，共 ${Changelog.releases.size} 个版本")
        Changelog.releases.forEach { release ->
            PowerCard(padding = PaddingValues(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 20.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(release.version, color = colors.accent, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    if (release.version == BuildConfig.VERSION_NAME) {
                        Spacer(Modifier.width(10.dp))
                        Sticker("当前版本", fill = colors.lighting, angleRadians = -0.08f)
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(release.title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(release.summary, color = colors.secondaryText, fontSize = 15.sp, modifier = Modifier.padding(top = 4.dp))
                release.sections.forEach { section ->
                    val tint = when (section.title) {
                        "新增" -> colors.accent
                        "修复" -> colors.lighting
                        else -> colors.secondaryText
                    }
                    Text(section.title, color = tint, fontSize = 12.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 14.dp, bottom = 6.dp))
                    section.items.forEach { item ->
                        Row(Modifier.padding(vertical = 2.dp)) {
                            Text("•", color = tint, fontSize = 17.sp)
                            Spacer(Modifier.width(8.dp))
                            Text(item, fontSize = 17.sp)
                        }
                    }
                }
            }
        }
    }
}
