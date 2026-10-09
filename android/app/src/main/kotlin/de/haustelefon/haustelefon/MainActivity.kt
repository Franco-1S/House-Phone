package de.haustelefon.haustelefon

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Verbindet Dart mit dem Vordergrund-Dienst und den Anruf-Benachrichtigungen
 * über den Kanal `de.haustelefon/background`.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenFlags(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        applyLockScreenFlags(intent)
    }

    /** Bei eingehendem Anruf über dem Sperrbildschirm anzeigen. */
    private fun applyLockScreenFlags(intent: Intent?) {
        val incoming = intent?.getBooleanExtra(CallNotifications.EXTRA_INCOMING, false) == true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(incoming)
            setTurnScreenOn(incoming)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startKeepAlive" -> {
                        requestNotificationPermission()
                        KeepAliveService.start(
                            this,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("text") ?: "",
                        )
                        result.success(null)
                    }
                    "stopKeepAlive" -> {
                        KeepAliveService.stop(this)
                        result.success(null)
                    }
                    "showIncomingCall" -> {
                        CallNotifications.showIncoming(
                            this,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("caller") ?: "",
                        )
                        result.success(null)
                    }
                    "cancelIncomingCall" -> {
                        CallNotifications.cancelIncoming(this)
                        result.success(null)
                    }
                    "showMissedCall" -> {
                        CallNotifications.showMissed(
                            this,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("caller") ?: "",
                        )
                        result.success(null)
                    }
                    "requestBatteryExemption" -> {
                        requestBatteryExemption()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 42)
        }
    }

    /** Öffnet den System-Dialog "Akku-Optimierung ignorieren". */
    @SuppressLint("BatteryLife")
    private fun requestBatteryExemption() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:$packageName"))
            )
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    companion object {
        private const val CHANNEL = "de.haustelefon/background"
    }
}
