package com.example.nullpunkt_01

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class AppMonitorService : Service() {

    companion object {
        const val ACTION_UPDATE_BLOCKED_APPS = "UPDATE_BLOCKED_APPS"
        const val EXTRA_BLOCKED_APPS = "BLOCKED_APPS"
        private const val CHANNEL_ID = "app_blocker_channel"
        private const val NOTIFICATION_ID = 1
        private const val CHECK_INTERVAL = 500L // Check every 0.5 seconds (faster)
        private const val TAG = "AppMonitorService"
    }

    private var blockedApps = mutableSetOf<String>()
    private val handler = Handler(Looper.getMainLooper())
    private var isMonitoring = false

    private val monitoringRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            if (isMonitoring) {
                handler.postDelayed(this, CHECK_INTERVAL)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE_BLOCKED_APPS -> {
                val apps = intent.getStringArrayListExtra(EXTRA_BLOCKED_APPS)
                if (apps != null) {
                    blockedApps.clear()
                    blockedApps.addAll(apps)
                    Log.d(TAG, "Updated blocked apps: $blockedApps")

                    if (blockedApps.isNotEmpty() && !isMonitoring) {
                        startForeground(NOTIFICATION_ID, createNotification())
                        startMonitoring()
                        Log.d(TAG, "Started monitoring")
                    } else if (blockedApps.isEmpty()) {
                        stopMonitoring()
                        stopSelf()
                        Log.d(TAG, "Stopped monitoring - no blocked apps")
                    }
                }
            }
        }
        return START_STICKY
    }

    private fun startMonitoring() {
        isMonitoring = true
        handler.post(monitoringRunnable)
    }

    private fun stopMonitoring() {
        isMonitoring = false
        handler.removeCallbacks(monitoringRunnable)
    }

    private fun checkForegroundApp() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val currentTime = System.currentTimeMillis()

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            currentTime - 1000 * 60, // Last 60 seconds
            currentTime
        )

        if (stats != null && stats.isNotEmpty()) {
            val sortedStats = stats.sortedByDescending { it.lastTimeUsed }
            val currentApp = sortedStats.firstOrNull()?.packageName

            Log.d(TAG, "Current foreground app: $currentApp")
            Log.d(TAG, "Blocked apps: $blockedApps")

            if (currentApp != null && blockedApps.contains(currentApp)) {
                Log.d(TAG, "BLOCKING APP: $currentApp")
                showBlockScreen()
            }
        } else {
            Log.d(TAG, "No usage stats available")
        }
    }

    private fun showBlockScreen() {
        val intent = Intent(this, BlockScreenActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors blocked apps"
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("NullPunkt Active")
            .setContentText("Monitoring ${blockedApps.size} blocked apps")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        Log.d(TAG, "Service destroyed")
    }
}
