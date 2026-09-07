package com.example.fidokeeper

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var host: FidoHost? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // 必须在 Activity.super.onCreate 之后绑定，避免系统尚未允许注册广播。
        if (host == null) {
            host = FidoHost.bind(this)
        }
        super.configureFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        runCatching { host?.enableNfc() }
    }

    override fun onPause() {
        runCatching { host?.disableNfc() }
        super.onPause()
    }

    override fun onDestroy() {
        host?.release()
        super.onDestroy()
    }
}
