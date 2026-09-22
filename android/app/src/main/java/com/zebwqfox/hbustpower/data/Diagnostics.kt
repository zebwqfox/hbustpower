package com.zebwqfox.hbustpower.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.time.LocalTime
import java.time.format.DateTimeFormatter

/** An in-memory, bounded log of explicit events; never stores URLs, tokens, accounts or cookie values. */
object Diagnostics {
    private val formatter = DateTimeFormatter.ofPattern("HH:mm:ss")
    private val mutableEvents = MutableStateFlow<List<String>>(emptyList())
    val events: StateFlow<List<String>> = mutableEvents.asStateFlow()

    fun record(message: String) {
        val line = LocalTime.now().format(formatter) + "  " + message
        mutableEvents.update { (it + line).takeLast(60) }
    }

    fun errorSummary(error: Throwable): String = when (error) {
        is ElectricityException -> error.message.orEmpty()
        is NetworkException -> "网络连接失败"
        // Do not export messages of other exceptions, which may contain an authenticated URL.
        else -> "错误类型 ${error.javaClass.simpleName}（系统）"
    }
}
