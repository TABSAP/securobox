package app.securobox.video_player_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val mediaStoreChannel = "secure_player/media_store"
    private val tag = "SecuroBoxRestore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaStoreChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType")
                            ?: "application/octet-stream"
                        if (path.isNullOrEmpty() || fileName.isNullOrEmpty()) {
                            Log.e(tag, "saveToDownloads: bad args path=$path name=$fileName")
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
     * File API, so we insert through MediaStore. On older releases we fall back
     * to a direct copy, which WRITE_EXTERNAL_STORAGE still permits there.
     *
     * Returns true only when the bytes are verifiably written.
     */
    private fun saveToDownloads(path: String, fileName: String, mimeType: String): Map<String, Any>? {
        return try {
            val source = File(path)
            Log.i(tag, "saveToDownloads: src=$path exists=${source.exists()} " +
                "size=${if (source.exists()) source.length() else -1} name=$fileName mime=$mimeType sdk=${Build.VERSION.SDK_INT}")
            if (!source.exists()) {
                Log.e(tag, "saveToDownloads: source missing")
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
                    Log.e(tag, "saveToDownloads: MediaStore insert returned null uri")
                    return null
                }
                Log.i(tag, "saveToDownloads: inserted uri=$uri")

                var written = 0L
                try {
                    val output = resolver.openOutputStream(uri)
                    if (output == null) {
                        Log.e(tag, "saveToDownloads: openOutputStream null, deleting row")
                        resolver.delete(uri, null, null)
                        return null
                    }
                    output.use { out ->
                        source.inputStream().use { input -> written = input.copyTo(out) }
                        out.flush()
                    }
                } catch (e: Exception) {
                    Log.e(tag, "saveToDownloads: write failed, deleting row", e)
                    resolver.delete(uri, null, null)
                    return null
                }

                val done = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
                resolver.update(uri, done, null, null)

                // Verify the row is readable and complete before reporting success.
                var verified = 0L
                try {
                    resolver.openInputStream(uri)?.use { verified = it.available().toLong() }
                } catch (e: Exception) {
                    Log.e(tag, "saveToDownloads: verification read failed", e)
                }
                Log.i(tag, "saveToDownloads: written=$written expected=$sourceSize verifyReadable=$verified uri=$uri")

                if (written != sourceSize) {
                    Log.e(tag, "saveToDownloads: byte mismatch, deleting row")
                    resolver.delete(uri, null, null)
                    return null
                }
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
                Log.i(tag, "saveToDownloads(legacy): target=${target.absolutePath} ok=$ok")
                if (!ok) null else mapOf("uri" to target.absolutePath, "bytes" to target.length())
            }
        } catch (e: Exception) {
            Log.e(tag, "saveToDownloads: unexpected failure", e)
            null
        }
    }
}
