package com.muskmelon.vinyl

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {

    private companion object {
        const val DELETE_CHANNEL = "com.muskmelon.vinyl/media_delete"
        const val DELETE_REQUEST_CODE = 7301
    }

    // A delete that is waiting for the user to answer the system prompt.
    private var pendingResult: MethodChannel.Result? = null
    private var pendingUri: Uri? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DELETE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "deleteAudioFile") {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "Missing file path", null)
                    } else {
                        deleteAudioFile(path, result)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Deletes an audio file from device storage.
     *
     * Result is one of: "deleted", "not_found", "cancelled", "failed".
     * Files this app created can be deleted directly. Files owned by other
     * apps (Android 10+) need the user's approval through the system prompt.
     */
    private fun deleteAudioFile(path: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another delete is waiting for the user", null)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            // Nothing on disk; drop any stale MediaStore row and report success.
            findMediaUri(path)?.let { uri ->
                try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
            }
            result.success("not_found")
            return
        }

        // 1. Direct delete works for files this app owns (e.g. its own downloads).
        try {
            if (file.delete()) {
                findMediaUri(path)?.let { uri ->
                    try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
                }
                result.success("deleted")
                return
            }
        } catch (_: SecurityException) {
        }

        // 2. Owned by another app: go through MediaStore.
        val uri = findMediaUri(path)
        if (uri == null) {
            result.success("failed")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+: system dialog asking the user to allow the delete.
            val request = MediaStore.createDeleteRequest(contentResolver, listOf(uri))
            launchPrompt(request.intentSender, uri, path, result)
            return
        }

        try {
            val rows = contentResolver.delete(uri, null, null)
            result.success(if (rows > 0 || !file.exists()) "deleted" else "failed")
        } catch (e: SecurityException) {
            // Android 10: the exception carries the approval prompt.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && e is RecoverableSecurityException) {
                launchPrompt(e.userAction.actionIntent.intentSender, uri, path, result)
            } else {
                result.success("failed")
            }
        } catch (_: Exception) {
            result.success("failed")
        }
    }

    private fun launchPrompt(sender: IntentSender, uri: Uri, path: String, result: MethodChannel.Result) {
        pendingResult = result
        pendingUri = uri
        pendingPath = path
        try {
            startIntentSenderForResult(sender, DELETE_REQUEST_CODE, null, 0, 0, 0)
        } catch (_: Exception) {
            clearPending()
            result.success("failed")
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != DELETE_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult ?: return
        val uri = pendingUri
        val path = pendingPath
        clearPending()

        if (resultCode != Activity.RESULT_OK) {
            result.success("cancelled")
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // createDeleteRequest already deleted the file once approved.
            result.success("deleted")
            return
        }
        // Android 10: approval granted, now the delete is allowed.
        try {
            if (uri != null) contentResolver.delete(uri, null, null)
            val gone = path == null || !File(path).exists()
            result.success(if (gone) "deleted" else "failed")
        } catch (_: Exception) {
            result.success("failed")
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingUri = null
        pendingPath = null
    }

    /** Looks up the MediaStore entry for an absolute file path. */
    @Suppress("DEPRECATION")
    private fun findMediaUri(path: String): Uri? {
        val collections = listOf(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Files.getContentUri("external"),
        )
        for (collection in collections) {
            try {
                contentResolver.query(
                    collection,
                    arrayOf(MediaStore.MediaColumns._ID),
                    "${MediaStore.MediaColumns.DATA} = ?",
                    arrayOf(path),
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        return ContentUris.withAppendedId(collection, cursor.getLong(0))
                    }
                }
            } catch (_: Exception) {
            }
        }
        return null
    }
}
