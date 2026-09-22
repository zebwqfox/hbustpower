package com.zebwqfox.hbustpower.ui.screens

import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.CheckBoxOutlineBlank
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PhoneIphone
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.zebwqfox.hbustpower.R
import com.zebwqfox.hbustpower.auth.ElectricityRedirectValidator
import com.zebwqfox.hbustpower.data.Diagnostics
import com.zebwqfox.hbustpower.data.SchoolEndpoints
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.RoundIconButton
import com.zebwqfox.hbustpower.ui.components.PowerButton
import com.zebwqfox.hbustpower.ui.components.pressable
import com.zebwqfox.hbustpower.ui.theme.Power
import com.zebwqfox.hbustpower.web.WebViewFactory
import com.zebwqfox.hbustpower.web.evaluate
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Port of iOS `AuthenticationViewController`. The official HTTPS page stays responsible for encryption,
 * captcha and second-factor checks; the native form only fills the exact official fields after the user agrees.
 * The password lives only in this composition and is cleared on submit and on leave.
 */
@Composable
fun LoginScreen(
    model: PowerViewModel,
    campus: Boolean,
    onClose: () -> Unit,
) {
    val colors = Power.colors
    val loginAccent = colors.loginAccent
    val context = LocalContext.current
    val focus = LocalFocusManager.current
    val scope = rememberCoroutineScope()
    val close by rememberUpdatedState(onClose)
    val authUrl = model.authUrl

    val page = remember { model.newAuthWebView() }
    var account by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var agreed by remember { mutableStateOf(false) }
    var formReady by remember { mutableStateOf(false) }
    var submitting by remember { mutableStateOf(false) }
    var completed by remember { mutableStateOf(false) }
    var adopted by remember { mutableStateOf(false) }
    var showingWeb by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var stage by remember { mutableIntStateOf(0) }
    var retryVisible by remember { mutableStateOf(false) }
    var alternativeTitle by remember { mutableStateOf("打开学习通官方页面") }
    val jobs = remember { mutableMapOf<String, Job>() }

    fun startTimeout() {
        jobs["timeout"]?.cancel()
        jobs["timeout"] = scope.launch {
            delay(20_000)
            if (completed) return@launch
            submitting = false
            status = "连接耗时较长，请检查网络后重试。"
            retryVisible = true
        }
    }

    fun loadLogin() {
        formReady = false
        submitting = false
        status = ""
        retryVisible = false
        alternativeTitle = "打开学习通官方页面"
        page.loadUrl(authUrl)
        startTimeout()
    }

    /** Back to the native 学习通 form from the official page. */
    fun returnToNativeLogin() {
        showingWeb = false
        loadLogin()
    }

    fun retryCurrentProvider() {
        loadLogin()
    }

    fun showOfficialPage() {
        showingWeb = true
        jobs["monitor"]?.cancel()
        focus.clearFocus()
    }

    fun complete(redirect: String) {
        if (completed) return
        completed = true
        jobs.values.forEach(Job::cancel)
        password = ""
        stage = 2
        Diagnostics.record("登录授权已取得，正在读取电量")
        model.completeAuthentication(redirect)
        close()
    }

    DisposableEffect(page) {
        page.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val url = request.url.toString()
                if (!campus && request.isForMainFrame && ElectricityRedirectValidator.isValid(url)) {
                    complete(url)
                    return true
                }
                return !SchoolEndpoints.isAllowedNavigation(url)
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                if (!campus && url != null && ElectricityRedirectValidator.isValid(url)) {
                    view.stopLoading()
                    complete(url)
                }
            }

            override fun onPageFinished(view: WebView, url: String?) {
                if (completed) return
                when {
                    SchoolEndpoints.isLoginForm(url) -> scope.launch {
                        if (!SchoolEndpoints.isLoginForm(page.url)) return@launch
                        formReady = page.evaluate(model.scripts.formReady) == true
                        status = if (formReady) "" else "可通过其他登录方式继续官方验证。"
                        jobs["timeout"]?.cancel()
                    }
                    SchoolEndpoints.isCampusPortal(url) -> {
                        stage = 1
                        if (campus) {
                            // Hand over this very page: its sessionStorage belongs to it.
                            completed = true
                            adopted = true
                            jobs.values.forEach(Job::cancel)
                            password = ""
                            WebViewFactory.detach(page)
                            model.campusCard.adoptPortal(page)
                            close()
                            return
                        }
                        showingWeb = false
                        alternativeTitle = "打开校园卡页面"
                        status = ""
                        submitting = true
                        formReady = false
                        Diagnostics.record("已到达一卡通，等待宿舍电费入口")
                        view.evaluateJavascript(model.scripts.portal, null)
                        startTimeout()
                    }
                    SchoolEndpoints.isOfficialAuthHost(url) -> showOfficialPage()
                }
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (!request.isForMainFrame || completed) return
                jobs["timeout"]?.cancel()
                submitting = false
                status = "连接未成功，请检查网络后重试。"
                retryVisible = true
                Diagnostics.record("登录连接失败：错误代码 ${error.errorCode}（网络）")
            }
        }
        loadLogin()
        onDispose {
            jobs.values.forEach(Job::cancel)
            password = ""
            if (!adopted) {
                WebViewFactory.detach(page)
                page.stopLoading()
                page.destroy()
            }
        }
    }

    fun submit() {
        val canSubmit = formReady && agreed && !submitting && account.isNotBlank() && password.isNotEmpty()
        if (!canSubmit || !SchoolEndpoints.isLoginForm(page.url)) return
        submitting = true
        status = ""
        focus.clearFocus()
        val script = model.scripts.submit(account.trim(), password, agreed)
        password = ""
        scope.launch {
            val submitted = page.evaluate(script) == true
            if (completed) return@launch
            if (submitted) {
                jobs["monitor"]?.cancel()
                jobs["monitor"] = scope.launch {
                    repeat(40) {
                        delay(500)
                        if (completed || showingWeb) return@launch
                        if (!SchoolEndpoints.isLoginForm(page.url)) return@repeat
                        val message = page.evaluate(model.scripts.loginError) as? String
                        if (!message.isNullOrEmpty()) {
                            status = message
                            submitting = false
                            jobs["timeout"]?.cancel()
                            return@launch
                        }
                    }
                }
            } else {
                submitting = false
                status = "当前登录方式需要在官方页面继续。"
                showOfficialPage()
            }
        }
        startTimeout()
    }

    BackHandler {
        when {
            showingWeb && page.canGoBack() && !SchoolEndpoints.isLoginForm(page.url) -> page.goBack()
            showingWeb -> returnToNativeLogin()
            else -> close()
        }
    }

    LoginShell(
        title = when {
            showingWeb -> "超星官方验证"
            else -> "连接校园服务"
        },
        onClose = {
            completed = true
            page.stopLoading()
            close()
        },
        trailing = {
            when {
                showingWeb -> TextButton({ showingWeb = false; loadLogin() }) { Text("返回", color = loginAccent) }
                retryVisible -> TextButton(::retryCurrentProvider) { Text("重试", color = loginAccent) }
            }
        },
    ) {
        Box(Modifier.fillMaxSize()) {
            if (!showingWeb) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .imePadding()
                        .padding(horizontal = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Column(Modifier.widthIn(max = 380.dp).fillMaxWidth().padding(top = 32.dp, bottom = 24.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Image(painterResource(R.drawable.xuexitong_logo), "学习通 Logo", Modifier.size(52.dp).clip(RoundedCornerShape(12.dp)))
                            Spacer(Modifier.width(12.dp))
                            Text("学习通", fontSize = 20.sp, fontWeight = FontWeight.Medium)
                        }
                        Spacer(Modifier.height(30.dp))
                        FlowStages(stage, campus)
                        Spacer(Modifier.height(16.dp))
                        Text(
                            if (campus) "使用学习通完成验证。验证通过后，即可查看校园卡余额。"
                            else "使用学习通完成验证。验证通过后，即可查看已绑定宿舍的电量。",
                            color = colors.secondaryText, fontSize = 13.sp,
                        )
                        Spacer(Modifier.height(24.dp))
                        GlassFields(
                            account = account, onAccount = { account = it },
                            password = password, onPassword = { password = it },
                            accent = loginAccent, onGo = ::submit,
                        )
                        Spacer(Modifier.height(26.dp))
                        val enabled = formReady && agreed && !submitting && account.isNotBlank() && password.isNotEmpty()
                        PowerButton(
                            "登录并连接", ::submit, primary = enabled || submitting, enabled = enabled,
                            loading = submitting, accent = loginAccent,
                        )
                        Spacer(Modifier.height(16.dp))
                        PowerButton(alternativeTitle, ::showOfficialPage, icon = Icons.Filled.AccountCircle, accent = loginAccent)
                        Spacer(Modifier.height(26.dp))
                        Row(
                            Modifier
                                .align(Alignment.CenterHorizontally)
                                .heightIn(min = 44.dp)
                                .pressable(onClick = { agreed = !agreed }, pressedScale = 0.97f)
                                .semantics(mergeDescendants = true) { stateDescription = if (agreed) "已同意" else "未同意" }
                                .padding(horizontal = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(if (agreed) Icons.Filled.CheckBox else Icons.Filled.CheckBoxOutlineBlank, null, tint = loginAccent, modifier = Modifier.size(20.dp))
                            Spacer(Modifier.width(7.dp))
                            Text("我已阅读并同意以下条款", color = loginAccent, fontSize = 13.sp)
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                            listOf("《隐私政策》" to SchoolEndpoints.PRIVACY_POLICY_URL, "《用户协议》" to SchoolEndpoints.USER_AGREEMENT_URL).forEach { (label, url) ->
                                TextButton({ runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } }) {
                                    Text(label, color = loginAccent, fontSize = 13.sp)
                                }
                            }
                        }
                        Text(
                            status, color = colors.secondaryText, fontSize = 13.sp, textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth().semantics { liveRegion = LiveRegionMode.Polite },
                        )
                    }
                }
            }
            AndroidView(
                factory = { WebViewFactory.attach(page, it) },
                modifier = if (showingWeb) Modifier.fillMaxSize() else Modifier.size(1.dp),
                onRelease = { if (!adopted) WebViewFactory.detach(it) },
            )
        }
    }
}

