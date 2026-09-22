package com.zebwqfox.hbustpower.ui.screens

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.CurrencyYen
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale
import androidx.compose.ui.window.Dialog
import com.zebwqfox.hbustpower.model.RechargeRecord
import com.zebwqfox.hbustpower.model.RechargeSummary
import com.zebwqfox.hbustpower.ui.DetailPage
import com.zebwqfox.hbustpower.ui.LargeTitleHeader
import com.zebwqfox.hbustpower.ui.PageColumn
import com.zebwqfox.hbustpower.ui.PowerStatus
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.RoundIconButton
import com.zebwqfox.hbustpower.ui.components.ChargeRefreshBox
import com.zebwqfox.hbustpower.ui.components.GroupedRow
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.PowerCard
import com.zebwqfox.hbustpower.ui.components.SectionHeading
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.components.rememberHaptics
import com.zebwqfox.hbustpower.ui.theme.Power
import androidx.compose.material.icons.automirrored.filled.ArrowBack

/** Sorted newest first, as the iOS table shows them. */
fun sortedRecords(records: List<RechargeRecord>) = records.sortedByDescending { it.occurredAt }

fun recordSummary(record: RechargeRecord) = "${formatDateTime(record.occurredAt)} ${record.type} ${record.amountText} · ${record.kWhText}"

@Composable
fun RecordsScreen(model: PowerViewModel, onOpenRecord: (Int) -> Unit, onLogin: () -> Unit, onRecharge: () -> Unit) {
    val colors = Power.colors
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val records = remember(model.snapshot) { sortedRecords(model.snapshot?.rechargeRecords.orEmpty()) }
    var preview by remember { mutableStateOf<Int?>(null) }
    val status = model.status

    ChargeRefreshBox(loading = status == PowerStatus.Loading, onRefresh = { haptics.soft(); model.refresh() }, succeeded = { model.status == PowerStatus.Ready }) {
        PageColumn {
            LargeTitleHeader("充值记录") {
                RoundIconButton(Icons.Filled.AddCircle, "充值", {
                    when (status) {
                        PowerStatus.Ready -> { haptics.soft(); onRecharge() }
                        PowerStatus.AuthenticationRequired -> onLogin()
                        else -> Unit
                    }
                }, enabled = status != PowerStatus.Loading)
            }
            if (records.isEmpty()) {
                EmptyRecords(status, onLogin, model::refresh)
            } else {
                RechargeSummaryCard(remember(records) { RechargeSummary.of(records) })
                Text("最近记录", fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 16.dp, top = 8.dp))
                PowerCard(padding = PaddingValues(0.dp)) {
                    records.forEachIndexed { index, record ->
                        if (index > 0) HorizontalDivider(Modifier.padding(start = 60.dp), thickness = 0.5.dp, color = colors.separator)
                        RecordRow(record, onClick = { onOpenRecord(index) }, onLongClick = { preview = index })
                    }
                }
            }
        }
    }

    preview?.let { index ->
        val record = records.getOrNull(index) ?: return@let
        Dialog(onDismissRequest = { preview = null }) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.widthIn(max = 360.dp)) {
                PowerCard(
                    Modifier.pressable(onClick = { preview = null; onOpenRecord(index) }, onClickLabel = "打开记录详情"),
                    padding = PaddingValues(24.dp),
                ) {
                    RecordFields(record)
                }
                PowerCard(padding = PaddingValues(0.dp), shape = RoundedCornerShape(16.dp)) {
                    GroupedRow("复制金额", icon = Icons.Filled.CurrencyYen) { copyText(context, record.amountText); preview = null }
                    HorizontalDivider(thickness = 0.5.dp, color = colors.separator)
                    GroupedRow("复制这条记录", icon = Icons.Filled.ContentCopy) { copyText(context, recordSummary(record)); preview = null }
                    HorizontalDivider(thickness = 0.5.dp, color = colors.separator)
                    GroupedRow("分享", icon = Icons.Filled.Share) {
                        preview = null
                        context.startActivity(
                            Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, recordSummary(record)), "分享记录"),
                        )
                    }
                }
            }
        }
    }
}

