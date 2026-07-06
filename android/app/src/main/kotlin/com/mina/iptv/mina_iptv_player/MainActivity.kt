package com.mina.iptv.mina_iptv_player

import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.MediaScannerConnection
import android.media.audiofx.Equalizer
import android.net.TrafficStats
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import android.util.Rational
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.util.Locale
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pipChannel: MethodChannel? = null
    private var activityLifecycleChannel: MethodChannel? = null

    // -------- Audio Equalizer (BetterPlayer / ExoPlayer çıkışı) --------
    // Tek bir Equalizer örneği tutarız; Dart tarafı `bandLevelsMb`
    // değişikliğinde aynı instance üzerinden bantları günceller.
    // session=0 → global output mix; Android 9 sonrası bazı cihazlarda
    // UnsupportedOperationException atar — try/catch ile graceful degrade
    // ederiz ve Dart tarafına `supported=false` döneriz.
    private var nativeEqualizer: Equalizer? = null
    private var nativeEqualizerEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // TV / tablet → Skia; telefon → Impeller (manifest yerine kurulum anında Intent bayrağı).
        intent.putExtra(
            FlutterShellArgs.ARG_KEY_TOGGLE_IMPELLER,
            MinaRendererPolicy.useImpeller(this),
        )
        MinaRendererPolicy.logChoice(this)
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

    /**
     * Bazı cihazlarda PiP tam ekrana genişletilirken [onResume], [onPictureInPictureModeChanged]
     * (false) öncesinde gelir. Bu bayrak o yarışta uygulamanın yanlışlıkla kapanmasını önler.
     */
    private var pipExpandResumeBeforePipModeExit = false

    // Samsung One UI başta olmak üzere bazı OEM'ler View.performHapticFeedback(CLOCK_TICK)
    // — Flutter'ın HapticFeedback.selectionClick() çağrısı — sabitini yok sayıyor. Cihazın
    // titreşim donanımını Vibrator/VibratorManager üzerinden doğrudan tetiklemek için
    // hafifletilmiş bir bridge. Çağrılar ana iş parçacığına yığılmaması adına burada
    // tutuluyor (UI thread'inde milisaniye düzeyinde fn çağrısı).
    private val hapticVibrator: Vibrator? by lazy(LazyThreadSafetyMode.NONE) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }?.takeIf { it.hasVibrator() }
        } catch (_: Throwable) {
            null
        }
    }

    private fun triggerHaptic(intensity: String) {
        val v = hapticVibrator ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val predefined = when (intensity) {
                    // 'light' / 'selection' / 'tick' → kısa, hafif uç.
                    "heavy" -> VibrationEffect.EFFECT_HEAVY_CLICK
                    "medium" -> VibrationEffect.EFFECT_CLICK
                    else -> VibrationEffect.EFFECT_TICK
                }
                v.vibrate(VibrationEffect.createPredefined(predefined))
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val (durMs, amp) = when (intensity) {
                    "heavy" -> 30L to 180
                    "medium" -> 20L to 120
                    else -> 12L to 80
                }
                v.vibrate(VibrationEffect.createOneShot(durMs, amp))
                return
            }
            @Suppress("DEPRECATION")
            v.vibrate(if (intensity == "heavy") 30L else if (intensity == "medium") 20L else 12L)
        } catch (e: Throwable) {
            Log.w("MainActivity", "haptic vibrate failed: $e")
        }
    }

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
        MethodChannel(messenger, "mina.device/info").setMethodCallHandler { call, result ->
            when (call.method) {
                "getFirstInstallTime" -> {
                    try {
                        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        result.success(packageInfo.firstInstallTime)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not get first install time: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        activityLifecycleChannel = MethodChannel(messenger, "mina.app/activity_lifecycle")
        // Adaptive haptics: Samsung/OEM'lerin View.performHapticFeedback(CLOCK_TICK)
        // sabitini yok saydığı cihazlarda Vibrator API'sini doğrudan tetikler.
        MethodChannel(messenger, "mina.device/haptics").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasVibrator" -> {
                    result.success(hapticVibrator != null)
                }
                "tick" -> {
                    triggerHaptic("light")
                    result.success(true)
                }
                "selection" -> {
                    triggerHaptic("light")
                    result.success(true)
                }
                "medium" -> {
                    triggerHaptic("medium")
                    result.success(true)
                }
                "heavy" -> {
                    triggerHaptic("heavy")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            messenger,
            "mina.device/layout",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> {
                    result.success(MinaRendererPolicy.isAndroidTvOrTvBox(this))
                }
                "rendererProfile" -> {
                    val factor = MinaRendererPolicy.detectFormFactor(this)
                    val impeller = MinaRendererPolicy.useImpeller(this)
                    result.success(
                        mapOf(
                            "formFactor" to factor.name.lowercase(Locale.US),
                            "useImpeller" to impeller,
                            "backend" to if (impeller) "impeller" else "skia",
                        ),
                    )
                }
                "mediaKitSoCProfile" -> {
                    val hw = Build.HARDWARE.lowercase(Locale.US)
                    val board = Build.BOARD.lowercase(Locale.US)
                    val man = Build.MANUFACTURER.lowercase(Locale.US)
                    val brand = Build.BRAND.lowercase(Locale.US)
                    val model = Build.MODEL.lowercase(Locale.US)
                    val device = Build.DEVICE.lowercase(Locale.US)
                    val blob = "$hw $board $man $brand $model $device"
                    val digipollLike = listOf("digipoll").any { x ->
                        man.contains(x) || brand.contains(x) || model.contains(x)
                    }
                    val amlogic = blob.contains("amlogic") || blob.contains("meson")
                    val tclLike = listOf("tcl").any { x ->
                        man.contains(x) || brand.contains(x) || model.contains(x)
                    }
                    val philipsLike = listOf("philips", "tpv", "pfl", "pus").any { x ->
                        man.contains(x) || brand.contains(x) || model.contains(x)
                    }
                    val toshibaLike = listOf("toshiba", "regza").any { x ->
                        man.contains(x) || brand.contains(x) || model.contains(x)
                    }
                    val hisenseLike = listOf("hisense", "vidaa").any { x ->
                        man.contains(x) || brand.contains(x) || model.contains(x)
                    }
                    val vestelLike = listOf("vestel", "regal", "finlux").any { x ->
                        man.contains(x) || brand.contains(x) || model.contains(x)
                    }
                    val mediatekLike = listOf("mediatek", "mtk").any { x -> blob.contains(x) } ||
                        hw.startsWith("mt")
                    val realtekLike = blob.contains("realtek") || hw.startsWith("rtd")
                    // Ucuz 4K Android kutular (Next Star, Atlas, Vestel vb.) çoğunlukla
                    // Allwinner (sunxi: sun8i / sun50iw…) veya Rockchip (rk3318 / rk3328 /
                    // rk3399) yonga seti kullanır. Bu zayıf kod çözücüler dengeli (mid)
                    // tamponla kesik kesik oynatır; `playbackChallengedTv` ile `low`
                    // profile (geniş tampon + VOD yazılım kod çözücü ilk deneme) inerler.
                    val allwinnerLike = blob.contains("allwinner") ||
                        hw.startsWith("sun") || board.startsWith("sun") || board.startsWith("exdroid")
                    val rockchipLike = blob.contains("rockchip") ||
                        hw.startsWith("rk3") || board.startsWith("rk3")
                    val genericBudgetBoxLike = listOf(
                        "x96", "x98", "t95", "t96", "t98", "h96", "h98", "h616", "h618",
                        "tanix", "mxq", "tx3", "tx6", "transpeed", "bqeel", "vontar",
                        "atlas", "next star", "nextstar",
                    ).any { x -> model.contains(x) || brand.contains(x) || device.contains(x) }
                    val budgetTvBoxSoc = allwinnerLike || rockchipLike || genericBudgetBoxLike
                    val cores = Runtime.getRuntime().availableProcessors()
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val mi = ActivityManager.MemoryInfo()
                    am.getMemoryInfo(mi)
                    val ram = mi.totalMem
                    val oneGiB = 1024L * 1024 * 1024
                    val twoGiB = 2L * oneGiB
                    val threeGiB = 3L * oneGiB
                    val twoHalfGiB = (2.5 * 1024 * 1024 * 1024).toLong()
                    val fourGiB = 4L * oneGiB
                    val isTv = MinaRendererPolicy.isAndroidTvOrTvBox(this)
                    val capableTwoGiBTvBox = ram >= twoGiB && ram < threeGiB && cores >= 4 &&
                        !budgetTvBoxSoc &&
                        listOf(
                            "google", "chromecast", "sabrina", "oneday", "xiaomi", "mi box",
                            "mitv", "mi tv stick", "onn", "mecool", "km9", "km2", "nvidia",
                            "shield", "tivo", "formuler",
                        ).any { x -> blob.contains(x) }
                    val weakMpv = (ram < twoHalfGiB || cores <= 4) && !capableTwoGiBTvBox
                    val amazonFireLike = isTv &&
                        listOf("amazon", "fire tv", "aft", "sheldon", "mantis").any { x ->
                            man.contains(x) || brand.contains(x) || model.contains(x) || device.contains(x)
                        }
                    val lowEndSmartTvLike = isTv &&
                        (tclLike || philipsLike || toshibaLike || hisenseLike || vestelLike ||
                            realtekLike || (mediatekLike && ram < fourGiB))
                    // TCL / Google TV (ör. C755): Exo MTK/Realtek ve mpv mediacodec-copy sık bozulur.
                    // Allwinner/Rockchip ucuz 4K kutular da aynı zorlu kod çözücü sınıfına girer.
                    val playbackChallengedTv = isTv &&
                        (amlogic || tclLike || philipsLike || toshibaLike || hisenseLike ||
                            vestelLike || mediatekLike || realtekLike ||
                            allwinnerLike || rockchipLike || genericBudgetBoxLike ||
                            digipollLike || amazonFireLike || lowEndSmartTvLike || weakMpv)
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
                            "playbackChallengedTv" to playbackChallengedTv,
                            "tclLike" to tclLike,
                            "philipsLike" to philipsLike,
                            "toshibaLike" to toshibaLike,
                            "hisenseLike" to hisenseLike,
                            "vestelLike" to vestelLike,
                            "mediatekLike" to mediatekLike,
                            "allwinnerLike" to allwinnerLike,
                            "rockchipLike" to rockchipLike,
                            "genericBudgetBoxLike" to genericBudgetBoxLike,
                            "budgetTvBoxSoc" to budgetTvBoxSoc,
                            "lowEndSmartTvLike" to lowEndSmartTvLike,
                            "capableTwoGiBTvBox" to capableTwoGiBTvBox,
                            "amazonFireLike" to amazonFireLike,
                            "digipollLike" to digipollLike,
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
        // Veri Kullanım Detayı: bu uygulamanın UID'i için cihaz açıldığından
        // beri biriken alınan/gönderilen byte miktarı. Dart tarafı her
        // poll'da delta'yı hesaplayıp connectivity_plus ile algılanan
        // mevcut bağlantıya (wifi/mobil) yazar. Cihaz yeniden başlarsa
        // sayaç sıfırlanır; Dart bunu negatif delta ile fark eder ve
        // baseline'ı resetler.
        MethodChannel(messenger, "mina.device/data_usage").setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getStats" -> {
                    try {
                        val uid = Process.myUid()
                        val rx = TrafficStats.getUidRxBytes(uid)
                        val tx = TrafficStats.getUidTxBytes(uid)
                        // TrafficStats.UNSUPPORTED == -1; Android 7+'da uid
                        // başına izleme genelde çalışır, eski cihazlar için
                        // toplam (mobil + wifi) ile fallback.
                        val totalRx = if (rx >= 0) rx else TrafficStats.getTotalRxBytes()
                        val totalTx = if (tx >= 0) tx else TrafficStats.getTotalTxBytes()
                        result.success(
                            mapOf(
                                "rxBytes" to totalRx,
                                "txBytes" to totalTx,
                                "uidSupported" to (rx >= 0 && tx >= 0),
                                "uptimeMs" to SystemClock.elapsedRealtime(),
                            ),
                        )
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "data_usage getStats: $e")
                        result.error("data_usage_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // Ses Equalizer: BetterPlayer (ExoPlayer) çıkışı için
        // android.media.audiofx.Equalizer. Çağrılar:
        // * info → numberOfBands, bandLevelRange (millibel), center freq
        //   listesi (Hz) ve `supported` bayrağı.
        // * apply → {enabled, bandLevelsMb: List<Int>} — bant sayısı Dart
        //   tarafının verdiği listenin uzunluğuna eşit olmalı (10 logical
        //   bant → cihaz N bant interpolasyonu Dart'ta yapılır).
        // * release → instance'ı serbest bırakır.
        MethodChannel(messenger, "mina.player/equalizer").setMethodCallHandler {
            call, result ->
            when (call.method) {
                "info" -> {
                    try {
                        val info = ensureNativeEqualizerInfo()
                        result.success(info)
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "equalizer info: $e")
                        result.success(
                            mapOf(
                                "supported" to false,
                                "errorMessage" to (e.message ?: "init failed"),
                            ),
                        )
                    }
                }
                "apply" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val enabled = args?.get("enabled") == true
                        val raw = args?.get("bandLevelsMb") as? List<*>
                        val levels = raw?.mapNotNull {
                            (it as? Number)?.toInt()
                        } ?: emptyList()
                        val ok = applyNativeEqualizer(enabled, levels)
                        result.success(ok)
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "equalizer apply: $e")
                        result.success(false)
                    }
                }
                "release" -> {
                    try {
                        releaseNativeEqualizer()
                        result.success(true)
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "equalizer release: $e")
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // MediaStore köprüsü: kayıt / indirme tamamlandığında dosyayı
        // public Movies/MinaIPTV altına kopyalar. Android 10+ scoped
        // storage kullanır — `WRITE_EXTERNAL_STORAGE` izni gerektirmez.
        // Eski cihazlarda (API ≤ 28) MediaScannerConnection ile mevcut
        // app-scoped dosyayı tarayıcıya bildirir (Galeri görmez ama
        // dosya yöneticisi görür).
        MethodChannel(messenger, "mina.player/media_store").setMethodCallHandler {
            call, result ->
            when (call.method) {
                "saveToGallery" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val srcPath = (args?.get("sourcePath") as? String)?.trim().orEmpty()
                        val displayName = (args?.get("displayName") as? String)?.trim().orEmpty()
                        val subFolderRaw = (args?.get("subFolder") as? String)?.trim().orEmpty()
                        val subFolder = if (subFolderRaw.isEmpty()) "MinaIPTV" else subFolderRaw
                        val mimeTypeRaw = (args?.get("mimeType") as? String)?.trim().orEmpty()
                        val mimeType =
                            if (mimeTypeRaw.isEmpty()) guessMimeForFile(srcPath) else mimeTypeRaw
                        if (srcPath.isEmpty() || !File(srcPath).exists()) {
                            result.error(
                                "mediastore_source_missing",
                                "Source file not found: $srcPath",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val finalName = displayName.ifEmpty {
                            File(srcPath).nameWithoutExtension
                        } + extensionOrFallback(srcPath)
                        val saved = saveVideoToGallery(
                            srcPath = srcPath,
                            displayName = finalName,
                            subFolder = subFolder,
                            mimeType = mimeType,
                        )
                        result.success(saved)
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "media_store saveToGallery: $e")
                        result.error(
                            "mediastore_save_failed",
                            e.message ?: "save failed",
                            null,
                        )
                    }
                }
                "openFile" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val srcPath = (args?.get("path") as? String)?.trim().orEmpty()
                        val title = (args?.get("title") as? String)?.takeUnless { it.isEmpty() }
                        val mimeTypeRaw = (args?.get("mimeType") as? String)?.trim().orEmpty()
                        if (srcPath.isEmpty() || !File(srcPath).exists()) {
                            Log.w(
                                "MainActivity",
                                "media_store openFile: source missing path=$srcPath",
                            )
                            result.error(
                                "open_source_missing",
                                "Source file not found",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "$packageName.fileprovider",
                            File(srcPath),
                        )
                        // Sırayla farklı MIME'lerle dene — Android bazı cihazlarda
                        // explicit MIME bekler, bazılarında wildcard daha iyi
                        // sonuç verir.
                        val mimeCandidates = buildList {
                            if (mimeTypeRaw.isNotEmpty()) add(mimeTypeRaw)
                            val guessed = guessMimeForFile(srcPath)
                            if (guessed !in this) add(guessed)
                            if ("video/*" !in this) add("video/*")
                            if ("*/*" !in this) add("*/*")
                        }
                        var launched = false
                        var lastErr: Throwable? = null
                        for (m in mimeCandidates) {
                            try {
                                val view = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, m)
                                    addFlags(
                                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                            Intent.FLAG_ACTIVITY_NEW_TASK,
                                    )
                                    if (!title.isNullOrBlank()) {
                                        putExtra("title", title)
                                        putExtra("displayName", title)
                                    }
                                }
                                // Eğer hiç app handler yoksa createChooser boş bir
                                // chooser göstermek yerine ActivityNotFound atar
                                // → bir sonraki MIME'a düşer.
                                val resolves = packageManager
                                    .queryIntentActivities(view, 0)
                                if (resolves.isEmpty()) {
                                    Log.w(
                                        "MainActivity",
                                        "openFile: no handler for mime=$m",
                                    )
                                    continue
                                }
                                val chooser =
                                    Intent.createChooser(view, title ?: "Open").apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                startActivity(chooser)
                                Log.i(
                                    "MainActivity",
                                    "openFile: launched with mime=$m path=$srcPath",
                                )
                                launched = true
                                break
                            } catch (e: Throwable) {
                                lastErr = e
                                Log.w("MainActivity", "openFile mime=$m failed: $e")
                            }
                        }
                        if (!launched) {
                            Log.w(
                                "MainActivity",
                                "openFile: no MIME variant could launch chooser " +
                                    "for $srcPath; lastErr=$lastErr",
                            )
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "media_store openFile: $e")
                        result.error("open_failed", e.message ?: "open failed", null)
                    }
                }
                "openFolder" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val folderPath = (args?.get("path") as? String)?.trim().orEmpty()
                        if (folderPath.isEmpty() || !File(folderPath).exists()) {
                            Log.w("MainActivity", "openFolder: missing $folderPath")
                            result.error(
                                "folder_missing",
                                "Folder not found: $folderPath",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        // Klasörler için 2 strateji deniyoruz:
                        // 1) ACTION_VIEW + Document Tree URI (Files apps)
                        // 2) ACTION_GET_CONTENT + Documents UI (fallback)
                        val candidates = mutableListOf<Intent>()
                        // 1) Direkt klasör URI'si — Files / DocumentsUI bunu açar.
                        candidates += Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                Uri.parse("content://com.android.externalstorage.documents/document/primary%3A" +
                                    folderPath.removePrefix("/storage/emulated/0/")
                                        .replace("/", "%2F")),
                                "vnd.android.document/directory",
                            )
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        // 2) Boş bir intent ile Files seçicisi
                        candidates += Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                Uri.parse("file://$folderPath"),
                                "resource/folder",
                            )
                        }
                        var ok = false
                        for (intent in candidates) {
                            try {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                val resolves = packageManager.queryIntentActivities(intent, 0)
                                if (resolves.isEmpty()) continue
                                startActivity(
                                    Intent.createChooser(intent, "Open folder").apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    },
                                )
                                ok = true
                                Log.i("MainActivity", "openFolder launched: $folderPath")
                                break
                            } catch (e: Throwable) {
                                Log.w("MainActivity", "openFolder candidate failed: $e")
                            }
                        }
                        result.success(ok)
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "openFolder: $e")
                        result.error("openFolder_failed", e.message, null)
                    }
                }
                "shareFile" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val srcPath = (args?.get("path") as? String)?.trim().orEmpty()
                        val title = (args?.get("title") as? String)?.takeUnless { it.isEmpty() }
                        val mimeTypeRaw = (args?.get("mimeType") as? String)?.trim().orEmpty()
                        val mimeType =
                            if (mimeTypeRaw.isEmpty()) guessMimeForFile(srcPath) else mimeTypeRaw
                        if (srcPath.isEmpty() || !File(srcPath).exists()) {
                            result.error(
                                "share_source_missing",
                                "Source file not found",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "$packageName.fileprovider",
                            File(srcPath),
                        )
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            if (!title.isNullOrBlank()) {
                                putExtra(Intent.EXTRA_TITLE, title)
                                putExtra(Intent.EXTRA_SUBJECT, title)
                            }
                        }
                        val chooser = Intent.createChooser(share, title ?: "Share").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "media_store shareFile: $e")
                        result.error("share_failed", e.message ?: "share failed", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // Harici video oynatıcı: yüklü video oynatıcıları listeler ve seçilen
        // oynatıcıda akış URL'sini açar (VLC, MX Player, Just Player vb.).
        MethodChannel(messenger, "mina.device/external_player").setMethodCallHandler {
            call, result ->
            when (call.method) {
                "list" -> {
                    try {
                        result.success(listInstalledVideoPlayers())
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "external_player list: $e")
                        result.error("external_player_list_failed", e.message, null)
                    }
                }
                "launch" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val url = (args?.get("url") as? String)?.trim().orEmpty()
                        val pkg = (args?.get("packageName") as? String)?.trim().orEmpty()
                        val title = (args?.get("title") as? String)?.takeUnless { it.isEmpty() }
                        if (url.isEmpty()) {
                            result.error(
                                "external_player_invalid_url",
                                "url is required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        result.success(launchVideoIntent(url, pkg.ifEmpty { null }, title))
                    } catch (e: Throwable) {
                        Log.w("MainActivity", "external_player launch: $e")
                        result.error("external_player_launch_failed", e.message, null)
                    }
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

    private fun cancelPipDismissFinish() {
        awaitingPipCloseOrExpand = false
        pipDismissFinishRunnable?.let { pipExitHandler.removeCallbacks(it) }
        pipDismissFinishRunnable = null
    }

    private fun schedulePipDismissFinishIfStillBackground() {
        cancelPipDismissFinish()
        awaitingPipCloseOrExpand = true
        val r = Runnable {
            pipDismissFinishRunnable = null
            if (!awaitingPipCloseOrExpand) return@Runnable
            awaitingPipCloseOrExpand = false
            if (isFinishing || isDestroyed) return@Runnable
            // Tam ekrana genişletmede bu noktada activity zaten ön plandadır.
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) return@Runnable
            if (hasWindowFocus()) return@Runnable
            try {
                finishAffinity()
            } catch (e: Exception) {
                Log.w("MainActivity", "finishAffinity after PiP dismiss: $e")
            }
        }
        pipDismissFinishRunnable = r
        // PiP X ile kapatmada onResume gelmez; genişletmede gelir ve iptal edilir.
        pipExitHandler.postDelayed(r, 600L)
    }

    private fun notifyActivityBackgrounded() {
        try {
            activityLifecycleChannel?.invokeMethod("background", null)
        } catch (e: Exception) {
            Log.w("MainActivity", "activity background notify: $e")
        }
    }

    private fun notifyActivityForegrounded() {
        try {
            activityLifecycleChannel?.invokeMethod("foreground", null)
        } catch (e: Exception) {
            Log.w("MainActivity", "activity foreground notify: $e")
        }
    }

    override fun onResume() {
        if (wasInPictureInPicture) {
            pipExpandResumeBeforePipModeExit = true
        }
        cancelPipDismissFinish()
        super.onResume()
        applyPipAutoEnterParams()
        notifyActivityForegrounded()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            cancelPipDismissFinish()
        }
    }

    override fun onPause() {
        // PiP entry is now handled entirely by BetterPlayer package to avoid conflicts
        // Only notify Dart about background state
        super.onPause()
        if (!isChangingConfigurations && !isFinishing) {
            notifyActivityBackgrounded()
        }
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations && !isFinishing) {
            notifyActivityBackgrounded()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            wasInPictureInPicture = true
            pipExpandResumeBeforePipModeExit = false
            cancelPipDismissFinish()
            return
        }
        if (!wasInPictureInPicture) return
        wasInPictureInPicture = false

        val expandingToFullScreen =
            pipExpandResumeBeforePipModeExit ||
                lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) ||
                hasWindowFocus()
        pipExpandResumeBeforePipModeExit = false

        if (expandingToFullScreen) {
            cancelPipDismissFinish()
            // Notify Dart that we're returning from PiP to ensure proper UI state
            notifyActivityForegrounded()
            return
        }

        schedulePipDismissFinishIfStillBackground()
    }

    override fun onDestroy() {
        cancelPipDismissFinish()
        wasInPictureInPicture = false
        pipExpandResumeBeforePipModeExit = false
        releaseNativeEqualizer()
        super.onDestroy()
    }

    // =========================================================================
    // Native Equalizer: BetterPlayer (ExoPlayer) çıkışına bağlanır.
    // =========================================================================

    /**
     * Equalizer instance'ını kurar (yoksa) ve cihazın band/frekans bilgisini
     * döner. `supported=false` ise EQ uygulanamaz (Android 9+ session=0
     * kısıtı, eksik AudioFX servisi, vb.).
     */
    private fun ensureNativeEqualizerInfo(): Map<String, Any?> {
        val eq = obtainNativeEqualizer()
            ?: return mapOf(
                "supported" to false,
                "errorMessage" to "Equalizer unavailable on this device",
            )
        return try {
            val numBands = eq.numberOfBands.toInt()
            val range = eq.bandLevelRange
            val freqs = IntArray(numBands) { i ->
                try {
                    eq.getCenterFreq(i.toShort()).toInt()
                } catch (_: Throwable) {
                    0
                }
            }
            mapOf(
                "supported" to true,
                "numberOfBands" to numBands,
                "minLevelMb" to range[0].toInt(),
                "maxLevelMb" to range[1].toInt(),
                // Center frequencies in milliHertz; Dart side converts to Hz.
                "centerFreqMillihertz" to freqs.toList(),
            )
        } catch (e: Throwable) {
            Log.w("MainActivity", "equalizer ensureInfo: $e")
            mapOf(
                "supported" to false,
                "errorMessage" to (e.message ?: "info failed"),
            )
        }
    }

    /**
     * Bantları uygular ve EQ açık/kapalı durumunu ayarlar.
     * [bandLevelsMb] uzunluğu cihazın `numberOfBands` değerine eşit
     * olmalı; eşit değilse mevcut bantlar değiştirilmez (sadece
     * enabled state güncellenir).
     */
    private fun applyNativeEqualizer(enabled: Boolean, bandLevelsMb: List<Int>): Boolean {
        val eq = obtainNativeEqualizer() ?: return false
        return try {
            val numBands = eq.numberOfBands.toInt()
            if (bandLevelsMb.size == numBands) {
                val range = eq.bandLevelRange
                val minMb = range[0].toInt()
                val maxMb = range[1].toInt()
                for (i in 0 until numBands) {
                    val clamped =
                        bandLevelsMb[i].coerceIn(minMb, maxMb).toShort()
                    eq.setBandLevel(i.toShort(), clamped)
                }
            }
            if (eq.enabled != enabled) {
                eq.enabled = enabled
            }
            nativeEqualizerEnabled = enabled
            true
        } catch (e: Throwable) {
            Log.w("MainActivity", "equalizer apply: $e")
            false
        }
    }

    private fun obtainNativeEqualizer(): Equalizer? {
        val existing = nativeEqualizer
        if (existing != null) return existing
        return try {
            // priority=0 (en düşük öncelik — sistem önceliği ile çakışmaz)
            // sessionId=0 → global output mix. Android 9+ bazı cihazlarda
            // UnsupportedOperationException atar; o zaman null döner ve
            // Dart tarafı `supported=false` görür.
            val eq = Equalizer(0, 0)
            nativeEqualizer = eq
            // Default: disabled — Dart `apply` çağrısıyla aktif edilir.
            try { eq.enabled = false } catch (_: Throwable) {}
            eq
        } catch (e: Throwable) {
            Log.w("MainActivity", "equalizer init: $e")
            null
        }
    }

    private fun releaseNativeEqualizer() {
        val eq = nativeEqualizer ?: return
        try {
            try { eq.enabled = false } catch (_: Throwable) {}
            eq.release()
        } catch (e: Throwable) {
            Log.w("MainActivity", "equalizer release: $e")
        } finally {
            nativeEqualizer = null
            nativeEqualizerEnabled = false
        }
    }

    // =========================================================================
    // Harici Oynatıcı: yüklü video oynatıcı uygulamalarını listele ve aç.
    // =========================================================================

    /**
     * Sistemde [Intent.ACTION_VIEW] + video MIME türlerini işleyen tüm
     * uygulamaları döner. Kendi paketimiz hariç tutulur. Her giriş şu
     * alanlardan oluşur:
     * - `packageName`: paket adı (Intent.setPackage için kullanılır)
     * - `name`: kullanıcıya gösterilecek etiket (uygulama adı)
     * - `iconBase64`: 64×64 PNG (base64) — UI'da küçük rozet olarak kullanılır
     */
    private fun listInstalledVideoPlayers(): List<Map<String, Any?>> {
        val pm = packageManager
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any?>>()
        val ownPackage = packageName
        // Birden fazla MIME varyasyonu deniyoruz: bazı oynatıcılar yalnızca
        // `video/mp4` veya `application/x-mpegURL` gibi spesifik tipleri
        // işleyebiliyor; toplam küme kullanıcıya en geniş seçeneği sunar.
        val intents = listOf(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse("https://example.com/sample.mp4"), "video/*")
                addCategory(Intent.CATEGORY_BROWSABLE)
            },
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse("https://example.com/sample.m3u8"), "application/x-mpegURL")
                addCategory(Intent.CATEGORY_BROWSABLE)
            },
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse("https://example.com/sample.mp4"), "video/mp4")
                addCategory(Intent.CATEGORY_BROWSABLE)
            },
        )
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            PackageManager.ResolveInfoFlags.of(
                (PackageManager.MATCH_DEFAULT_ONLY or PackageManager.MATCH_ALL).toLong(),
            )
        } else {
            null
        }
        for (intent in intents) {
            val resolves: List<ResolveInfo> = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && flags != null) {
                    pm.queryIntentActivities(intent, flags)
                } else {
                    @Suppress("DEPRECATION")
                    pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                }
            } catch (e: Throwable) {
                Log.w("MainActivity", "queryIntentActivities: $e")
                emptyList()
            }
            for (info in resolves) {
                val pkg = info.activityInfo?.packageName ?: continue
                if (pkg == ownPackage) continue
                if (!seen.add(pkg)) continue
                val label = try {
                    info.loadLabel(pm).toString()
                } catch (_: Throwable) {
                    pkg
                }
                val iconBase64 = try {
                    drawableToPngBase64(info.loadIcon(pm))
                } catch (_: Throwable) {
                    null
                }
                out.add(
                    mapOf(
                        "packageName" to pkg,
                        "name" to label,
                        "iconBase64" to iconBase64,
                    ),
                )
            }
        }
        out.sortWith(
            compareBy(
                { (it["name"] as? String)?.lowercase(Locale.getDefault()) ?: "" },
            ),
        )
        return out
    }

    /**
     * [Intent.ACTION_VIEW] ile akış URL'sini açar. [packageName] verilmişse
     * o uygulama hedeflenir; verilmezse Android'in seçici ekranı çıkar
     * (kullanıcı hangi oynatıcıyı kullanmak istediğini seçer).
     */
    private fun launchVideoIntent(url: String, packageName: String?, title: String?): Boolean {
        val uri = Uri.parse(url)
        val mime = guessMimeType(uri)
        val baseIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            // Ana aktiviteden ayrılırken yeni görev üzerinde başlat.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (!title.isNullOrBlank()) {
                putExtra("title", title)
                putExtra("Title", title)
                // MX Player / Just Player gibi oynatıcılar bu extra'yı tanır.
                putExtra("displayName", title)
            }
        }
        return try {
            if (!packageName.isNullOrBlank()) {
                baseIntent.setPackage(packageName)
                startActivity(baseIntent)
            } else {
                // Sistem seçicisini göster — kullanıcı tek seferlik seçim yapsın.
                val chooser = Intent.createChooser(baseIntent, title ?: "Mina IPTV").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(chooser)
            }
            true
        } catch (e: ActivityNotFoundException) {
            Log.w("MainActivity", "external_player launch: ActivityNotFound ($packageName)")
            false
        } catch (e: SecurityException) {
            Log.w("MainActivity", "external_player launch: SecurityException ($packageName)")
            false
        } catch (e: Throwable) {
            Log.w("MainActivity", "external_player launch: $e")
            false
        }
    }

    // =========================================================================
    // MediaStore: Galeri'ye video kopyalama (Android 10+ scoped storage).
    // =========================================================================

    /**
     * Verilen dosyayı public `Movies/[subFolder]` altına kopyalar.
     * Android 10+ (Q) MediaStore.Video API'sini kullanır — `WRITE_EXTERNAL_STORAGE`
     * izni gerektirmez. Eski cihazlar (API ≤ 28) için MediaScannerConnection
     * ile mevcut dosyayı tarayıcıya bildirir (gerçek kopyalama yapılmaz).
     *
     * Döner: kopyalanan dosyanın public yolu (P+) veya orijinal yolu (P altı).
     */
    private fun saveVideoToGallery(
        srcPath: String,
        displayName: String,
        subFolder: String,
        mimeType: String,
    ): String? {
        val src = File(srcPath)
        if (!src.exists()) return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val srcSize = try { src.length() } catch (_: Throwable) { -1L }
            Log.i(
                "MainActivity",
                "saveVideoToGallery: src=$srcPath size=$srcSize mime=$mimeType " +
                    "target=${Environment.DIRECTORY_MOVIES}/$subFolder/$displayName",
            )
            if (srcSize <= 0L) {
                Log.w(
                    "MainActivity",
                    "saveVideoToGallery: source is empty (size=$srcSize); skipping copy",
                )
                return null
            }
            val resolver = contentResolver
            val collection = MediaStore.Video.Media.getContentUri(
                MediaStore.VOLUME_EXTERNAL_PRIMARY,
            )
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Video.Media.MIME_TYPE, mimeType)
                put(
                    MediaStore.Video.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/$subFolder",
                )
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val itemUri = resolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore insert returned null")
            try {
                var written = 0L
                resolver.openOutputStream(itemUri)?.use { out ->
                    FileInputStream(src).use { input ->
                        val buf = ByteArray(64 * 1024)
                        while (true) {
                            val n = input.read(buf)
                            if (n <= 0) break
                            out.write(buf, 0, n)
                            written += n
                        }
                        out.flush()
                    }
                } ?: throw IllegalStateException("openOutputStream returned null")
                values.clear()
                values.put(MediaStore.Video.Media.IS_PENDING, 0)
                resolver.update(itemUri, values, null, null)
                Log.i(
                    "MainActivity",
                    "saveVideoToGallery: success uri=$itemUri written=$written",
                )
                // Kullanıcı dostu yol bilgisi: Movies/<subFolder>/<name>
                return "${Environment.DIRECTORY_MOVIES}/$subFolder/$displayName"
            } catch (e: Throwable) {
                Log.w("MainActivity", "saveVideoToGallery copy failed: $e")
                // Hata: kaydı temizle
                try { resolver.delete(itemUri, null, null) } catch (_: Throwable) {}
                throw e
            }
        }

        // Android 9 ve altı: scoped storage öncesi davranış.
        // Sadece MediaScanner'a bildir; kullanıcı genelde Dosyalar uygulamasından
        // erişebilir. WRITE_EXTERNAL_STORAGE izni gerekir; manifestte
        // beyan edilmediyse buradan da çekemeyiz.
        MediaScannerConnection.scanFile(
            this,
            arrayOf(srcPath),
            arrayOf(mimeType),
            null,
        )
        return srcPath
    }

    private fun guessMimeForFile(path: String): String {
        val lower = path.lowercase(Locale.US)
        return when {
            lower.endsWith(".mp4") -> "video/mp4"
            lower.endsWith(".mkv") -> "video/x-matroska"
            lower.endsWith(".webm") -> "video/webm"
            lower.endsWith(".ts") -> "video/mp2t"
            lower.endsWith(".m4a") -> "audio/mp4"
            lower.endsWith(".mp3") -> "audio/mpeg"
            else -> "video/*"
        }
    }

    private fun extensionOrFallback(path: String): String {
        val ix = path.lastIndexOf('.')
        if (ix < 0 || ix >= path.length - 1) return ".mp4"
        return path.substring(ix).lowercase(Locale.US)
    }

    private fun guessMimeType(uri: Uri): String {
        val path = (uri.path ?: "").lowercase(Locale.US)
        return when {
            path.endsWith(".m3u8") -> "application/x-mpegURL"
            path.endsWith(".mpd") -> "application/dash+xml"
            path.endsWith(".ts") -> "video/mp2t"
            path.endsWith(".mp4") -> "video/mp4"
            path.endsWith(".mkv") -> "video/x-matroska"
            path.endsWith(".webm") -> "video/webm"
            path.endsWith(".avi") -> "video/x-msvideo"
            path.endsWith(".mov") -> "video/quicktime"
            else -> "video/*"
        }
    }

    private fun drawableToPngBase64(drawable: Drawable?): String? {
        if (drawable == null) return null
        val width = (drawable.intrinsicWidth.takeIf { it > 0 } ?: 96).coerceAtMost(192)
        val height = (drawable.intrinsicHeight.takeIf { it > 0 } ?: 96).coerceAtMost(192)
        val bmp: Bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            // Çok büyük orijinaller için yeniden ölçekle.
            val src = drawable.bitmap
            if (src.width <= 192 && src.height <= 192) {
                src
            } else {
                val ratio = 192f / maxOf(src.width, src.height)
                Bitmap.createScaledBitmap(
                    src,
                    (src.width * ratio).toInt().coerceAtLeast(1),
                    (src.height * ratio).toInt().coerceAtLeast(1),
                    true,
                )
            }
        } else {
            val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(canvas)
            out
        }
        val baos = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 90, baos)
        return Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
    }
}
