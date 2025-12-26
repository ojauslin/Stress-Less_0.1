package com.example.nullpunkt_01

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.nullpunkt/app_blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    startMonitoringService(blockedApps)
                    result.success(true)
                }
                "stopMonitoring" -> {
                    stopMonitoringService()
                    result.success(true)
                }
                "requestUsagePermission" -> {
                    requestUsageStatsPermission()
                    result.success(true)
                }
                "hasUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startMonitoringService(blockedApps: List<String>) {
        val intent = Intent(this, AppMonitorService::class.java).apply {
            action = AppMonitorService.ACTION_UPDATE_BLOCKED_APPS
            putStringArrayListExtra(AppMonitorService.EXTRA_BLOCKED_APPS, ArrayList(blockedApps))
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMonitoringService() {
        val intent = Intent(this, AppMonitorService::class.java)
        stopService(intent)
    }

    private fun requestUsageStatsPermission() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                startActivity(intent)
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
