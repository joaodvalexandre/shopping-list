package app.cestou.mobile

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The app asks for the notification that keeps it alive in the background (or to drop it)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.cestou.mobile/family_link").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, FamilyLinkService::class.java)
                        .putExtra(FamilyLinkService.EXTRA_TITLE, call.argument<String>("title"))
                        .putExtra(FamilyLinkService.EXTRA_TEXT, call.argument<String>("text"))

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false) // not allowed right now (the app is not in a state to start it)
                    }
                }
                "update" -> {
                    FamilyLinkService.instance?.refresh(call.argument<String>("title") ?: "Cestou", call.argument<String>("text") ?: "")
                    result.success(FamilyLinkService.instance != null)
                }
                "stop" -> {
                    stopService(Intent(this, FamilyLinkService::class.java))
                    result.success(true)
                }
                // Is the app allowed to go on running in the background (not stopped to save battery)?
                "batteryExempt" -> {
                    val power = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(power.isIgnoringBatteryOptimizations(packageName))
                }
                "askBatteryExemption" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                .setData(Uri.parse("package:$packageName")),
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        // some phones have no such screen: the app's own settings page instead
                        try {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(Uri.parse("package:$packageName")))
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
