package com.zebwqfox.hbustpower.auth

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

object ElectricityRedirectValidator {
    fun isValid(rawUrl: String): Boolean = runCatching {
        val uri = URI(rawUrl)
        if (uri.scheme !in setOf("http", "https")) return false
        if (!uri.host.equals("ecard.hbust.edu.cn", ignoreCase = true)) return false
        if (uri.path != "/berserker-base/redirect") return false
        val parameters = parseQuery(uri.rawQuery ?: return false)
        val appIds = parameters["appId"].orEmpty()
        val tokens = parameters["synjones-auth"].orEmpty()
        appIds.size == 1 && appIds.single() == "180" &&
            tokens.size == 1 && tokens.single().isNotBlank()
    }.getOrDefault(false)

    private fun parseQuery(query: String): Map<String, List<String>> = query
        .split('&')
        .filter(String::isNotBlank)
        .map { part ->
            val pieces = part.split('=', limit = 2)
            decode(pieces[0]) to decode(pieces.getOrElse(1) { "" })
        }
        .groupBy({ it.first }, { it.second })

    private fun decode(value: String): String =
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())
}
