package com.zebwqfox.hbustpower.ui

import android.app.Application
import android.webkit.WebStorage
import android.webkit.WebView
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.zebwqfox.hbustpower.BuildConfig
import com.zebwqfox.hbustpower.auth.ElectricityRedirectValidator
import com.zebwqfox.hbustpower.data.AppSettings
import com.zebwqfox.hbustpower.data.CloudConfig
import com.zebwqfox.hbustpower.data.CloudConfigRepository
import com.zebwqfox.hbustpower.data.CloudConfigState
import com.zebwqfox.hbustpower.data.CloudEndpoints
import com.zebwqfox.hbustpower.data.CloudRefreshTrigger
import com.zebwqfox.hbustpower.data.Diagnostics
import com.zebwqfox.hbustpower.data.ElectricityException
import com.zebwqfox.hbustpower.data.ElectricityService
import com.zebwqfox.hbustpower.data.KeychainAccounts
import com.zebwqfox.hbustpower.data.KeystoreCredentialStore
import com.zebwqfox.hbustpower.data.NetworkException
import com.zebwqfox.hbustpower.data.SchoolEndpoints
import com.zebwqfox.hbustpower.data.TelemetryEndpoint
import com.zebwqfox.hbustpower.data.TelemetryRepository
import com.zebwqfox.hbustpower.data.SessionHttpClient
import com.zebwqfox.hbustpower.data.WebViewCookieBridge
import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import com.zebwqfox.hbustpower.model.FirstRunFlow
import com.zebwqfox.hbustpower.model.LegalDocuments
import com.zebwqfox.hbustpower.model.PowerThemeStyle
import com.zebwqfox.hbustpower.model.FirstRunStore
import com.zebwqfox.hbustpower.notification.AndroidReminderGateway
import com.zebwqfox.hbustpower.notification.DebugNotificationService
import com.zebwqfox.hbustpower.notification.LowBalanceReminder
import com.zebwqfox.hbustpower.notification.PowerNotifications
import com.zebwqfox.hbustpower.notification.PrefsReminderStateStore
import com.zebwqfox.hbustpower.web.WebScripts
import com.zebwqfox.hbustpower.web.WebViewFactory
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

sealed interface PowerStatus {
    data object Idle : PowerStatus
    data object Loading : PowerStatus
    data object Ready : PowerStatus
    data object AuthenticationRequired : PowerStatus
    data class Error(val message: String) : PowerStatus
}

/** Android counterpart of iOS `AppModel`: one refresh at a time, previous snapshot kept on failure. */
class PowerViewModel(application: Application) : AndroidViewModel(application) {
    private val app = application
    val settings = AppSettings(app)
    private val credentials = KeystoreCredentialStore(app)
    val cookies = WebViewCookieBridge()
    private val service = ElectricityService(SessionHttpClient(cookies, { WebViewFactory.userAgent(app) }))
    private val reminder = LowBalanceReminder(AndroidReminderGateway(app), PrefsReminderStateStore(app))
    val debugNotifications = DebugNotificationService(app)
    val scripts = WebScripts(app)
    val campusCard = CampusCardController(this, scripts)
    private val cloud = CloudConfigRepository(settings.prefs, BuildConfig.VERSION_CODE)
    private val telemetry = TelemetryRepository(settings.prefs)

    val firstRun = FirstRunFlow(object : FirstRunStore {
        override fun markCompleted() { settings.firstRunCompleted = true }
        override fun markNotificationDeferred() { settings.notificationPermissionDeferred = true }
    })
    var firstRunCompleted by mutableStateOf(settings.firstRunCompleted); private set

    /** No network request or permission prompt happens before the privacy policy is accepted. */
    var privacyAccepted by mutableStateOf(settings.acceptedConsentVersion >= LegalDocuments.CONSENT_VERSION)
        private set

