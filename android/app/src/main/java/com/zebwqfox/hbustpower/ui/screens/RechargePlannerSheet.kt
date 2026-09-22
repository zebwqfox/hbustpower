package com.zebwqfox.hbustpower.ui.screens

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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import com.zebwqfox.hbustpower.model.RechargePlanner
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.PowerCard
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.theme.Power
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

private val beijing: ZoneId = RechargePlanner.BEIJING

/**
 * "算算充多少" (iOS 1.8.0). Everything is computed locally from the latest snapshot; the app never charges
 * anything itself, so the sheet only tells the user what to pay on the school's own page.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RechargePlannerSheet(snapshot: ElectricitySnapshot, roommates: Int, onRoommates: (Int) -> Unit, onDismiss: () -> Unit) {
    val colors = Power.colors
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val planner = remember(snapshot) { RechargePlanner.from(snapshot) }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState, containerColor = colors.background) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(start = 24.dp, end = 24.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("算算充多少", fontSize = 24.sp, fontWeight = FontWeight.Bold)
            if (planner == null) {
                Text(
                    "还算不了：需要学校返回电价，并且照明和空调都有用量记录。刷新拿到完整数据后再试。",
                    color = colors.secondaryText, fontSize = 15.sp,
                )
                PowerButton("知道了", onDismiss)
                return@Column
            }
            Text(
                String.format(
                    Locale.ROOT, "当前剩余 %.2f 度 · 电价 %.2f 元/度 · 近期日均 %.2f 度",
                    planner.balanceKWh, planner.unitPrice, planner.dailyKWh,
                ),
                color = colors.secondaryText, fontSize = 13.sp,
            )

            var tab by rememberSaveable { mutableIntStateOf(0) }
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(colors.surface).padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                listOf("按金额", "按日期").forEachIndexed { index, title ->
                    val selected = tab == index
                    Box(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(11.dp))
                            .background(if (selected) colors.hero else colors.surface)
                            .pressable(onClick = { tab = index }, pressedScale = 0.98f)
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(title, color = if (selected) colors.accent else colors.secondaryText, fontWeight = FontWeight.SemiBold)
                    }
                }
            }

            var amountText by rememberSaveable { mutableStateOf("100") }
            var target by rememberSaveable { mutableStateOf(LocalDate.now(beijing).plusDays(30).toEpochDay()) }
            var picking by remember { mutableStateOf(false) }
            val amount = amountText.toDoubleOrNull()?.takeIf { it.isFinite() && it >= 0 }
            val amountPlan = amount?.let { planner.plan(it) }
            val datePlan = planner.plan(LocalDate.ofEpochDay(target))
            val payable = if (tab == 0) amount ?: 0.0 else datePlan.amount.toDouble()

            if (tab == 0) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    RechargePlanner.presetAmounts.forEach { preset ->
                        val selected = amount == preset
                        Box(
                            Modifier
                                .weight(1f)
                                .clip(CircleShape)
                                .background(if (selected) colors.accent else colors.surface)
                                .border(0.8.dp, colors.separator, CircleShape)
                                .pressable(onClick = { amountText = preset.toInt().toString() }, pressedScale = 0.96f)
                                .padding(vertical = 10.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                "¥${preset.toInt()}",
                                color = if (selected) (if (colors.isDark) colors.background else androidx.compose.ui.graphics.Color.White) else colors.accent,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
                OutlinedTextField(
                    amountText, { amountText = it.filter { char -> char.isDigit() || char == '.' } },
                    label = { Text("自定义金额（元）") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                )
                PowerCard(padding = PaddingValues(20.dp)) {
                    if (amountPlan == null) {
                        Text("输入一个金额", color = colors.secondaryText)
                    } else {
                        Text(String.format(Locale.ROOT, "可充 %.1f 度", amountPlan.addedKWh), fontSize = 24.sp, fontWeight = FontWeight.Bold, color = colors.accent)
                        Spacer(Modifier.height(6.dp))
                        Text(
                            String.format(Locale.ROOT, "加上现有电量，约可用 %.1f 天", amountPlan.totalDays),
                            fontSize = 15.sp,
                        )
                        Text(
                            "大约用到 " + formatDay(amountPlan.lastsUntil),
                            color = colors.secondaryText, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            } else {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(colors.surface)
                        .pressable(onClick = { picking = true }, pressedScale = 0.99f)
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.CalendarMonth, null, tint = colors.accent)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("要用到哪天", color = colors.secondaryText, fontSize = 13.sp)
                        Text(LocalDate.ofEpochDay(target).let { "${it.year}年${it.monthValue}月${it.dayOfMonth}日" }, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    }
                    Text("更改", color = colors.accent, fontSize = 15.sp)
                }
                PowerCard(padding = PaddingValues(20.dp)) {
                    if (datePlan.amount == 0) {
                        Text("现有电量够用到那天", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = colors.good)
                        Spacer(Modifier.height(6.dp))
                        Text("按近期用量估算，这段时间不用再充。", color = colors.secondaryText, fontSize = 13.sp)
                    } else {
                        Text("至少充 ¥${datePlan.amount}", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = colors.accent)
                        Spacer(Modifier.height(6.dp))
                        Text(String.format(Locale.ROOT, "还需要约 %.1f 度，覆盖 %d 天", datePlan.neededKWh, datePlan.days), fontSize = 15.sp)
                    }
                }
            }

            // Roommate split.
            PowerCard(padding = PaddingValues(20.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Group, null, tint = colors.accent, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("室友分摊", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    StepperButton(Icons.Filled.Remove, "减少人数") { onRoommates((roommates - 1).coerceAtLeast(1)) }
                    Text("$roommates 人", Modifier.padding(horizontal = 12.dp), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    StepperButton(Icons.Filled.Add, "增加人数") { onRoommates((roommates + 1).coerceAtMost(12)) }
                }
                Spacer(Modifier.height(12.dp))
                val each = RechargePlanner.share(payable, roommates)
                Text(
                    if (payable <= 0) "先选一个金额或日期" else String.format(Locale.ROOT, "每人 ¥%.2f", each),
                    fontSize = 20.sp, fontWeight = FontWeight.Bold,
                )
                if (payable > 0) {
                    Spacer(Modifier.height(10.dp))
                    PowerButton(
                        "复制分摊说明",
                        {
                            copyText(
                                context,
                                String.format(
                                    Locale.ROOT, "宿舍电费充值 ¥%.0f，%d 人分摊，每人 ¥%.2f。", payable, roommates, each,
                                ),
                            )
                        },
                        icon = Icons.Filled.ContentCopy,
                    )
                }
            }
            Text(
                "以上都是按最近有记录日的平均用量估算，仅供参考；充值仍需在学校官方页面完成。",
                color = colors.tertiaryText, fontSize = 12.sp,
            )

            if (picking) {
                val state = rememberDatePickerState(
                    initialSelectedDateMillis = LocalDate.ofEpochDay(target).atStartOfDay(ZoneId.of("UTC")).toInstant().toEpochMilli(),
                    selectableDates = object : SelectableDates {
                        override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                            utcTimeMillis >= LocalDate.now(beijing).atStartOfDay(ZoneId.of("UTC")).toInstant().toEpochMilli()
                    },
                )
                DatePickerDialog(
                    onDismissRequest = { picking = false },
                    confirmButton = {
                        TextButton({
                            state.selectedDateMillis?.let { target = Instant.ofEpochMilli(it).atZone(ZoneId.of("UTC")).toLocalDate().toEpochDay() }
                            picking = false
                        }) { Text("好") }
                    },
                    dismissButton = { TextButton({ picking = false }) { Text("取消") } },
                ) { DatePicker(state) }
            }
        }
    }
}

@Composable
private fun StepperButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit) {
    val colors = Power.colors
    Box(
        Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(colors.hero)
            .pressable(onClick = onClick, pressedScale = 0.9f, onClickLabel = label),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, label, tint = colors.accent, modifier = Modifier.size(18.dp))
    }
}

private fun formatDay(instant: Instant): String = instant.atZone(beijing).toLocalDate().let { "${it.monthValue}月${it.dayOfMonth}日" }
