package app.familyshopper.mobile

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * The screen of the app. The app itself (its Dart code, the connections to the family's phones, the
 * checks that raise notifications) lives in an engine that belongs to the process, not to this
 * screen: closing the screen, or swiping the app away from the recent apps, leaves it running for as
 * long as the foreground service keeps the process alive. Opening the screen again just shows it.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? = engine(context.applicationContext)

    // The engine outlives this screen
    override fun shouldDestroyEngineWithHost(): Boolean = false

    companion object {
        private const val ENGINE_ID = "familyshopper_main"

        /** The app's engine: made once, the first time the screen opens, and kept. */
        fun engine(app: Context): FlutterEngine {
            val cache = FlutterEngineCache.getInstance()
            cache.get(ENGINE_ID)?.let { return it }

            // (plugins are registered here, once: not by the engine itself, which would do it a second time)
            val engine = FlutterEngine(app, null, false)
            GeneratedPluginRegistrant.registerWith(engine)
            registerChannels(engine, app)
            registerSound(engine, app)
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())

            cache.put(ENGINE_ID, engine)
            return engine
        }

        // The sound of a banner inside the app (a phone notification brings its own): `res/raw/sound_<kind>.wav`,
        // played as a notification sound, so it follows the phone's notification volume and silent mode
        private fun registerSound(engine: FlutterEngine, app: Context) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "app.familyshopper.mobile/sound").setMethodCallHandler { call, result ->
                if (call.method != "play") return@setMethodCallHandler result.notImplemented()

                val id = app.resources.getIdentifier("sound_" + call.argument<String>("sound"), "raw", app.packageName)
                if (id == 0) return@setMethodCallHandler result.success(false)

                try {
                    val attributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    val player = MediaPlayer.create(app, id, attributes, AudioManager.AUDIO_SESSION_ID_GENERATE)
                    player.setOnCompletionListener { it.release() }
                    player.start()
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
        }

        // The app asks for the notification that keeps it alive in the background (or to drop it)
        private fun registerChannels(engine: FlutterEngine, app: Context) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "app.familyshopper.mobile/family_link").setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val intent = Intent(app, FamilyLinkService::class.java)
                            .putExtra(FamilyLinkService.EXTRA_TITLE, call.argument<String>("title"))
                            .putExtra(FamilyLinkService.EXTRA_TEXT, call.argument<String>("text"))
                            .putExtra(FamilyLinkService.EXTRA_CLOSE, call.argument<String>("close"))

                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) app.startForegroundService(intent) else app.startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false) // not allowed right now (the app is not in a state to start it)
                        }
                    }
                    "update" -> {
                        FamilyLinkService.instance?.refresh(call.argument<String>("title") ?: "Family Shopper", call.argument<String>("text") ?: "", call.argument<String>("close"))
                        result.success(FamilyLinkService.instance != null)
                    }
                    "stop" -> {
                        app.stopService(Intent(app, FamilyLinkService::class.java))
                        result.success(true)
                    }
                    // Is the app allowed to go on running in the background (not stopped to save battery)?
                    "batteryExempt" -> {
                        val power = app.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(app.packageName))
                    }
                    "askBatteryExemption" -> {
                        try {
                            app.startActivity(
                                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                    .setData(Uri.parse("package:${app.packageName}"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            // some phones have no such screen: the app's own settings page instead
                            try {
                                app.startActivity(
                                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                        .setData(Uri.parse("package:${app.packageName}"))
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                                )
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
}
