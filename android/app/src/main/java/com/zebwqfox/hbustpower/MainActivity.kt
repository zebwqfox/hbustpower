package com.zebwqfox.hbustpower

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.ViewModelProvider
import com.zebwqfox.hbustpower.ui.PowerViewModel
import com.zebwqfox.hbustpower.ui.HbustPowerApp
import com.zebwqfox.hbustpower.ui.theme.HbustPowerTheme

class MainActivity : ComponentActivity() {
    private val model by lazy { ViewModelProvider(this)[PowerViewModel::class.java] }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { HbustPowerTheme(model.theme) { HbustPowerApp(model) } }
    }
}
