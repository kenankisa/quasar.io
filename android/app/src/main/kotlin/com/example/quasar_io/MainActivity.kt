package com.example.quasar_io

import android.os.Build
import android.os.Bundle
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/** Caps display / surface cadence at 60 Hz to cut mobile heat on 90/120 Hz panels. */
class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    applyMaxFps(TARGET_FPS)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      CHANNEL,
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "setMaxFps" -> {
          val fps = call.argument<Number>("fps")?.toFloat() ?: TARGET_FPS
          applyMaxFps(fps)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun applyMaxFps(fps: Float) {
    val target = fps.coerceIn(30f, 120f)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        display
      } else {
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay
      }

      if (display != null) {
        val current = display.mode
        val mode60 = display.supportedModes
          .filter {
            it.physicalWidth == current.physicalWidth &&
              it.physicalHeight == current.physicalHeight &&
              it.refreshRate <= target + 1.5f
          }
          .minByOrNull { abs(it.refreshRate - target) }

        val attrs = window.attributes
        attrs.preferredRefreshRate = target
        if (mode60 != null) {
          attrs.preferredDisplayModeId = mode60.modeId
        }
        window.attributes = attrs
      } else {
        val attrs = window.attributes
        attrs.preferredRefreshRate = target
        window.attributes = attrs
      }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      window.decorView.post { setSurfaceFrameRate(window.decorView, target) }
    }
  }

  private fun setSurfaceFrameRate(view: View, fps: Float) {
    when (view) {
      is FlutterSurfaceView -> {
        val surface = view.holder.surface
        if (surface != null && surface.isValid) {
          surface.setFrameRate(fps, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
        }
      }
      is ViewGroup -> {
        for (i in 0 until view.childCount) {
          setSurfaceFrameRate(view.getChildAt(i), fps)
        }
      }
    }
  }

  companion object {
    private const val CHANNEL = "quasar_io/display"
    private const val TARGET_FPS = 60f
  }
}
