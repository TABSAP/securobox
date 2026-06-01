package app.securobox.vault

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

// `open` so the disguise launcher entries (CalculatorActivity, NotesActivity,
// …) can subclass it — each is a real <activity> in the manifest with its own
// icon/label/theme but identical Flutter behaviour.
open class MainActivity: FlutterFragmentActivity() {
    private val channelName = "secure_player/disguise"

    // Maps a disguise key to its launcher component's class name. These MUST
    // match the <activity> entries declared in AndroidManifest.xml — each is a
    // real activity (a thin MainActivity subclass) so it can carry its own
    // icon/label/theme. Only one is ever enabled at a time.
    private val aliasMap = mapOf(
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
        val targetSuffix = aliasMap[targetKey] ?: return
        // Enable the target launcher FIRST, then disable the others — so there
        // is never a moment where every launcher entry is disabled (which would
        // make the app icon vanish and leave the user unable to reopen it).
        setComponentEnabled(pm, targetSuffix, true)
        for ((key, suffix) in aliasMap) {
            if (key == targetKey) continue
            setComponentEnabled(pm, suffix, false)
        }
    }

    private fun setComponentEnabled(
        pm: PackageManager,
        suffix: String,
        enabled: Boolean,
    ) {
        val component = ComponentName(packageName, "$packageName.$suffix")
        val desired = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        if (pm.getComponentEnabledSetting(component) != desired) {
            pm.setComponentEnabledSetting(
                component,
                desired,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
