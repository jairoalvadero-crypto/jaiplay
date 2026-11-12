package com.jaiplay.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.jaiplay.app/device_storage"
    private val pickerRequestCode = 4817
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingPickerMethod: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickAudioFile" -> {
                        val name = call.argument<String>("name")
                        if (name.isNullOrBlank()) {
                            result.error("invalid_name", "Falta el nombre del archivo.", null)
                            return@setMethodCallHandler
                        }
                        launchPicker(
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "audio/*"
                                putExtra(Intent.EXTRA_TITLE, name)
                            },
                            call.method,
                            result,
                        )
                    }

                    "pickAudioDirectory" -> launchPicker(
                        Intent(Intent.ACTION_OPEN_DOCUMENT_TREE),
                        call.method,
                        result,
                    )

                    "writeAudioFile" -> {
                        val uri = call.argument<String>("uri")?.let(Uri::parse)
                        val path = call.argument<String>("path")
                        if (uri == null || path.isNullOrBlank()) {
                            result.error("invalid_file", "Faltan datos del archivo.", null)
                            return@setMethodCallHandler
                        }
                        copyToUri(uri, path, result)
                    }

                    "writeAudioFilesToDirectory" -> {
                        val uri = call.argument<String>("uri")?.let(Uri::parse)
                        val files = call.argument<List<Map<String, String>>>("files")
                        if (uri == null || files.isNullOrEmpty()) {
                            result.error("invalid_album", "Faltan la carpeta o las canciones.", null)
                            return@setMethodCallHandler
                        }
                        copyAlbumToTree(uri, files, result)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun launchPicker(
        intent: Intent,
        method: String,
        result: MethodChannel.Result,
    ) {
        if (pendingPickerResult != null) {
            result.error("picker_busy", "Ya hay un selector de archivos abierto.", null)
            return
        }
        try {
            pendingPickerMethod = method
            pendingPickerResult = result
            startActivityForResult(intent, pickerRequestCode)
        } catch (error: Exception) {
            pendingPickerMethod = null
            pendingPickerResult = null
            result.error("picker_failed", error.message, null)
        }
    }

    @Deprecated("Deprecated in Android, retained for compatibility with the Flutter activity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickerRequestCode) return
        val result = pendingPickerResult ?: return
        val method = pendingPickerMethod
        pendingPickerResult = null
        pendingPickerMethod = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data!!
        try {
            if (method == "pickAudioDirectory") {
                val flags = data.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                contentResolver.takePersistableUriPermission(uri, flags)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("permission_failed", error.message, null)
        }
    }

    private fun copyToUri(uri: Uri, path: String, result: MethodChannel.Result) {
        Thread {
            try {
                val source = java.io.File(path)
                contentResolver.openOutputStream(uri, "w").use { output ->
                    if (output == null) throw IllegalStateException("No se pudo abrir el destino.")
                    source.inputStream().use { input -> input.copyTo(output) }
                }
                runOnUiThread { result.success(null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("save_failed", error.message, null)
                }
            }
        }.start()
    }

    private fun copyAlbumToTree(
        treeUri: Uri,
        files: List<Map<String, String>>,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                val parent = DocumentFile.fromTreeUri(this, treeUri)
                    ?: throw IllegalStateException("No se pudo abrir la carpeta seleccionada.")
                for (file in files) {
                    val path = file["path"]
                        ?: throw IllegalArgumentException("Falta la ruta de una canción.")
                    val name = file["name"]
                        ?: throw IllegalArgumentException("Falta el nombre de una canción.")
                    val extension = name.substringAfterLast('.', "")
                    val mime = MimeTypeMap.getSingleton()
                        .getMimeTypeFromExtension(extension.lowercase()) ?: "audio/*"
                    val destination = parent.createFile(mime, name)
                        ?: throw IllegalStateException("No se pudo crear «$name».")
                    contentResolver.openOutputStream(destination.uri, "w").use { output ->
                        if (output == null) throw IllegalStateException("No se pudo abrir «$name».")
                        java.io.File(path).inputStream().use { input -> input.copyTo(output) }
                    }
                }
                runOnUiThread { result.success(null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("album_save_failed", error.message, null)
                }
            }
        }.start()
    }
}