@Composable
private fun LoginShell(
    title: String,
    onClose: () -> Unit,
    trailing: @Composable () -> Unit = {},
    content: @Composable () -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(Power.colors.background)
            .windowInsetsPadding(WindowInsets.safeDrawing),
    ) {
        Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
            Box(Modifier.align(Alignment.CenterStart)) { RoundIconButton(Icons.Filled.Close, "取消", onClose, tint = Power.colors.loginAccent) }
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.align(Alignment.Center))
            Box(Modifier.align(Alignment.CenterEnd)) { trailing() }
        }
        Box(Modifier.weight(1f)) { content() }
    }
}

@Composable
private fun FlowStages(stage: Int, campus: Boolean) {
    val colors = Power.colors
    val stages = listOf(
        Triple(Icons.Filled.AccountCircle, "身份验证", 0),
        Triple(Icons.Outlined.CreditCard, "校园卡授权", 1),
        Triple(if (campus) Icons.Filled.CreditCard else Icons.Filled.Bolt, if (campus) "查看余额" else "查看电量", 2),
    )
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) { contentDescription = "登录进度：第 ${stage + 1} 步，共 3 步" }) {
        stages.forEach { (icon, label, position) ->
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                StageIcon(if (position < stage) Icons.Filled.CheckCircle else icon, if (position <= stage) colors.loginAccent else colors.tertiaryText)
                Text(label, fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun StageIcon(icon: ImageVector, tint: Color) = Icon(icon, null, tint = tint, modifier = Modifier.size(26.dp))

@Composable
private fun GlassFields(
    account: String,
    onAccount: (String) -> Unit,
    password: String,
    onPassword: (String) -> Unit,
    accent: Color,
    onGo: () -> Unit,
) {
    val colors = Power.colors
    val focus = LocalFocusManager.current
    val shape = RoundedCornerShape(28.dp)
    val fieldColors = TextFieldDefaults.colors(
        focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent,
        focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
        cursorColor = accent,
    )
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(if (colors.isDark) 0.dp else 10.dp, shape, ambientColor = Color.Black.copy(alpha = 0.06f), spotColor = Color.Black.copy(alpha = 0.08f))
            .clip(shape)
            .background(colors.surface.copy(alpha = if (colors.isDark) 0.7f else 0.9f))
            .border(0.8.dp, Color.White.copy(alpha = if (colors.isDark) 0.08f else 0.9f), shape)
            .padding(6.dp),
    ) {
        TextField(
            account, onAccount, singleLine = true, colors = fieldColors,
            placeholder = { Text("手机号 / 超星号") },
            leadingIcon = { Icon(Icons.Filled.PhoneIphone, null, tint = accent.copy(alpha = 0.8f), modifier = Modifier.size(18.dp)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii, imeAction = ImeAction.Next, autoCorrectEnabled = false),
            keyboardActions = KeyboardActions(onNext = { focus.moveFocus(androidx.compose.ui.focus.FocusDirection.Down) }),
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentType = ContentType.Username },
        )
        HorizontalDivider(Modifier.padding(horizontal = 8.dp), thickness = 0.5.dp, color = colors.separator)
        TextField(
            password, onPassword, singleLine = true, colors = fieldColors,
            placeholder = { Text("学习通密码") },
            leadingIcon = { Icon(Icons.Filled.Lock, null, tint = accent.copy(alpha = 0.8f), modifier = Modifier.size(18.dp)) },
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Go, autoCorrectEnabled = false),
            keyboardActions = KeyboardActions(onGo = { onGo() }),
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentType = ContentType.Password },
        )
    }
}