/** Totals above the list (iOS 1.8.0): missing fields are skipped rather than counted as zero. */
@Composable
private fun RechargeSummaryCard(summary: RechargeSummary) {
    val colors = Power.colors
    PowerCard(padding = PaddingValues(20.dp)) {
        Text("最近 ${summary.count} 次充值", color = colors.secondaryText, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                summary.totalYuan?.let { String.format(Locale.ROOT, "¥%.2f", it) } ?: "—",
                fontSize = 28.sp, fontWeight = FontWeight.Bold, color = colors.accent,
            )
            Spacer(Modifier.width(12.dp))
            summary.totalKWh?.let {
                Text(String.format(Locale.ROOT, "%.2f 度", it), fontSize = 17.sp, color = colors.secondaryText, modifier = Modifier.padding(bottom = 3.dp))
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            listOfNotNull(
                summary.averageYuan?.let { String.format(Locale.ROOT, "平均每次 ¥%.2f", it) },
                summary.latest?.let { "上次 ${formatDateTime(it)}" },
            ).joinToString("  ·  "),
            color = colors.secondaryText, fontSize = 13.sp,
        )
    }
}

@Composable
private fun RecordRow(record: RechargeRecord, onClick: () -> Unit, onLongClick: () -> Unit) {
    val colors = Power.colors
    val subsidy = record.type.contains("补助")
    val student = record.studentNumber?.let { "，学工号 $it" }.orEmpty()
    Row(
        Modifier
            .fillMaxWidth()
            .pressable(onClick = onClick, onLongClick = onLongClick, onClickLabel = "查看详情")
            .semantics(mergeDescendants = true) {
                contentDescription = "${record.type}，${record.amountText}，${record.kWhText}$student，${record.meterName}，${formatDateTime(record.occurredAt)}"
            }
            .padding(20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(if (subsidy) Icons.Filled.Redeem else Icons.Filled.Bolt, null, tint = colors.accent, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f)) {
            Text("${record.amountText}  ·  ${record.kWhText}", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(record.type, color = colors.secondaryText, fontSize = 15.sp, modifier = Modifier.padding(top = 2.dp))
            Text("${record.meterName} · ${formatDateTime(record.occurredAt)}", color = colors.secondaryText, fontSize = 15.sp)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.tertiaryText)
    }
}

@Composable
private fun RecordFields(record: RechargeRecord) {
    Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
        listOfNotNull(
            "充值类型" to record.type,
            "金额" to record.amountText,
            "电量" to record.kWhText,
            "宿舍" to record.meterName,
            "时间" to formatDateTime(record.occurredAt),
            record.studentNumber?.let { "学工号" to it },
        ).forEach { (title, value) -> SectionHeading(value, detail = title) }
    }
}

@Composable
fun RecordDetailScreen(model: PowerViewModel, index: Int, onBack: () -> Unit) {
    val record = sortedRecords(model.snapshot?.rechargeRecords.orEmpty()).getOrNull(index)
    DetailPage("记录详情", onBack, Icons.AutoMirrored.Filled.ArrowBack) {
        if (record == null) {
            Text("这条记录已不在当前数据中", color = Power.colors.secondaryText)
        } else {
            PowerCard(padding = PaddingValues(24.dp)) { RecordFields(record) }
        }
    }
}

@Composable
private fun EmptyRecords(status: PowerStatus, onLogin: () -> Unit, onRetry: () -> Unit) {
    val colors = Power.colors
    Column(
        Modifier.fillMaxWidth().padding(top = 80.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (status == PowerStatus.Loading) CircularProgressIndicator(color = colors.accent)
        else Icon(Icons.Filled.Inbox, null, tint = colors.tertiaryText, modifier = Modifier.size(44.dp))
        val (title, detail) = when (status) {
            PowerStatus.AuthenticationRequired -> "登录后查看记录" to "连接智慧湖科，查看充值与补助明细。"
            is PowerStatus.Error -> "暂时无法读取记录" to "检查网络后，下拉重试。"
            PowerStatus.Loading -> "正在读取记录" to "请稍候"
            else -> "暂无充值记录" to "充值与补助到账后，会显示在这里。"
        }
        Text(title, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
        Text(detail, color = colors.secondaryText, fontSize = 15.sp, textAlign = TextAlign.Center)
        if (status == PowerStatus.AuthenticationRequired) {
            PowerButton("登录智慧湖科", onLogin, modifier = Modifier.padding(top = 12.dp).widthIn(max = 320.dp))
        }
        if (status is PowerStatus.Error) {
            PowerButton("重试", onRetry, icon = Icons.Filled.Refresh, modifier = Modifier.padding(top = 12.dp).widthIn(max = 320.dp))
        }
    }
}
