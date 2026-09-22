package com.zebwqfox.hbustpower.web

import android.content.Context
import android.webkit.WebView
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONObject
import org.json.JSONTokener
import kotlin.coroutines.resume

/**
 * The iOS page scripts live verbatim in `assets/scripts`. iOS passes account and password as
 * `callAsyncJavaScript` arguments; Android's `evaluateJavascript` has no arguments, so values are JSON string
 * literals (never raw concatenation) bound as locals of a wrapping function. No JavaScript bridge is exposed.
 */
class WebScripts(context: Context) {
    private val assets = context.applicationContext.assets
    private fun load(name: String) = assets.open("scripts/$name").bufferedReader().use { it.readText() }

    val formReady by lazy { load("form_ready.js") }
    val loginError by lazy { load("login_error.js") }
    val portal by lazy { load("portal.js") }
    val campusReady by lazy { load("campus_ready.js") }
    private val submitBody by lazy { load("login_submit_body.js") }
    private val campusReadBody by lazy { load("campus_read_body.js") }

    fun submit(account: String, password: String, agreed: Boolean): String = buildSubmit(submitBody, account, password, agreed)

    /** Starts the async read; the outcome lands in `window.__powerCampus` for [campusResult] to poll. */
    val campusReadStart: String get() = buildAsyncCapture(campusReadBody, RESULT_SLOT)

    val campusResult = "JSON.stringify(window.$RESULT_SLOT ?? null)"

    companion object {
        const val RESULT_SLOT = "__powerCampus"

        fun buildSubmit(body: String, account: String, password: String, agreed: Boolean): String =
            "(function(account, password, agreed) {\n$body\n})(${JSONObject.quote(account)}, ${JSONObject.quote(password)}, $agreed);"

        fun buildAsyncCapture(body: String, slot: String): String = """
            (() => {
              window.$slot = null;
              (async () => {
            $body
              })().then(
                value => { window.$slot = { ok: true, value: value }; },
                error => { window.$slot = { ok: false, error: String((error && error.message) || error) }; }
              );
              return true;
            })();
        """.trimIndent()

        /** evaluateJavascript hands back the JSON encoding of the result. */
        fun decodeResult(raw: String?): Any? = raw?.let { runCatching { JSONTokener(it).nextValue() }.getOrNull() }
            ?.takeUnless { it == JSONObject.NULL }
    }
}

suspend fun WebView.evaluate(script: String): Any? = suspendCancellableCoroutine { continuation ->
    evaluateJavascript(script) { raw -> if (continuation.isActive) continuation.resume(WebScripts.decodeResult(raw)) }
}
