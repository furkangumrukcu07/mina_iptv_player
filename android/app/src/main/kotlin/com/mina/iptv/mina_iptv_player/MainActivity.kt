package com.mina.iptv.mina_iptv_player

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import android.util.Rational
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pipChannel: MethodChannel? = null

    /** Dart [PlayerController] uygun olduğunda true — API 31+ otomatik PiP, API 26–30 [onPause] girişi. */
    private var pipAutoEnterEligible = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        pipChannel = MethodChannel(messenger, "mina.player/pip").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPipAutoEnterEligible" -> {
                        val m = call.arguments as? Map<*, *>
                        pipAutoEnterEligible = m?.get("eligible") == true
                        applyPipAutoEnterParams()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            messenger,
            "mina.device/layout",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> {
                    val pm = packageManager
                    val tv = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                        pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
                    result.success(tv)
                }
                "mediaKitSoCProfile" -> {
                    val hw = Build.HARDWARE.lowercase(Locale.US)
                    val board = Build.BOARD.lowercase(Locale.US)
                    val man = Build.MANUFACTURER.lowercase(Locale.US)
                    val brand = Build.BRAND.lowercase(Locale.US)
                    val model = Build.MODEL.lowercase(Locale.US)
                    val blob = "$hw $board $man $brand $model"
                    val amlogic = blob.contains("amlogic") || blob.contains("meson")
                    result.success(
                        mapOf(
                            "amlogicLike" to amlogic,
                            "hardware" to Build.HARDWARE,
                            "board" to Build.BOARD,
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun applyPipAutoEnterParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) return
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setSeamlessResizeEnabled(true)
                .setAutoEnterEnabled(pipAutoEnterEligible)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val label = applicationInfo.loadLabel(packageManager)
                if (label.isNotEmpty()) {
                    builder.setTitle(label)
                }
            } catch (_: Exception) {
                // ignore
            }
        }
        try {
            setPictureInPictureParams(builder.build())
        } catch (e: Exception) {
            Log.w("MainActivity", "setPictureInPictureParams: $e")
        }
    }

    override fun onResume() {
        super.onResume()
        applyPipAutoEnterParams()
    }

    override fun onPause() {
        // API 26–30: ana ekrana geçerken asenkron Dart çağrısı çoğu zaman geç kalır; burada senkron dene.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            pipAutoEnterEligible &&
            !isChangingConfigurations &&
            !isFinishing
        ) {
            try {
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build()
                val ok = enterPictureInPictureMode(params)
                if (!ok) {
                    Log.w("MainActivity", "onPause enterPictureInPictureMode returned false")
                }
            } catch (e: Exception) {
                Log.w("MainActivity", "onPause PiP: $e")
            }
        }
        super.onPause()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }
}