    var snapshot by mutableStateOf<ElectricitySnapshot?>(null); private set
    var status by mutableStateOf<PowerStatus>(PowerStatus.Idle); private set
    var lowBalanceThreshold by mutableDoubleStateOf(settings.lowBalanceThreshold); private set
    var hasSavedLogin by mutableStateOf(credentials.read(KeychainAccounts.REDIRECT) != null); private set
    var theme by mutableStateOf(PowerThemeStyle.of(settings.themeId)); private set
    var roommates by mutableIntStateOf(settings.roommates); private set
    var lastRefreshResult by mutableStateOf("尚未刷新"); private set
    var lastRefreshDurationMillis by mutableStateOf<Long?>(null); private set

    /** The school entries are built in, exactly as the iOS app ships them. */
    val authUrl: String get() = SchoolEndpoints.AUTH_URL
    val reminderDiagnostic: String get() = reminder.diagnosticStatus
    val isLowBalance: Boolean get() = snapshot?.let { it.purchasedKWh < lowBalanceThreshold } ?: false

    /** Version notice, announcement and feature switches, as last fetched. Empty until the first check. */
    var cloudState by mutableStateOf(CloudConfigState()); private set
    var pendingUpdate by mutableStateOf<CloudConfig.Update?>(null); private set
    var notice by mutableStateOf<CloudConfig.Notice?>(null); private set

    /** False when the build has no config address or the published config hides version-update UI. */
    val isUpdateCheckAvailable: Boolean
        get() = cloud.isConfigured && cloudState.config.isEnabled(CloudConfig.FLAG_UPDATE_CHECK)
    val cloudConfigHost: String? get() = CloudEndpoints.configHost

    /** True when this build is older than the oldest one the school pages still work with. */
    val mustUpgrade: Boolean
        get() = isUpdateCheckAvailable && cloudState.config.mustUpgrade(BuildConfig.VERSION_CODE)

    /**
     * Feature switches fail open, so an unreachable config never takes a feature away. Read from the snapshot
     * state rather than from disk: screens call this while composing, and they have to redraw when it changes.
     */
    fun isFeatureEnabled(flag: String): Boolean = cloudState.config.isEnabled(flag)

    /** Anonymous version/device reporting: on unless switched off, and hidden when not configured. */
    var telemetryEnabled by mutableStateOf(true); private set
    val isTelemetryAvailable: Boolean get() = telemetry.isConfigured
    val telemetryHost: String? get() = TelemetryEndpoint.host
    val telemetryLastSentAt: Long get() = telemetry.lastSentAt

    /** Exactly what a report would contain, so the settings screen can show it instead of describing it. */
    fun telemetryPreview(): List<Pair<String, String>> = telemetry.previewPayload().humanReadable()

    private var started = false
    private var cloudJob: Job? = null
    private var telemetryJob: Job? = null
    private var refreshJob: Job? = null
    private var refreshStartedAt = 0L

    init {
        PowerNotifications.ensureChannels(app)
        // The cached copy only; the first request waits for consent and for start().
        publishCloud(cloud.state())
        telemetryEnabled = telemetry.isEnabled
    }

    fun acceptPrivacy() {
        settings.acceptedConsentVersion = LegalDocuments.CONSENT_VERSION
        privacyAccepted = true
        Diagnostics.record("已同意隐私政策（版本 ${LegalDocuments.CONSENT_VERSION}）")
    }

    fun completeFirstRun() {
        firstRunCompleted = true
        start()
    }

    fun start() {
        if (started || !firstRunCompleted || !privacyAccepted) return
        started = true
        refresh()
        checkForUpdates(CloudRefreshTrigger.LAUNCH)
        reportUsage()
    }

    /** Foreground return: iOS refreshes on `sceneWillEnterForeground`. */
    fun onForeground() {
        if (!started) return
        refresh()
        checkForUpdates(CloudRefreshTrigger.FOREGROUND)
        reportUsage()
    }

