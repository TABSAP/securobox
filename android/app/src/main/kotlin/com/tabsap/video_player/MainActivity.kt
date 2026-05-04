package com.tabsap.video_player

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterFragmentActivity() {
    private val channelName = "secure_player/disguise"

    private val aliasMap = mapOf(
        "default"    to "DefaultAlias",
        "calculator" to "CalculatorAlias",
        "notes"      to "NotesAlias",
        "weather"    to "WeatherAlias",
        "compass"    to "CompassAlias",
        "utilities"  to "UtilitiesAlias",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrent" -> result.success(currentAlias())
                    "set" -> {
                        val key = call.argument<String>("name")
                        if (key == null || !aliasMap.containsKey(key)) {
                            result.error("BAD_ARG", "Unknown disguise: $key", null)
                        } else {
                            applyAlias(key)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun currentAlias(): String {
        val pm = packageManager
        for ((key, suffix) in aliasMap) {
            val component = ComponentName(packageName, "$packageName.$suffix")
            val state = pm.getComponentEnabledSetting(component)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return key
            }
        }
        return "default"
    }

    private fun applyAlias(targetKey: String) {
        val pm = packageManager
        for ((key, suffix) in aliasMap) {
            val component = ComponentName(packageName, "$packageName.$suffix")
            val desired = if (key == targetKey) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            val current = pm.getComponentEnabledSetting(component)
            if (current != desired) {
                pm.setComponentEnabledSetting(
                    component,
                    desired,
                    PackageManager.DONT_KILL_APP,
                )
            }
        }
    }
}
