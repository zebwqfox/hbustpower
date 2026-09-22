package com.zebwqfox.hbustpower.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zebwqfox.hbustpower.model.LegalDocuments
import com.zebwqfox.hbustpower.ui.DetailPage
import com.zebwqfox.hbustpower.ui.components.PowerCard
import com.zebwqfox.hbustpower.ui.theme.Power

@Composable
fun LegalScreen(document: LegalDocuments.Document, onBack: () -> Unit) {
    val context = LocalContext.current
    val text = remember(document) { LegalDocuments.text(context, document) }
    DetailPage(document.title, onBack, Icons.AutoMirrored.Filled.ArrowBack) {
        LegalText(text)
    }
}

/** Renders the small Markdown subset the filing documents use: headings, bullets, tables and paragraphs. */
@Composable
fun LegalText(markdown: String, modifier: Modifier = Modifier) {
    val colors = Power.colors
    val blocks = remember(markdown) { parseLegalMarkdown(markdown) }
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        blocks.forEach { block ->
            when (block) {
                is LegalBlock.Title -> Text(
                    block.text, fontSize = 24.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 2.dp).semantics { heading() },
                )
                is LegalBlock.Section -> Text(
                    block.text, fontSize = 18.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 12.dp).semantics { heading() },
                )
                is LegalBlock.Meta -> Text(block.text, color = colors.secondaryText, fontSize = 13.sp)
                is LegalBlock.Paragraph -> Text(block.text, fontSize = 15.sp, lineHeight = 25.sp)
                is LegalBlock.Bullet -> Row {
                    Text("·", color = colors.accent, fontSize = 15.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(block.text, fontSize = 15.sp, lineHeight = 25.sp)
                }
                is LegalBlock.Table -> PowerCard(padding = PaddingValues(14.dp)) {
                    block.rows.forEachIndexed { index, cells ->
                        Text(
                            cells.joinToString("　·　"),
                            fontSize = 14.sp, lineHeight = 22.sp,
                            fontWeight = if (index == 0) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (index == 0) colors.accent else Power.colors.secondaryText,
                            modifier = Modifier.padding(vertical = 3.dp),
                        )
                    }
                }
            }
        }
    }
}

internal sealed interface LegalBlock {
    data class Title(val text: String) : LegalBlock
    data class Section(val text: String) : LegalBlock
    data class Meta(val text: String) : LegalBlock
    data class Paragraph(val text: String) : LegalBlock
    data class Bullet(val text: String) : LegalBlock
    data class Table(val rows: List<List<String>>) : LegalBlock
}

internal fun parseLegalMarkdown(markdown: String): List<LegalBlock> {
    val blocks = mutableListOf<LegalBlock>()
    var table = mutableListOf<List<String>>()
    fun flushTable() {
        if (table.isNotEmpty()) {
            blocks += LegalBlock.Table(table.filterNot { row -> row.all { it.all { char -> char == '-' || char == ':' || char == ' ' } } })
            table = mutableListOf()
        }
    }
    markdown.lineSequence().forEach { raw ->
        val line = raw.trim().replace("**", "").replace("`", "")
        when {
            line.isEmpty() -> flushTable()
            line.startsWith("|") -> table += line.trim('|').split('|').map(String::trim)
            else -> {
                flushTable()
                blocks += when {
                    line.startsWith("## ") -> LegalBlock.Section(line.removePrefix("## "))
                    line.startsWith("# ") -> LegalBlock.Title(line.removePrefix("# "))
                    line.startsWith("- ") -> LegalBlock.Bullet(line.removePrefix("- "))
                    line.startsWith("生效日期") || line.startsWith("版本") -> LegalBlock.Meta(line)
                    else -> LegalBlock.Paragraph(line)
                }
            }
        }
    }
    flushTable()
    return blocks
}