    /**
     * Sends the anonymous version/device report, at most once a day and only when the user has switched it on.
     * Failures are silent: this exists for the developer's benefit, never the user's, so it must not interrupt
     * anything or be worth retrying aggressively.
     */
    fun reportUsage(force: Boolean = false) {
        if (!privacyAccepted || !telemetry.shouldSend(force)) return
        if (telemetryJob?.isActive == true) return
        telemetryJob = viewModelScope.launch {
            val sent = withContext(Dispatchers.IO) { telemetry.report(force) }
            if (sent) Diagnostics.record("已发送匿名使用统计")
        }
    }

    /** The consent screen's toggle and the settings switch both land here. */
    fun updateTelemetryEnabled(enabled: Boolean) {
        telemetry.isEnabled = enabled
        telemetryEnabled = telemetry.isEnabled
        Diagnostics.record(if (enabled) "已开启匿名使用统计" else "已关闭匿名使用统计，并清除本机安装标识")
        // Not from the consent screen: nothing may go out before the policy is accepted.
        if (enabled && privacyAccepted) reportUsage(force = true)
    }

    /** Gives this install a new random identifier; the old one can no longer be linked to this device. */
    fun resetTelemetryId() {
        telemetry.resetInstallId()
        Diagnostics.record("已重置匿名安装标识")
    }

    /**
     * Reads the version/notice file from the developer's own site. A launch always checks; foreground checks are
     * throttled to 30 minutes; a manual check always asks and reports what went wrong. Nothing is sent: it is a
     * plain GET with no cookies and only a timestamp cache-busting parameter; it never runs before the privacy
     * policy is accepted.
     */
    fun checkForUpdates(trigger: CloudRefreshTrigger) {
        if (!privacyAccepted || !cloud.isConfigured) return
        if (cloudJob?.isActive == true) return
        if (!cloud.shouldCheck(trigger)) {
            if (trigger == CloudRefreshTrigger.MANUAL) publishCloud(cloud.state())
            return
        }
        cloudState = cloudState.copy(isChecking = true, error = null)
        cloudJob = viewModelScope.launch {
            val result = withContext(Dispatchers.IO) { cloud.refresh(trigger) }
            publishCloud(result)
            Diagnostics.record(
                "检查更新：" + (result.error ?: cloud.pendingUpdate(result.config)?.let { "发现 ${it.versionName}" } ?: "已是最新"),
            )
        }
    }

    /** Stops offering this particular version; a later one, or a required upgrade, still shows. */
    fun skipUpdate() {
        pendingUpdate?.let { cloud.skip(it) }
        pendingUpdate = cloud.pendingUpdate(cloudState.config)
    }

    fun dismissNotice() {
        notice?.let { cloud.dismissNotice(it) }
        notice = cloud.activeNotice(cloudState.config)
    }

    private fun publishCloud(state: CloudConfigState) {
        cloudState = state.copy(isChecking = false)
        pendingUpdate = cloud.pendingUpdate(state.config)
        notice = cloud.activeNotice(state.config)
    }

