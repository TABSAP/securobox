package app.securobox.vault

import android.content.ComponentName
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File

open class MainActivity: FlutterFragmentActivity() {
    private val channelName = "secure_player/disguise"
    private val mediaStoreChannel = "secure_player/media_store"
    private val restoreTag = "SecuroBoxRestore"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaStoreChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType")
                            ?: "application/octet-stream"
                        if (path.isNullOrEmpty() || fileName.isNullOrEmpty()) {
                            Log.e(restoreTag, "saveToDownloads: bad args path=$path name=$fileName")
                            result.success(null)
                        } else {
                            // Null on failure; {uri, bytes} on verified success.
                            result.success(saveToDownloads(path, fileName, mimeType))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Copies a file into the public Downloads collection.
     *
     * On Android 10+ scoped storage forbids writing to shared storage with the
     * File API, so we insert through MediaStore — which also indexes the file
     * so it is immediately visible in the Files app. On older releases we fall
     * back to a direct copy, which WRITE_EXTERNAL_STORAGE still permits there.
     *
     * Returns null unless the bytes are verifiably written.
     */
    private fun saveToDownloads(
        path: String,
        fileName: String,
        mimeType: String,
    ): Map<String, Any>? {
        return try {
            val source = File(path)
            Log.i(
                restoreTag,
                "saveToDownloads: src=$path exists=${source.exists()} " +
                    "size=${if (source.exists()) source.length() else -1} " +
                    "name=$fileName mime=$mimeType sdk=${Build.VERSION.SDK_INT}"
            )
            if (!source.exists()) {
                Log.e(restoreTag, "saveToDownloads: source missing")
                return null
            }
            val sourceSize = source.length()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    // Hide the row until the bytes are fully written.
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }

                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (uri == null) {
                    Log.e(restoreTag, "saveToDownloads: MediaStore insert returned null uri")
                    return null
                }
                Log.i(restoreTag, "saveToDownloads: inserted uri=$uri")

                var written = 0L
                try {
                    val output = resolver.openOutputStream(uri)
                    if (output == null) {
                        Log.e(restoreTag, "saveToDownloads: openOutputStream null, deleting row")
                        resolver.delete(uri, null, null)
                        return null
                    }
                    output.use { out ->
                        source.inputStream().use { input -> written = input.copyTo(out) }
                        out.flush()
                    }
                } catch (e: Exception) {
                    Log.e(restoreTag, "saveToDownloads: write failed, deleting row", e)
                    resolver.delete(uri, null, null)
                    return null
                }

                if (written != sourceSize) {
                    Log.e(restoreTag, "saveToDownloads: byte mismatch $written != $sourceSize")
                    resolver.delete(uri, null, null)
                    return null
                }

                // Publish: clears IS_PENDING so the row is visible to other apps.
                val done = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
                resolver.update(uri, done, null, null)
                Log.i(restoreTag, "saveToDownloads: published uri=$uri bytes=$written")
                mapOf("uri" to uri.toString(), "bytes" to written)
            } else {
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                if (!dir.exists()) dir.mkdirs()
                var target = File(dir, fileName)
                var index = 1
                val dot = fileName.lastIndexOf('.')
                val base = if (dot > 0) fileName.substring(0, dot) else fileName
                val ext = if (dot > 0) fileName.substring(dot) else ""
                while (target.exists()) {
                    target = File(dir, "$base ($index)$ext")
                    index++
                }
                source.copyTo(target, overwrite = false)
                val ok = target.exists() && target.length() == sourceSize
                Log.i(restoreTag, "saveToDownloads(legacy): target=${target.absolutePath} ok=$ok")
                if (!ok) null else mapOf("uri" to target.absolutePath, "bytes" to target.length())
            }
        } catch (e: Exception) {
            Log.e(restoreTag, "saveToDownloads: unexpected failure", e)
            null
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
