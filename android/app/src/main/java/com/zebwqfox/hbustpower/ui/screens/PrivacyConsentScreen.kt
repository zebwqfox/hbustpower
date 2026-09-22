package com.zebwqfox.hbustpower.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.Switch
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.model.LegalDocuments
import com.zebwqfox.hbustpower.ui.PageColumn
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.reveal
import com.zebwqfox.hbustpower.ui.theme.Power

/**
 * Shown before anything else on first launch (and again after the policy changes). Nothing is read from the
 * network and no permission is requested until the user agrees, as China's app filing and personal
 * information rules require.
 *
 * Anonymous usage reporting starts switched on, but it is switched on *here*, in front of the person, with the
 * toggle sitting above the button they are about to press — not silently behind their back. Turning it off
 * before agreeing means no identifier is ever generated and nothing is ever sent.
 */
@Composable
fun PrivacyConsentScreen(
    onAgree: () -> Unit,
    onDecline: () -> Unit,
    onOpenDocument: (LegalDocuments.Document) -> Unit,
    telemetryAvailable: Boolean = false,
    telemetryEnabled: Boolean = true,
    onTelemetryChanged: (Boolean) -> Unit = {},
) {
    val colors = Power.colors
    PageColumn(maxWidth = 480.dp, topPadding = 48.dp, spacing = 18.dp) {
        Column(Modifier.fillMaxWidth().reveal(0), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(72.dp), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Bolt, null, tint = colors.accent, modifier = Modifier.size(64.dp))
            }
            Spacer(Modifier.height(12.dp))
            Text(
                "欢迎使用湖科电量", fontSize = 26.sp, fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() },
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "开始前请阅读《隐私政策》和《用户服务协议》。",
                color = colors.secondaryText, fontSize = 15.sp, textAlign = TextAlign.Center,
            )
        }
        Row(Modifier.fillMaxWidth().reveal(1), horizontalArrangement = Arrangement.Center) {
            TextButton({ onOpenDocument(LegalDocuments.Document.PRIVACY) }) { Text("《隐私政策》", color = colors.accent) }
            TextButton({ onOpenDocument(LegalDocuments.Document.AGREEMENT) }) { Text("《用户服务协议》", color = colors.accent) }
        }
        if (telemetryAvailable) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .reveal(2)
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.surface)
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("帮助改进", fontSize = 15.sp, fontWeight = FontWeight.Medium)
                    Text(
                        "每天最多上报一次应用版本、系统版本和手机型号，用来判断旧版本还有多少人在用。" +
                            "不含账号、宿舍号和电量，也不读取设备识别码。关掉不影响任何功能，之后在设置里也能改。",
                        color = colors.secondaryText, fontSize = 12.sp, lineHeight = 17.sp,
                        modifier = Modifier.padding(top = 3.dp),
                    )
                }
                Spacer(Modifier.width(12.dp))
                Switch(telemetryEnabled, onTelemetryChanged)
            }
        }
        PowerButton("同意并继续", onAgree, primary = true, modifier = Modifier.reveal(3))
        TextButton(onDecline, modifier = Modifier.fillMaxWidth()) {
            Text("不同意并退出", color = colors.secondaryText, fontSize = 15.sp)
        }
    }
}