    fun refresh() {
        if (!firstRunCompleted) return
        if (status == PowerStatus.Loading) return
        beginRefresh()
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            try {
                val value = try {
                    if (!hasSavedLogin && cookies.count(listOf(SchoolEndpoints.HOME_URL)) == 0) {
                        throw ElectricityException.AuthenticationRequired()
                    }
                    service.fetchCurrentSession()
                } catch (error: ElectricityException.AuthenticationRequired) {
                    Diagnostics.record("当前会话失效，尝试恢复本机登录")
                    recoverSavedSession()
                }
                apply(value)
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: ElectricityException.AuthenticationRequired) {
                finishRefresh("需要登录")
                status = PowerStatus.AuthenticationRequired
            } catch (error: ElectricityException.InvalidRedirect) {
                finishRefresh("授权已失效")
                status = PowerStatus.AuthenticationRequired
            } catch (error: Exception) {
                finishRefresh(Diagnostics.errorSummary(error))
                status = PowerStatus.Error(if (error is ElectricityException || error is NetworkException) error.message.orEmpty() else "学校系统暂时无法连接")
            }
        }
    }

    fun completeAuthentication(redirectUrl: String) {
        if (!ElectricityRedirectValidator.isValid(redirectUrl)) return
        beginRefresh()
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            try {
                cookies.flush()
                if (!credentials.save(KeychainAccounts.REDIRECT, redirectUrl)) Diagnostics.record("授权未能写入本机安全存储")
                hasSavedLogin = credentials.read(KeychainAccounts.REDIRECT) != null
                apply(service.establishSession(redirectUrl))
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: Exception) {
                finishRefresh(Diagnostics.errorSummary(error))
                status = PowerStatus.Error(if (error is ElectricityException || error is NetworkException) error.message.orEmpty() else "学校系统暂时无法连接")
            }
        }
    }

    fun clearLogin() {
        refreshJob?.cancel()
        Diagnostics.record("已清除本机登录")
        reminder.reset()
        credentials.delete(KeychainAccounts.REDIRECT)
        hasSavedLogin = false
        cookies.clearAll()
        WebStorage.getInstance().deleteAllData()
        campusCard.reset(destroyPage = true)
        settings.saveSummary(null, null, null)
        snapshot = null
        status = PowerStatus.AuthenticationRequired
    }

    fun selectTheme(style: PowerThemeStyle) {
        if (style == theme) return
        settings.themeId = style.id
        theme = style
        Diagnostics.record("已切换主题：${style.displayName}")
    }

    fun updateRoommates(value: Int) {
        settings.roommates = value
        roommates = settings.roommates
    }

    fun updateThreshold(value: Double) {
        if (!value.isFinite() || value <= 0) return
        settings.lowBalanceThreshold = value
        lowBalanceThreshold = value
        snapshot?.let { current ->
            viewModelScope.launch { reminder.evaluate(current.purchasedKWh, value, current.room) }
        }
    }

    /**
     * Debug builds only: runs the real reminder path (permission check, dedup, reset) with a made-up reading.
     * The displayed snapshot and the saved summary are left alone, so it never fakes school data.
     */
    fun simulateLowBalanceCheck(balance: Double, onResult: (String) -> Unit) {
        if (!BuildConfig.DEBUG) return
        viewModelScope.launch {
            Diagnostics.record(String.format(Locale.ROOT, "模拟电量检查：%.2f 度", balance))
            reminder.evaluate(balance, lowBalanceThreshold, "测试宿舍")
            onResult(reminder.diagnosticStatus)
        }
    }

    fun newAuthWebView(): WebView = WebViewFactory.create(app, detachable = true)

    private suspend fun recoverSavedSession(): ElectricitySnapshot {
        val saved = credentials.read(KeychainAccounts.REDIRECT) ?: throw ElectricityException.AuthenticationRequired()
        return service.establishSession(saved)
    }

    private fun beginRefresh() {
        refreshStartedAt = System.currentTimeMillis()
        lastRefreshResult = "正在刷新"
        status = PowerStatus.Loading
        Diagnostics.record("开始读取电量")
    }

    private fun finishRefresh(result: String) {
        lastRefreshDurationMillis = refreshStartedAt.takeIf { it > 0 }?.let { System.currentTimeMillis() - it }
        refreshStartedAt = 0
        lastRefreshResult = result
        Diagnostics.record("读取电量：$result")
    }

    private fun apply(value: ElectricitySnapshot) {
        finishRefresh("成功")
        snapshot = value
        status = PowerStatus.Ready
        settings.saveSummary(value.room, value.purchasedKWh, value.fetchedAt.toEpochMilli())
        val threshold = lowBalanceThreshold
        viewModelScope.launch { reminder.evaluate(value.purchasedKWh, threshold, value.room) }
    }

    override fun onCleared() {
        campusCard.reset(destroyPage = true)
        super.onCleared()
    }
}
