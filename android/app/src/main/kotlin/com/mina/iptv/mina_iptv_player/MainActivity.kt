package com.mina.iptv.mina_iptv_player

import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Rational
import java.util.Locale
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pipChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15 (SDK 35) edge-to-edge: Play Console uyarısı; Flutter insets ile uyumlu.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    /** Dart [PlayerController] uygun olduğunda true — API 31+ otomatik PiP, API 26–30 [onPause] girişi. */
    private var pipAutoEnterEligible = false

    private val pipExitHandler = Handler(Looper.getMainLooper())
    private var pipDismissFinishRunnable: Runnable? = null

    /**
     * PiP kapatıldı (X) mı yoksa tam ekrana genişletildi mi ayırt etmek için:
     * Genişletmede hemen [onResume] gelir ve zamanlayıcı iptal edilir.
     * Sistem PiP’i kapatınca [onResume] olmadan arka plana düşer; zamanlayıcı [finishAffinity] çalıştırır.
     */
    private var awaitingPipCloseOrExpand = false

    /** Yalnızca PiP moduna girildiyse çıkışta görev sonlandırılır. */
    private var wasInPictureInPicture = false

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
                    val leanbackOrTv = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                        pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
                    // Bazı kutular telefon ROM’u ile gelir; sistem UI’ı yine “TV” modunda olabilir.
                    val ui = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
                    val uiTelevision = ui == Configuration.UI_MODE_TYPE_TELEVISION
                    result.success(leanbackOrTv || uiTelevision)
                }
                "mediaKitSoCProfile" -> {
                    val hw = Build.HARDWARE.lowercase(Locale.US)
                    val board = Build.BOARD.lowercase(Locale.US)
                    val man = Build.MANUFACTURER.lowercase(Locale.US)
                    val brand = Build.BRAND.lowercase(Locale.US)
                    val model = Build.MODEL.lowercase(Locale.US)
                    val blob = "$hw $board $man $brand $model"
                    val amlogic = blob.contains("amlogic") || blob.contains("meson")
                    val cores = Runtime.getRuntime().availableProcessors()
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val mi = ActivityManager.MemoryInfo()
                    am.getMemoryInfo(mi)
                    val ram = mi.totalMem
                    val twoHalfGiB = (2.5 * 1024 * 1024 * 1024).toLong()
                    // Düşük RAM veya az çekirdek: MediaKit (mpv) için daha agresif framedrop / thread sınırı.
                    val weakMpv = ram < twoHalfGiB || cores <= 4
                    val isTv = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                        packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION) ||
                        (resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK) ==
                        Configuration.UI_MODE_TYPE_TELEVISION
                    val xiaomiFamily = listOf("xiaomi", "redmi", "poco", "black shark").any { x ->
                        man.contains(x) || brand.contains(x) || model.contains(x)
                    }
                    result.success(
                        mapOf(
                            "amlogicLike" to amlogic,
                            "hardware" to Build.HARDWARE,
                            "board" to Build.BOARD,
                            "model" to Build.MODEL,
                            "totalRamBytes" to ram,
                            "availableProcessors" to cores,
                            "weakMpvDevice" to weakMpv,
                            "isAndroidTv" to isTv,
                            "xiaomiFamily" to xiaomiFamily,
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
        if (awaitingPipCloseOrExpand) {
            awaitingPipCloseOrExpand = false
            pipDismissFinishRunnable?.let { pipExitHandler.removeCallbacks(it) }
            pipDismissFinishRunnable = null
        }
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
        if (isInPictureInPictureMode) {
            wasInPictureInPicture = true
            return
        }
        if (!wasInPictureInPicture) return
        wasInPictureInPicture = false
        pipDismissFinishRunnable?.let { pipExitHandler.removeCallbacks(it) }
        pipDismissFinishRunnable = null
        awaitingPipCloseOrExpand = true
        val r = Runnable {
            pipDismissFinishRunnable = null
            if (!awaitingPipCloseOrExpand) return@Runnable
            awaitingPipCloseOrExpand = false
            if (isFinishing || isDestroyed) return@Runnable
            try {
                finishAffinity()
            } catch (e: Exception) {
                Log.w("MainActivity", "finishAffinity after PiP dismiss: $e")
            }
        }
        pipDismissFinishRunnable = r
        // Tam ekrana genişletmede onResume gelir ve bu görev iptal edilir; PiP X ile kapatmada gelmez.
        pipExitHandler.postDelayed(r, 400L)
    }

    override fun onDestroy() {
        pipDismissFinishRunnable?.let { pipExitHandler.removeCallbacks(it) }
        pipDismissFinishRunnable = null
        awaitingPipCloseOrExpand = false
        wasInPictureInPicture = false
        super.onDestroy()
    }
}
