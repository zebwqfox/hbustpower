package com.zebwqfox.hbustpower.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import androidx.core.content.FileProvider
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

fun copyText(context: Context, text: String) {
    context.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("湖科电量", text))
}
private val beijing = ZoneId.of("Asia/Shanghai")

/** "21:17", school time. */
fun formatTime(value: Instant): String = DateTimeFormatter.ofPattern("HH:mm", Locale.ROOT).withZone(beijing).format(value)

/** "2026年9月17日 21:17", school time. */
fun formatDateTime(value: Instant): String = DateTimeFormatter.ofPattern("yyyy年M月d日 HH:mm", Locale.ROOT).withZone(beijing).format(value)

/** "9月17日". */
fun formatMonthDay(value: java.time.LocalDate): String = "${value.monthValue}月${value.dayOfMonth}日"

/** Port of iOS `ShareCardRenderer`: drawn directly (glass effects cannot be captured), always in light colours. */
object ShareCard {
    fun render(room: String, balance: Double, forecast: String, isLow: Boolean): Bitmap {
        val width = 900f
        val height = 600f
        val bitmap = Bitmap.createBitmap(900, 600, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val accent = Color.rgb(31, 87, 194)
        val tint = if (isLow) Color.rgb(171, 102, 33) else accent
        canvas.drawColor(Color.rgb(219, 236, 255))
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val level = height * 0.52f
        val liquid = Path().apply {
            moveTo(0f, height)
            var x = 0f
            while (x <= width) {
                lineTo(x, level + 14f * kotlin.math.sin(x / width * Math.PI * 2.4).toFloat())
                x += 10f
            }
            lineTo(width, height)
            close()
        }
        paint.color = tint
        paint.alpha = (0.13f * 255).toInt()
        canvas.drawPath(liquid, paint)
        val (start, curves) = com.zebwqfox.hbustpower.ui.components.HandDrawn.squiggle(260.0, 14.0, 42)
        val doodle = Path().apply {
            moveTo(start.x.toFloat() + 64f, start.y.toFloat() + 138f)
            curves.forEach {
                quadTo(it.control.x.toFloat() + 64f, it.control.y.toFloat() + 138f, it.end.x.toFloat() + 64f, it.end.y.toFloat() + 138f)
            }
        }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = 5f; strokeCap = Paint.Cap.ROUND; color = accent; alpha = 128
        }
        canvas.drawPath(doodle, stroke)
        fun draw(text: String, size: Float, weight: Int, color: Int, alpha: Int, x: Float, top: Float): Float {
            paint.textSize = size
            paint.typeface = if (android.os.Build.VERSION.SDK_INT >= 28) {
                android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, weight, false)
            } else if (weight >= 600) android.graphics.Typeface.DEFAULT_BOLD else android.graphics.Typeface.DEFAULT
            paint.color = color
            paint.alpha = alpha
            canvas.drawText(text, x, top - paint.fontMetrics.ascent, paint)
            return paint.measureText(text)
        }
        draw(room, 44f, 600, accent, 255, 64f, 70f)
        val value = String.format(Locale.ROOT, "%.2f", balance)
        val valueWidth = draw(value, 150f, 500, accent, 255, 56f, 170f)
        draw("度", 48f, 400, accent, 255, 64f + valueWidth, 262f)
        draw(forecast, 38f, 500, tint, 255, 64f, 370f)
        draw("⚡ 湖科电量", 30f, 600, accent, 178, 64f, 510f)
        return bitmap
    }

    fun share(context: Context, room: String, balance: Double, forecast: String, isLow: Boolean) {
        val bitmap = render(room, balance, forecast, isLow)
        val directory = File(context.cacheDir, "share").apply { mkdirs() }
        val file = File(directory, "power-${System.nanoTime()}.png")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = "image/png"; putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri("电量卡片", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, "分享电量卡片"))
    }
}
