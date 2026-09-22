package com.zebwqfox.hbustpower.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.ui.theme.Power

/** An inset grouped section: header, rounded card of rows with hairline separators, optional footer. */
@Composable
fun GroupedSection(
    title: String?,
    footer: String? = null,
    modifier: Modifier = Modifier,
    rows: List<@Composable () -> Unit>,
) {
    val colors = Power.colors
    Column(modifier.fillMaxWidth()) {
        title?.let {
            Text(
                it, color = colors.secondaryText, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(start = 16.dp, bottom = 7.dp).semantics { heading() },
            )
        }
        PowerCard(padding = PaddingValues(0.dp)) {
            rows.forEachIndexed { index, row ->
                if (index > 0) HorizontalDivider(Modifier.padding(start = 16.dp), thickness = 0.5.dp, color = colors.separator)
                row()
            }
        }
        footer?.let {
            Text(it, color = colors.secondaryText, fontSize = 13.sp, modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 7.dp))
        }
    }
}

@Composable
fun GroupedRow(
    title: String,
    detail: String? = null,
    icon: ImageVector? = null,
    tint: Color = Power.colors.accent,
    titleColor: Color = Color.Unspecified,
    stacked: Boolean = false,
    disclosure: Boolean = false,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    val colors = Power.colors
    val clickable = if (onClick != null) Modifier.clickable(enabled = enabled, role = Role.Button, onClick = onClick) else Modifier
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).then(clickable).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon?.let {
            Icon(it, null, tint = tint, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(14.dp))
        }
        if (stacked) {
            Column(Modifier.weight(1f)) {
                Text(title, fontSize = 17.sp, color = if (onClick != null && titleColor == Color.Unspecified) colors.accent else titleColor)
                detail?.let { Text(it, color = colors.secondaryText, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp)) }
            }
        } else {
            Text(title, fontSize = 17.sp, color = titleColor, modifier = Modifier.weight(1f))
            detail?.let { Text(it, color = colors.secondaryText, fontSize = 15.sp, modifier = Modifier.padding(start = 12.dp)) }
        }
        if (disclosure || (stacked && onClick != null)) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.tertiaryText, modifier = Modifier.padding(start = 6.dp))
        }
    }
}
