package com.mahdi_abbasi.dms.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val scanIo = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dms/scan_images")
            .setMethodCallHandler { call, result ->
                if (call.method != "copyImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val reference = call.argument<String>("uri")
                val target = call.argument<String>("target")
                if (reference == null || target == null) {
                    result.error("INVALID_IMAGE", "Missing image location", null)
                    return@setMethodCallHandler
                }
                scanIo.execute {
                    try {
                        val destination = File(target).canonicalFile
                        val permitted = listOf(cacheDir.canonicalPath, filesDir.canonicalPath)
                            .any { destination.path.startsWith(it + File.separator) }
                        require(permitted && Uri.parse(reference).scheme == "content")
                        contentResolver.openInputStream(Uri.parse(reference)).use { input ->
                            requireNotNull(input) { "Image could not be opened" }
                            destination.outputStream().use { output ->
                                val buffer = ByteArray(8192)
                                var total = 0L
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    total += count
                                    require(total <= 30L * 1024 * 1024) { "Image exceeds 30 MiB" }
                                    output.write(buffer, 0, count)
                                }
                            }
                        }
                        runOnUiThread { result.success(null) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("IMAGE_COPY_FAILED", "Could not import scanner image", null) }
                    }
                }
            }
    }

    override fun onDestroy() {
        scanIo.shutdown()
        super.onDestroy()
    }
}
