package com.edde746.plezy.fork

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * FORK: native half of the Plezy Streamer in-app updater (see
 * lib/fork/streamer_update.dart). Hands a downloaded APK to Android's package
 * installer, which asks the user to confirm.
 */
internal object StreamerUpdateChannel {
  private const val CHANNEL = "com.plezy.fork/update"
  private const val APK_MIME_TYPE = "application/vnd.android.package-archive"

  fun attach(activity: Activity, messenger: BinaryMessenger) {
    MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "installApk" -> {
          val path = call.argument<String>("path")
          if (path.isNullOrEmpty()) {
            result.error("BAD_ARGS", "Missing APK path", null)
            return@setMethodCallHandler
          }
          val file = File(path)
          if (!file.isFile) {
            result.error("NO_FILE", "APK not found: $path", null)
            return@setMethodCallHandler
          }
          try {
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW)
              .setDataAndType(uri, APK_MIME_TYPE)
              // No NEW_TASK: the installer opens on top of this activity. With
              // NEW_TASK Android may only bring a leftover installer task from
              // the previous update to the front and show nothing.
              .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            activity.startActivity(intent)
            result.success(null)
          } catch (e: ActivityNotFoundException) {
            result.error("NO_INSTALLER", "No package installer available", null)
          } catch (e: IllegalArgumentException) {
            result.error("BAD_PATH", e.message, null)
          } catch (e: SecurityException) {
            result.error("DENIED", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}
