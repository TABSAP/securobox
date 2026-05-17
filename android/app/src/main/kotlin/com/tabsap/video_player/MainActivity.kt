package com.tabsap.video_player

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

open class MainActivity: FlutterFragmentActivity() {
    private val channelName = "secure_player/disguise"

    private val disguiseComponents = mapOf(
        "default"    to "MainActivity",
        "calculator" to "CalculatorActivity",
        "notes"      to "NotesActivity",
        "weather"    to "WeatherActivity",
        "compass"    to "CompassActivity",
        "utilities"  to "UtilitiesActivity",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrent" -> result.success(currentDisguise())
                    "set" -> {
                        val key = call.argument<String>("name")
                        if (key == null || !disguiseComponents.containsKey(key)) {
                            result.error("BAD_ARG", "Unknown disguise: $key", null)
                        } else {
                            applyDisguise(key)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun currentDisguise(): String {
        val pm = packageManager
        for ((key, name) in disguiseComponents) {
            val component = ComponentName(packageName, "$packageName.$name")
            if (pm.getComponentEnabledSetting(component) ==
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return key
            }
        }
        return "default"
    }

    private fun applyDisguise(targetKey: String) {
        val pm = packageManager
        for ((key, name) in disguiseComponents) {
            val component = ComponentName(packageName, "$packageName.$name")
            val desired = if (key == targetKey) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            if (pm.getComponentEnabledSetting(component) != desired) {
                pm.setComponentEnabledSetting(component, desired, PackageManager.DONT_KILL_APP)
            }
        }
    }
}

// Disguise launcher entries. Each needs to be a distinct manifest <activity> so
// it can carry its own theme + icon — that is what puts the selected disguise
// icon on the Android launch/splash screen. An <activity-alias> cannot do this
// because it has no android:theme attribute. They inherit MainActivity's Flutter
// engine setup and disguise MethodChannel unchanged.
class CalculatorActivity : MainActivity()
class NotesActivity : MainActivity()
class WeatherActivity : MainActivity()
class CompassActivity : MainActivity()
class UtilitiesActivity : MainActivity()
