package com.edde746.plezy.fork

import android.app.Activity
import android.app.Application
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * FORK: plays a show's theme music once while its detail page is open (see
 * lib/fork/streamer_theme.dart). A plain MediaPlayer on the server's theme
 * URL; it stops when asked, when the tune ends, or when the app is paused.
 */
internal object StreamerThemeChannel {
  private const val CHANNEL = "com.plezy.fork/theme"
  private const val FADE_STEP_MS = 40L
  private const val FADE_STEPS = 10

  private val handler = Handler(Looper.getMainLooper())
  private var player: MediaPlayer? = null

  fun attach(activity: Activity, messenger: BinaryMessenger) {
    MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "play" -> {
          val url = call.argument<String>("url")
          if (url.isNullOrEmpty()) {
            result.error("BAD_ARGS", "Missing theme URL", null)
            return@setMethodCallHandler
          }
          val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
          val volume = (call.argument<Double>("volume") ?: 0.5).toFloat().coerceIn(0f, 1f)
          play(activity, url, headers, volume)
          result.success(null)
        }
        "stop" -> {
          stop(fade = true)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }

    activity.application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
      override fun onActivityPaused(paused: Activity) {
        if (paused === activity) stop(fade = false)
      }

      override fun onActivityDestroyed(destroyed: Activity) {
        if (destroyed === activity) {
          stop(fade = false)
          activity.application.unregisterActivityLifecycleCallbacks(this)
        }
      }

      override fun onActivityCreated(a: Activity, savedInstanceState: Bundle?) {}
      override fun onActivityStarted(a: Activity) {}
      override fun onActivityResumed(a: Activity) {}
      override fun onActivityStopped(a: Activity) {}
      override fun onActivitySaveInstanceState(a: Activity, outState: Bundle) {}
    })
  }

  private fun play(activity: Activity, url: String, headers: Map<String, String>, volume: Float) {
    stop(fade = false)
    val created = MediaPlayer()
    player = created
    try {
      created.setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(AudioAttributes.USAGE_MEDIA)
          .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
          .build()
      )
      created.setDataSource(activity.applicationContext, Uri.parse(url), headers)
      created.isLooping = false
      created.setVolume(volume, volume)
      created.setOnPreparedListener { prepared -> if (player === prepared) prepared.start() }
      created.setOnCompletionListener { finished -> release(finished) }
      // No theme on the server (404) or an unreachable server lands here.
      created.setOnErrorListener { failed, _, _ ->
        release(failed)
        true
      }
      created.prepareAsync()
    } catch (e: Exception) {
      release(created)
    }
  }

  private fun stop(fade: Boolean) {
    val current = player ?: return
    player = null
    handler.removeCallbacksAndMessages(null)
    val playing = try {
      current.isPlaying
    } catch (e: IllegalStateException) {
      false
    }
    if (!fade || !playing) {
      release(current)
      return
    }
    var step = FADE_STEPS
    val fadeOut = object : Runnable {
      override fun run() {
        step--
        if (step <= 0) {
          release(current)
          return
        }
        try {
          val level = 0.5f * step / FADE_STEPS
          current.setVolume(level, level)
        } catch (e: IllegalStateException) {
          release(current)
          return
        }
        handler.postDelayed(this, FADE_STEP_MS)
      }
    }
    handler.post(fadeOut)
  }

  private fun release(target: MediaPlayer) {
    if (player === target) player = null
    try {
      target.setOnPreparedListener(null)
      target.setOnCompletionListener(null)
      target.setOnErrorListener(null)
      target.reset()
    } catch (e: IllegalStateException) {
      // Already released.
    }
    target.release()
  }
}
