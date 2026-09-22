package com.zebwqfox.hbustpower.data

import com.zebwqfox.hbustpower.auth.ElectricityRedirectValidator
import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import java.io.IOException
import java.time.Instant

sealed class ElectricityException(message: String) : Exception(message) {
    class AuthenticationRequired : ElectricityException("登录状态已失效")
    class InvalidRedirect : ElectricityException("没有取得有效的电费授权")
    class InvalidResponse : ElectricityException("学校系统暂时无法连接")
    class ParseFailed : ElectricityException("没有找到宿舍电量数据")
}

/**
 * Mirrors iOS `ElectricityService`: home first, then usage and records in parallel; any failure fails the whole
 * refresh so the caller keeps its previous snapshot.
 */
class ElectricityService(
    private val http: HttpFetcher,
    private val parser: ElectricityHtmlParser = ElectricityHtmlParser(),
    private val clock: () -> Instant = Instant::now,
    private val io: CoroutineDispatcher = Dispatchers.IO,
) {
    suspend fun establishSession(redirectUrl: String): ElectricitySnapshot {
        if (!ElectricityRedirectValidator.isValid(redirectUrl)) throw ElectricityException.InvalidRedirect()
        val response = fetch(redirectUrl)
        validate(response)
        return fetchDashboard()
    }

    suspend fun fetchCurrentSession(): ElectricitySnapshot = fetchDashboard()

    private suspend fun fetchDashboard(): ElectricitySnapshot = coroutineScope {
        val home = fetchHtml(SchoolEndpoints.HOME_URL)
        val purchased = parser.purchasedKWh(home) ?: run {
            if (parser.isLoginPlaceholder(home)) throw ElectricityException.AuthenticationRequired()
            throw ElectricityException.ParseFailed()
        }
        val usage = async { fetchHtml(SchoolEndpoints.USAGE_URL) }
        val records = async { fetchHtml(SchoolEndpoints.RECORDS_URL) }
        val usageHtml = usage.await()
        val recordsHtml = records.await()
        ElectricitySnapshot(
            room = parser.room(home),
            purchasedKWh = purchased,
            subsidyKWh = parser.subsidyKWh(home),
            unitPrice = parser.unitPrice(home),
            meters = parser.meters(home),
            usageRecords = parser.usageRecords(usageHtml),
            rechargeRecords = parser.rechargeRecords(recordsHtml),
            fetchedAt = clock(),
        )
    }

    private suspend fun fetchHtml(url: String): String {
        val response = fetch(url)
        validate(response)
        return HtmlDecoding.decode(response.body) ?: throw ElectricityException.InvalidResponse()
    }

    private suspend fun fetch(url: String): HttpResult = withContext(io) {
        try {
            http.get(url)
        } catch (error: IOException) {
            throw NetworkException(error)
        }
    }

    private fun validate(response: HttpResult) {
        if (response.statusCode == 401 || response.statusCode == 403) throw ElectricityException.AuthenticationRequired()
        if (response.statusCode !in 200..399) throw ElectricityException.InvalidResponse()
        if (parser.isLoginPage(response.finalUrl, HtmlDecoding.decode(response.body).orEmpty())) {
            throw ElectricityException.AuthenticationRequired()
        }
    }
}

/** A transport failure; the message never includes the URL, which may carry an authorisation token. */
class NetworkException(cause: IOException) : Exception("网络连接失败，请检查网络后重试", cause)
