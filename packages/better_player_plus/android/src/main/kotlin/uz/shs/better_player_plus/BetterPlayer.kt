package uz.shs.better_player_plus

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import uz.shs.better_player_plus.DataSourceUtils.getUserAgent
import uz.shs.better_player_plus.DataSourceUtils.isHTTP
import uz.shs.better_player_plus.DataSourceUtils.getDataSourceFactory
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry.SurfaceProducer
import io.flutter.plugin.common.MethodChannel
import androidx.media3.ui.PlayerNotificationManager
import androidx.work.WorkManager
import androidx.work.WorkInfo
import androidx.media3.ui.PlayerNotificationManager.MediaDescriptionAdapter
import androidx.media3.ui.PlayerNotificationManager.BitmapCallback
import androidx.work.OneTimeWorkRequest
import android.util.Log
import androidx.annotation.OptIn
import androidx.lifecycle.Observer
import androidx.media3.extractor.DefaultExtractorsFactory
import io.flutter.plugin.common.EventChannel.EventSink
import androidx.work.Data
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.Tracks
import androidx.media3.common.text.Cue
import androidx.media3.common.text.CueGroup
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.LoadControl
import androidx.media3.exoplayer.RendererCapabilities
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.dash.DefaultDashChunkSource
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider
import androidx.media3.exoplayer.drm.DummyExoMediaDrm
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import androidx.media3.exoplayer.drm.LocalMediaDrmCallback
import androidx.media3.exoplayer.drm.UnsupportedDrmException
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.smoothstreaming.DefaultSsChunkSource
import androidx.media3.exoplayer.smoothstreaming.SsMediaSource
import androidx.media3.exoplayer.source.ClippingMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.trackselection.MappingTrackSelector.MappedTrackInfo
import java.io.File
import java.util.Objects
import java.lang.Exception
import java.lang.IllegalStateException
import java.util.*
import kotlin.math.max
import kotlin.math.min
import androidx.core.net.toUri

/**
 * ExoPlayer dahili olarak ayrı oynatma iş parçacıkları kullanır; [Player.Listener]
 * geri çağrıları varsayılan olarak oluşturma [Looper] üzerindedir (çoğu embeding’de ana iş parçacığı).
 * Oynatıcıyı ayrı bir [HandlerThread]’e almak, MethodChannel üzerinden senkron
 * [position] okuması yapan mevcut eklenti sözleşmesiyle uyumsuz olur (ana iş parçacığını kilitlemeden).
 * UI yükü: Flutter tarafında pozisyon bildirimleri seyrekleştirildi ([VideoPlayerController]).
 */
@UnstableApi
internal class BetterPlayer(
    context: Context,
    private val eventChannel: EventChannel,
    private val surfaceProducer: SurfaceProducer,
    customDefaultLoadControl: CustomDefaultLoadControl?,
    preferSoftwareVideoDecoder: Boolean,
    /** Tablet/TV düzeninde OSD [BoxFit] döngüsü için Exo FIT ölçeklemesi. */
    private val androidScaleVideoToFit: Boolean,
    result: MethodChannel.Result
) : SurfaceProducer.Callback {
    private val isAndroidTv: Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK) ==
            Configuration.UI_MODE_TYPE_TELEVISION

    /** Xiaomi / Redmi / POCO: MIUI’de tünel senkronu ve zamanlama ile kare kare takılma raporları. */
    private val isXiaomiFamilyDevice: Boolean = run {
        val m = Build.MANUFACTURER.lowercase(Locale.US)
        val b = Build.BRAND.lowercase(Locale.US)
        listOf("xiaomi", "redmi", "poco", "black shark").any { x ->
            m.contains(x) || b.contains(x)
        }
    }

    /**
     * Telefon / tablet: aynı kapsayıcıda stereo + surround varsa stereo öncelikli (ExoPlayer yazılım downmix yapmaz).
     * TV: çok kanallı çıkış genelde mevcut; varsayılan kalite sıralamasına bırakılır.
     */
    private val preferStereoEmbeddedWhenMultipleTracks: Boolean = !isAndroidTv

    private val exoPlayer: ExoPlayer?
    private val eventSink = QueuingEventSink()
    private val trackSelector: DefaultTrackSelector = DefaultTrackSelector(context)
    private val loadControl: LoadControl
    private var isInitialized = false

    /** [emitVideoFormatUpdateIfChanged] için; yeni kaynak / parça değişince sıfırlanır. */
    private var lastEmittedVideoFormatSig: Int = 0
    /** ExoPlayer henüz yüzey almadıysa (SurfaceProducer gecikmeli sağlayabilir). */
    private var needsSurface = true
    private var key: String? = null
    private var playerNotificationManager: PlayerNotificationManager? = null
    private var refreshHandler: Handler? = null
    private var refreshRunnable: Runnable? = null
    private var exoPlayerEventListener: Player.Listener? = null
    private var bitmap: Bitmap? = null
    private var mediaSession: MediaSessionCompat? = null
    private var drmSessionManager: DrmSessionManager? = null
    private val workManager: WorkManager
    private val workerObserverMap: HashMap<UUID, Observer<WorkInfo?>>
    private val customDefaultLoadControl: CustomDefaultLoadControl =
        customDefaultLoadControl ?: CustomDefaultLoadControl()
    private var lastSendBufferedPosition = 0L
    /** Xiaomi/telefon: parça haritası geldikten sonra desteklenen ses codec'ini birkaç kez dene. */
    private var audioAutoSelectPassesLeft = 0

    init {
        val loadBuilder = DefaultLoadControl.Builder()
        loadBuilder.setBufferDurationsMs(
            this.customDefaultLoadControl.minBufferMs,
            this.customDefaultLoadControl.maxBufferMs,
            this.customDefaultLoadControl.bufferForPlaybackMs,
            this.customDefaultLoadControl.bufferForPlaybackAfterRebufferMs
        )
        loadBuilder.setPrioritizeTimeOverSizeThresholds(
            this.customDefaultLoadControl.prioritizeTimeOverSizeThresholds,
        )
        loadControl = loadBuilder.build()
        val mediaCodecSelector =
            if (preferSoftwareVideoDecoder) {
                MediaCodecSelector.PREFER_SOFTWARE
            } else {
                // Donanım (MediaCodec) öncelikli; DEFAULT cihaz codec sıralamasını uygular.
                MediaCodecSelector.DEFAULT
            }
        // Resmi media3 `decoder_ffmpeg` modülü (AAR) classpath’teyse FfmpegAudioRenderer devreye girer.
        // Google Maven’da yayınlanmaz; Jellyfin Maven’ı kullanmadan androidx/media deposundan derlenmiş AAR
        // better_player_plus/android/third_party/decoder_ffmpeg/ altına konabilir (README.txt).
        //
        // TV kutusu: FFmpeg JNI sık sorun çıkarır → OFF.
        // Telefon / tablet: [EXTENSION_RENDERER_MODE_PREFER] — ses için yazılım (FFmpeg) çözücüyü
        // donanım (MediaCodec) önüne alır; Xiaomi MIUI/HyperOS AC3/EAC3/DTS sessizliklerinde hedeflenen davranış.
        val extensionRendererMode: Int =
            if (isAndroidTv) {
                DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF
            } else {
                DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER
            }
        // TV kutusu: KEY_LOW_LATENCY + senkron MediaCodec kuyruğu bazı 1080p donanım
        // kod çözücülerinde kare atlama / takılma raporu veriyor; telefon/tablette tutulur.
        val enableLowLatencyPath =
            !isAndroidTv &&
                !preferSoftwareVideoDecoder &&
                MinaLowLatencyMediaCodecAdapterFactory.shouldEnableLowLatencyHeuristics()
        // [DefaultRenderersFactory] + uzantı modu: ses için FFmpeg (varsa) tercih sırası.
        val renderersFactory =
            object : DefaultRenderersFactory(context) {
                override fun getCodecAdapterFactory(): MediaCodecAdapter.Factory {
                    return if (enableLowLatencyPath) {
                        MinaLowLatencyMediaCodecAdapterFactory(context, true)
                    } else {
                        super.getCodecAdapterFactory()
                    }
                }
            }.setExtensionRendererMode(extensionRendererMode)
                .setMediaCodecSelector(mediaCodecSelector)
                .setEnableDecoderFallback(true)
                // AudioTrack#setPlaybackParams (Media3 1.8: setEnableAudioTrackPlaybackParams) —
                // A/V zamanlaması için; Xiaomi’de kare kare senkron sorunlarına karşı açık tutulur.
                .setEnableAudioTrackPlaybackParams(true)
                .apply {
                    if (enableLowLatencyPath) {
                        // Düşük gecikme: senkron MediaCodec kuyruğu (desteklenen cihazlarda).
                        forceDisableMediaCodecAsynchronousQueueing()
                    }
                }
        // Prefer device-friendly codecs first so phones (e.g. Xiaomi) pick AAC/MP3 when
        // muxed MP4/MKV exposes AC3/EAC3 alongside AAC; TV boxes often work either way.
        // Donanım tüneli (video+audio): Xiaomi ailesinde özellikle kapatılır; TV/STB’de de varsayılan kapalı.
        val allowExoTunnelingExperiment = false
        val tunnelingEnabled = allowExoTunnelingExperiment && !isXiaomiFamilyDevice
        trackSelector.setParameters(
            trackSelector.buildUponParameters()
                .setTunnelingEnabled(tunnelingEnabled)
                .setPreferredAudioMimeTypes(
                    MimeTypes.AUDIO_AAC,
                    MimeTypes.AUDIO_MPEG,
                    MimeTypes.AUDIO_OPUS,
                    MimeTypes.AUDIO_VORBIS,
                    MimeTypes.AUDIO_FLAC,
                    MimeTypes.AUDIO_AC4,
                    MimeTypes.AUDIO_AC3,
                    MimeTypes.AUDIO_E_AC3,
                    MimeTypes.AUDIO_E_AC3_JOC,
                    MimeTypes.AUDIO_DTS,
                    MimeTypes.AUDIO_DTS_HD,
                    MimeTypes.AUDIO_DTS_EXPRESS,
                )
                // Cihaz çıkışı / Spatializer: surround uygun değilse seçici çok kanallıyı "kısıt dışı" sayar;
                // stereo parça varsa veya exceedAudioConstraints ile uygun düşük kanallı alternatif tercih edilir.
                .setConstrainAudioChannelCountToDeviceCapabilities(true)
                // HLS/DASH vb. adaptif sette farklı kanal sayılı ses varyantları arasında geçişe izin verir.
                .setAllowAudioMixedChannelCountAdaptiveness(true)
                // 2 = yalnızca stereo seçilebilir → tek 5.1 parçası tamamen elenir (sessizlik riski).
                // 8 = çok kanallı aday kalır; [tryAutoSelectSupportedAudioTrack] çoklu parçada stereo öne alır.
                .setMaxAudioChannelCount(8)
                .setAudioOffloadPreferences(
                    TrackSelectionParameters.AudioOffloadPreferences.Builder()
                        .setAudioOffloadMode(
                            TrackSelectionParameters.AudioOffloadPreferences.AUDIO_OFFLOAD_MODE_DISABLED,
                        )
                        .build(),
                )
                .build(),
        )
        // setPriority(1) KULLANILMAMALI: Media3'te varsayılan -1000 (C.PRIORITY_PLAYBACK). 1 = oynatma önceliğini düşürür.
        val scalingMode =
            if (isAndroidTv || androidScaleVideoToFit) {
                C.VIDEO_SCALING_MODE_SCALE_TO_FIT
            } else {
                C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING
            }
        exoPlayer = ExoPlayer.Builder(context)
            .setRenderersFactory(renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .setVideoScalingMode(scalingMode)
            .build()
        maybeLogFfmpegMinaHint()
        workManager = WorkManager.getInstance(context)
        workerObserverMap = HashMap()
        setupVideoPlayer(eventChannel, result)
    }

    /**
     * Media3 [DefaultRenderersFactory] zaten [EXTENSION_RENDERER_MODE_PREFER] ile FFmpeg ses (+ classpath’te
     * [ExperimentalFfmpegVideoRenderer]) yüklemeyi dener; AAR/jni eksikse Xiaomi’de teşhis için uyarı.
     */
    private fun maybeLogFfmpegMinaHint() {
        if (isAndroidTv || !isXiaomiFamilyDevice) return
        try {
            val clazz = Class.forName("androidx.media3.decoder.ffmpeg.FfmpegLibrary")
            val ok = clazz.getMethod("isAvailable").invoke(null) as Boolean
            if (!ok) {
                Log.w(
                    TAG,
                    "FFmpeg native kütüphane yok (isAvailable=false); decoder_ffmpeg AAR ve jni ABI kontrol edin.",
                )
            }
        } catch (_: ClassNotFoundException) {
            Log.w(
                TAG,
                "FFmpeg AAR classpath’te yok — third_party/decoder_ffmpeg/README.txt (ses; video için h264/hevc decoder derlemesi).",
            )
        } catch (e: Exception) {
            Log.w(TAG, "FFmpeg kullanılabilirlik: $e")
        }
    }

    override fun onSurfaceAvailable() {
        if (needsSurface) {
            Log.d(
                SURFACE_LOG_TAG,
                "onSurfaceAvailable textureId=${surfaceProducer.id()} attaching Surface to ExoPlayer",
            )
            exoPlayer?.setVideoSurface(surfaceProducer.surface)
            needsSurface = false
        }
    }

    override fun onSurfaceCleanup() {
        Log.d(
            SURFACE_LOG_TAG,
            "onSurfaceCleanup textureId=${surfaceProducer.id()} ExoPlayer surface detached (buffer may still hold refs until release)",
        )
        exoPlayer?.setVideoSurface(null)
        needsSurface = true
    }

    @OptIn(UnstableApi::class)
    fun setDataSource(
        context: Context,
        key: String?,
        dataSource: String?,
        formatHint: String?,
        result: MethodChannel.Result,
        headers: Map<String, String>?,
        useCache: Boolean,
        maxCacheSize: Long,
        maxCacheFileSize: Long,
        overriddenDuration: Long,
        licenseUrl: String?,
        drmHeaders: Map<String, String>?,
        cacheKey: String?,
        clearKey: String?
    ) {
        this.key = key
        audioAutoSelectPassesLeft = 5
        isInitialized = false
        lastEmittedVideoFormatSig = 0
        Log.d(
            SURFACE_LOG_TAG,
            "setDataSource textureId=${surfaceProducer.id()}: stop+clearMediaItems+new MediaSource (SurfaceProducer unchanged)",
        )
        val uri = dataSource?.toUri()
        var dataSourceFactory: DataSource.Factory?
        val userAgent = getUserAgent(headers)
        if (!licenseUrl.isNullOrEmpty()) {
            val httpMediaDrmCallback =
                HttpMediaDrmCallback(licenseUrl, DefaultHttpDataSource.Factory())
            if (drmHeaders != null) {
                for ((drmKey, drmValue) in drmHeaders) {
                    httpMediaDrmCallback.setKeyRequestProperty(drmKey, drmValue)
                }
            }
            val drmSchemeUuid = Util.getDrmUuid("widevine")
            if (drmSchemeUuid != null) {
                drmSessionManager = DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(
                        drmSchemeUuid
                    ) { uuid: UUID? ->
                        try {
                            val mediaDrm = FrameworkMediaDrm.newInstance(uuid!!)
                            // Force L3.
                            mediaDrm.setPropertyString("securityLevel", "L3")
                            return@setUuidAndExoMediaDrmProvider mediaDrm
                        } catch (_: UnsupportedDrmException) {
                            return@setUuidAndExoMediaDrmProvider DummyExoMediaDrm()
                        }
                    }
                    .setMultiSession(false)
                    .build(httpMediaDrmCallback)
            }
        } else if (!clearKey.isNullOrEmpty()) {
            DefaultDrmSessionManager.Builder()
                .setUuidAndExoMediaDrmProvider(
                    C.CLEARKEY_UUID,
                    FrameworkMediaDrm.DEFAULT_PROVIDER
                ).build(LocalMediaDrmCallback(clearKey.toByteArray()))
        } else {
            drmSessionManager = null
        }
        if (isHTTP(uri)) {
            dataSourceFactory = getDataSourceFactory(userAgent, headers)
            if (useCache && maxCacheSize > 0 && maxCacheFileSize > 0) {
                dataSourceFactory = CacheDataSourceFactory(
                    context,
                    maxCacheSize,
                    maxCacheFileSize,
                    dataSourceFactory
                )
            }
        } else {
            dataSourceFactory = DefaultDataSource.Factory(context)
        }
        val mediaSource = buildMediaSource(uri, dataSourceFactory, formatHint, cacheKey, context)
        // Tek Exo örneği üzerinde kanal değişimi: tampon/playlist temizliği + yeni kaynak (bellek şişmesini azaltır).
        exoPlayer?.stop()
        exoPlayer?.clearMediaItems()
        if (overriddenDuration != 0L) {
            val clippingMediaSource = ClippingMediaSource.Builder(mediaSource)
                .setStartPositionMs(0)
                .setEndPositionMs(overriddenDuration * 1000)
                .build()
            exoPlayer?.setMediaSource(clippingMediaSource)
        } else {
            exoPlayer?.setMediaSource(mediaSource)
        }
        exoPlayer?.prepare()
        result.success(null)
    }

    fun setupPlayerNotification(
        context: Context, title: String, author: String?,
        imageUrl: String?, notificationChannelName: String?,
        activityName: String
    ) {
        val mediaDescriptionAdapter: MediaDescriptionAdapter = object : MediaDescriptionAdapter {
            override fun getCurrentContentTitle(player: Player): String {
                return title
            }

            @SuppressLint("UnspecifiedImmutableFlag")
            override fun createCurrentContentIntent(player: Player): PendingIntent? {
                val packageName = context.applicationContext.packageName
                val notificationIntent = Intent()
                notificationIntent.setClassName(
                    packageName,
                    "$packageName.$activityName"
                )
                notificationIntent.flags = (Intent.FLAG_ACTIVITY_CLEAR_TOP
                        or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                return PendingIntent.getActivity(
                    context, 0,
                    notificationIntent,
                    PendingIntent.FLAG_IMMUTABLE
                )
            }

            override fun getCurrentContentText(player: Player): String? {
                return author
            }

            override fun getCurrentLargeIcon(
                player: Player,
                callback: BitmapCallback
            ): Bitmap? {
                if (imageUrl == null) {
                    return null
                }
                if (bitmap != null) {
                    return bitmap
                }
                val imageWorkRequest = OneTimeWorkRequest.Builder(ImageWorker::class.java)
                    .addTag(imageUrl)
                    .setInputData(
                        Data.Builder()
                            .putString(BetterPlayerPlugin.URL_PARAMETER, imageUrl)
                            .build()
                    )
                    .build()
                workManager.enqueue(imageWorkRequest)
                val workInfoObserver = Observer { workInfo: WorkInfo? ->
                    try {
                        if (workInfo != null) {
                            val state = workInfo.state
                            if (state == WorkInfo.State.SUCCEEDED) {
                                val outputData = workInfo.outputData
                                val filePath =
                                    outputData.getString(BetterPlayerPlugin.FILE_PATH_PARAMETER)
                                //Bitmap here is already processed and it's very small, so it won't
                                //break anything.
                                bitmap = BitmapFactory.decodeFile(filePath)
                                bitmap?.let { bitmap ->
                                    callback.onBitmap(bitmap)
                                }
                            }
                            if (state == WorkInfo.State.SUCCEEDED || state == WorkInfo.State.CANCELLED || state == WorkInfo.State.FAILED) {
                                val uuid = imageWorkRequest.id
                                val observer = workerObserverMap.remove(uuid)
                                if (observer != null) {
                                    workManager.getWorkInfoByIdLiveData(uuid)
                                        .removeObserver(observer)
                                }
                            }
                        }
                    } catch (exception: Exception) {
                        Log.e(TAG, "Image select error: $exception")
                    }
                }
                val workerUuid = imageWorkRequest.id
                workManager.getWorkInfoByIdLiveData(workerUuid)
                    .observeForever(workInfoObserver)
                workerObserverMap[workerUuid] = workInfoObserver
                return null
            }
        }
        var playerNotificationChannelName = notificationChannelName
        if (notificationChannelName == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val importance = NotificationManager.IMPORTANCE_LOW
                val channel = NotificationChannel(
                    DEFAULT_NOTIFICATION_CHANNEL,
                    DEFAULT_NOTIFICATION_CHANNEL, importance
                )
                channel.description = DEFAULT_NOTIFICATION_CHANNEL
                val notificationManager = context.getSystemService(
                    NotificationManager::class.java
                )
                notificationManager.createNotificationChannel(channel)
                playerNotificationChannelName = DEFAULT_NOTIFICATION_CHANNEL
            }
        }

        playerNotificationManager = PlayerNotificationManager.Builder(
            context, NOTIFICATION_ID,
            playerNotificationChannelName!!
        ).setMediaDescriptionAdapter(mediaDescriptionAdapter).build()

        playerNotificationManager?.apply {

            exoPlayer?.let {
                setPlayer(ForwardingPlayer(exoPlayer))
                setUseNextAction(false)
                setUsePreviousAction(false)
                setUseStopAction(false)
            }
        }

        refreshHandler = Handler(Looper.getMainLooper())
        refreshRunnable = Runnable {
            val playbackState: PlaybackStateCompat = if (exoPlayer?.isPlaying == true) {
                PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_SEEK_TO)
                    .setState(PlaybackStateCompat.STATE_PLAYING, position, 1.0f)
                    .build()
            } else {
                PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_SEEK_TO)
                    .setState(PlaybackStateCompat.STATE_PAUSED, position, 1.0f)
                    .build()
            }
            mediaSession?.setPlaybackState(playbackState)
            refreshHandler?.postDelayed(refreshRunnable!!, 1000)
        }
        refreshHandler?.postDelayed(refreshRunnable!!, 0)
        exoPlayerEventListener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                mediaSession?.setMetadata(
                    MediaMetadataCompat.Builder()
                        .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, getDuration())
                        .build()
                )
            }
        }
        exoPlayerEventListener?.let { exoPlayerEventListener ->
            exoPlayer?.addListener(exoPlayerEventListener)
        }
        exoPlayer?.seekTo(0)
    }

    fun disposeRemoteNotifications() {
        exoPlayerEventListener?.let { exoPlayerEventListener ->
            exoPlayer?.removeListener(exoPlayerEventListener)
        }
        if (refreshHandler != null) {
            refreshHandler?.removeCallbacksAndMessages(null)
            refreshHandler = null
            refreshRunnable = null
        }
        if (playerNotificationManager != null) {
            playerNotificationManager?.setPlayer(null)
        }
        bitmap = null
    }

    private fun buildMediaSource(
        uri: Uri?,
        mediaDataSourceFactory: DataSource.Factory,
        formatHint: String?,
        cacheKey: String?,
        context: Context
    ): MediaSource {
        val type: Int
        if (formatHint == null) {
            var lastPathSegment = uri?.lastPathSegment
            if (lastPathSegment == null) {
                lastPathSegment = ""
            }
            type = Util.inferContentTypeForExtension(lastPathSegment.split(".")[1])
        } else {
            type = when (formatHint) {
                FORMAT_SS -> C.CONTENT_TYPE_SS
                FORMAT_DASH -> C.CONTENT_TYPE_DASH
                FORMAT_HLS -> C.CONTENT_TYPE_HLS
                FORMAT_OTHER -> C.CONTENT_TYPE_OTHER
                else -> -1
            }
        }
        val mediaItemBuilder = MediaItem.Builder()
        mediaItemBuilder.setUri(uri)
        if (!cacheKey.isNullOrEmpty()) {
            mediaItemBuilder.setCustomCacheKey(cacheKey)
        }
        val mediaItem = mediaItemBuilder.build()
        val drmSessionManagerProvider: DrmSessionManagerProvider? = drmSessionManager?.let { drmSessionManager ->
            DrmSessionManagerProvider { drmSessionManager }
        }

        return when (type) {
            C.CONTENT_TYPE_SS -> SsMediaSource.Factory(
                DefaultSsChunkSource.Factory(mediaDataSourceFactory),
                DefaultDataSource.Factory(context, mediaDataSourceFactory)
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider)
                }
            }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_DASH -> DashMediaSource.Factory(
                DefaultDashChunkSource.Factory(mediaDataSourceFactory),
                DefaultDataSource.Factory(context, mediaDataSourceFactory)
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider)
                }
            }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_HLS -> HlsMediaSource.Factory(mediaDataSourceFactory)
                .apply {
                    if (drmSessionManagerProvider != null) {
                        setDrmSessionManagerProvider(drmSessionManagerProvider)
                    }
                }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_OTHER -> ProgressiveMediaSource.Factory(
                mediaDataSourceFactory,
                DefaultExtractorsFactory()
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider)
                }
            }.createMediaSource(mediaItem)

            else -> {
                throw IllegalStateException("Unsupported type: $type")
            }
        }
    }

    private fun setupVideoPlayer(
        eventChannel: EventChannel, result: MethodChannel.Result
    ) {
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(o: Any?, sink: EventSink) {
                    eventSink.setDelegate(sink)
                }

                override fun onCancel(o: Any?) {
                    eventSink.setDelegate(null)
                }
            },
        )
        // SurfaceProducer: ImageReader / donanım tamponu yolu (SurfaceTexture yerine); Flutter Impeller/Vulkan uyumu.
        surfaceProducer.setCallback(this)
        val surf = surfaceProducer.surface
        exoPlayer?.setVideoSurface(surf)
        needsSurface = surf == null
        setAudioAttributes(exoPlayer, true)
        exoPlayer?.addListener(object : Player.Listener {
            override fun onTracksChanged(tracks: Tracks) {
                tryAutoSelectSupportedAudioTrack()
                emitVideoFormatUpdateIfChanged()
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                emitVideoFormatUpdateIfChanged()
            }

            override fun onRenderedFirstFrame() {
                emitVideoFormatUpdateIfChanged()
            }

            override fun onCues(cueGroup: CueGroup) {
                sendExoEmbeddedCuesToFlutter(cueGroup)
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_BUFFERING -> {
                        sendBufferingUpdate(true)
                        val event: MutableMap<String, Any> = HashMap()
                        event["event"] = "bufferingStart"
                        eventSink.success(event)
                    }

                    Player.STATE_READY -> {
                        tryAutoSelectSupportedAudioTrack()
                        emitVideoFormatUpdateIfChanged()
                        if (!isInitialized) {
                            isInitialized = true
                            sendInitialized()
                        }
                        val event: MutableMap<String, Any> = HashMap()
                        event["event"] = "bufferingEnd"
                        eventSink.success(event)
                    }

                    Player.STATE_ENDED -> {
                        val event: MutableMap<String, Any?> = HashMap()
                        event["event"] = "completed"
                        event["key"] = key
                        eventSink.success(event)
                    }

                    Player.STATE_IDLE -> {
                        //no-op
                    }
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                eventSink.error("VideoError", "Video player had error $error", "")
            }
        })
        val reply: MutableMap<String, Any> = HashMap()
        reply["textureId"] = surfaceProducer.id()
        result.success(reply)
    }

    /**
     * Gömülü metin izleri (MKV/MP4/TS içi): Flutter [BetterPlayerSubtitlesDrawer] ile çizilir.
     * [Cue] süreleri bazı konteynerlerde yok; [CueGroup.presentationTimeUs] ve oynatıcı pozisyonu kullanılır.
     */
    private fun sendExoEmbeddedCuesToFlutter(cueGroup: CueGroup) {
        val player = exoPlayer ?: return
        var baseUs = cueGroup.presentationTimeUs
        if (baseUs == C.TIME_UNSET) {
            baseUs = Util.msToUs(player.currentPosition.coerceAtLeast(0L))
        }
        val list = ArrayList<Map<String, Any>>(cueGroup.cues.size)
        val defaultEndUs = baseUs + Util.msToUs(8_000L)
        for (i in 0 until cueGroup.cues.size) {
            val cue: Cue = cueGroup.cues[i]
            val text = cue.text?.toString()?.trim() ?: continue
            if (text.isEmpty()) continue
            list.add(
                mapOf(
                    "startMs" to Util.usToMs(baseUs),
                    "endMs" to Util.usToMs(defaultEndUs),
                    "text" to text,
                ),
            )
        }
        val event: MutableMap<String, Any> = HashMap(2)
        event["event"] = "exoEmbeddedCues"
        event["cues"] = list
        eventSink.success(event)
    }

    fun sendBufferingUpdate(isFromBufferingStart: Boolean) {
        val bufferedPosition = exoPlayer?.bufferedPosition ?: 0L
        if (isFromBufferingStart || bufferedPosition != lastSendBufferedPosition) {
            val event: MutableMap<String, Any> = HashMap()
            event["event"] = "bufferingUpdate"
            val range: List<Number?> = listOf(0, bufferedPosition)
            // iOS supports a list of buffered ranges, so here is a list with a single range.
            event["values"] = listOf(range)
            eventSink.success(event)
            lastSendBufferedPosition = bufferedPosition
        }
    }

    @Suppress("DEPRECATION")
    private fun setAudioAttributes(exoPlayer: ExoPlayer?, mixWithOthers: Boolean) {
        exoPlayer?.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build(),
            !mixWithOthers
        )
    }

    fun play() {
        exoPlayer?.playWhenReady = true
    }

    fun pause() {
        exoPlayer?.playWhenReady = false
    }

    fun stopPlayback() {
        if (isInitialized) {
            exoPlayer?.stop()
        }
        exoPlayer?.playWhenReady = false
    }

    fun setLooping(value: Boolean) {
        exoPlayer?.repeatMode = if (value) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF
    }

    fun setVolume(value: Double) {
        val bracketedValue = max(0.0, min(1.0, value))
            .toFloat()
        exoPlayer?.volume = bracketedValue
    }

    fun setSpeed(value: Double) {
        val bracketedValue = value.toFloat()
        val playbackParameters = PlaybackParameters(bracketedValue)
        exoPlayer?.playbackParameters = playbackParameters
    }

    fun setTrackParameters(width: Int, height: Int, bitrate: Int) {
        val parametersBuilder = trackSelector.buildUponParameters()
        if (width != 0 && height != 0) {
            parametersBuilder.setMaxVideoSize(width, height)
        }
        if (bitrate != 0) {
            parametersBuilder.setMaxVideoBitrate(bitrate)
        }
        if (width == 0 && height == 0 && bitrate == 0) {
            parametersBuilder.clearVideoSizeConstraints()
            parametersBuilder.setMaxVideoBitrate(Int.MAX_VALUE)
        }
        trackSelector.setParameters(parametersBuilder)
    }

    fun seekTo(location: Int) {
        exoPlayer?.seekTo(location.toLong())
    }

    val position: Long
        get() = exoPlayer?.currentPosition ?: 0L

    val absolutePosition: Long
        get() {
            exoPlayer?.let { player ->
                val timeline = player.currentTimeline
                if (!timeline.isEmpty) {
                    val windowStartTimeMs =
                        timeline.getWindow(0, Timeline.Window()).windowStartTimeMs
                    val pos = player.currentPosition
                    return windowStartTimeMs + pos
                }
            }
            return exoPlayer?.currentPosition ?: 0L
        }

    private fun sendInitialized() {
        if (isInitialized) {
            val event: MutableMap<String, Any?> = HashMap()
            event["event"] = "initialized"
            event["key"] = key
            event["duration"] = getDuration()
            exoPlayer?.let { player ->
                player.videoFormat?.let { videoFormat ->
                    var width = videoFormat.width
                    var height = videoFormat.height
                    val rotationDegrees = videoFormat.rotationDegrees
                    // Switch the width/height if video was taken in portrait mode
                    if (rotationDegrees == 90 || rotationDegrees == 270) {
                        width = videoFormat.height
                        height = videoFormat.width
                    }
                    event["width"] = width
                    event["height"] = height
                    val fr = videoFormat.frameRate
                    if (!fr.isNaN() && fr > 0f) {
                        event["frameRate"] = fr.toDouble()
                    }
                }
            }
            eventSink.success(event)
        }
    }

    /** İlk kare / parça değişimi sonrası FPS güncellemesi (manifestte yoksa bile decoder Format dolabilir). */
    private fun emitVideoFormatUpdateIfChanged() {
        val player = exoPlayer ?: return
        val videoFormat = player.videoFormat ?: return
        var width = videoFormat.width
        var height = videoFormat.height
        val rotationDegrees = videoFormat.rotationDegrees
        if (rotationDegrees == 90 || rotationDegrees == 270) {
            width = videoFormat.height
            height = videoFormat.width
        }
        if (width <= 0 || height <= 0) {
            return
        }
        val fr = videoFormat.frameRate
        val frKey = if (fr.isNaN() || fr <= 0f) 0 else (fr * 1000f).toInt()
        val sig = Objects.hash(width, height, frKey)
        if (sig == lastEmittedVideoFormatSig) {
            return
        }
        lastEmittedVideoFormatSig = sig
        val event: MutableMap<String, Any?> = HashMap()
        event["event"] = "videoFormat"
        event["key"] = key
        event["width"] = width
        event["height"] = height
        if (frKey > 0) {
            event["frameRate"] = fr.toDouble()
        }
        eventSink.success(event)
    }

    private fun getDuration(): Long = exoPlayer?.duration ?: 0L

    private fun mimePreferenceScore(mime: String?): Int {
        if (mime.isNullOrEmpty()) return 0
        return when {
            mime == MimeTypes.AUDIO_AAC || mime.contains("mp4a", ignoreCase = true) -> 100
            mime == MimeTypes.AUDIO_MPEG || mime.contains("mpeg", ignoreCase = true) -> 92
            mime == MimeTypes.AUDIO_OPUS -> 88
            mime == MimeTypes.AUDIO_VORBIS -> 84
            mime == MimeTypes.AUDIO_FLAC -> 80
            mime == MimeTypes.AUDIO_AC4 -> 55
            mime.contains("ac-3", ignoreCase = true) ||
                mime.contains("eac3", ignoreCase = true) ||
                mime.contains("/ac3", ignoreCase = true) -> 25
            mime.contains("dts", ignoreCase = true) -> 18
            else -> 45
        }
    }

    private fun selectedAudioMime(player: ExoPlayer): String? {
        for (group in player.currentTracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO) continue
            for (i in 0 until group.length) {
                if (group.isTrackSelected(i)) {
                    return group.getTrackFormat(i).sampleMimeType
                }
            }
        }
        return null
    }

    /** 0 = mono/stereo, 1 = bilinmeyen, 2 = çok kanallı. Küçük = telefonda öncelikli. */
    private fun embeddedAudioChannelTier(channelCount: Int): Int =
        when {
            channelCount == Format.NO_VALUE || channelCount <= 0 -> 1
            channelCount <= 2 -> 0
            else -> 2
        }

    private fun isMappedAudioTrackCurrentlySelected(
        player: ExoPlayer,
        mapped: MappedTrackInfo,
        audioRendererIndex: Int,
        targetGroupIndex: Int,
        targetTrackIndex: Int,
    ): Boolean {
        val tg = mapped.getTrackGroups(audioRendererIndex)
        if (targetGroupIndex < 0 || targetGroupIndex >= tg.length) return false
        val mediaGroup = tg[targetGroupIndex]
        for (g in player.currentTracks.groups) {
            if (g.type != C.TRACK_TYPE_AUDIO) continue
            if (g.mediaTrackGroup == mediaGroup && g.isTrackSelected(targetTrackIndex)) {
                return true
            }
        }
        return false
    }

    /**
     * Progressive / MKV çoklu ses: seçici bazen AC3/surround seçer; bazı telefonlarda sessiz / uyumsuz olabiliyor.
     * FORMAT_HANDLED + mime önceliği; TV dışı cihazlarda **≤2 kanal** gömülü parça varsa öne alınır.
     * (ExoPlayer’da yazılım downmix yok; stereo parça seçimi pratik çözüm.)
     */
    private fun tryAutoSelectSupportedAudioTrack() {
        if (audioAutoSelectPassesLeft <= 0) return
        val mapped = trackSelector.currentMappedTrackInfo ?: return
        val player = exoPlayer ?: return

        var rendererIndex = -1
        for (ri in 0 until mapped.rendererCount) {
            if (mapped.getRendererType(ri) == C.TRACK_TYPE_AUDIO) {
                rendererIndex = ri
                break
            }
        }
        if (rendererIndex < 0) return

        val trackGroups = mapped.getTrackGroups(rendererIndex)
        var total = 0
        for (g in 0 until trackGroups.length) {
            total += trackGroups[g].length
        }
        if (total == 0) return

        audioAutoSelectPassesLeft--

        data class Pick(
            val rendererIndex: Int,
            val groupIndex: Int,
            val trackIndex: Int,
            val formatSupport: Int,
            val mimeScore: Int,
            val mime: String?,
            val channelTier: Int,
        )

        if (total <= 1) {
            audioAutoSelectPassesLeft = 0
            return
        }

        val picks = ArrayList<Pick>(total)
        for (groupIndex in 0 until trackGroups.length) {
            val group = trackGroups[groupIndex]
            for (trackIndex in 0 until group.length) {
                val caps = mapped.getTrackSupport(rendererIndex, groupIndex, trackIndex)
                val fs = RendererCapabilities.getFormatSupport(caps)
                if (fs != C.FORMAT_HANDLED && fs != C.FORMAT_EXCEEDS_CAPABILITIES) continue
                val format = group.getFormat(trackIndex)
                val mime = format.sampleMimeType
                val chTier = embeddedAudioChannelTier(format.channelCount)
                picks.add(
                    Pick(
                        rendererIndex,
                        groupIndex,
                        trackIndex,
                        fs,
                        mimePreferenceScore(mime),
                        mime,
                        chTier,
                    ),
                )
            }
        }
        if (picks.isEmpty()) {
            audioAutoSelectPassesLeft = 0
            return
        }
        picks.sortWith(
            compareByDescending<Pick> { it.formatSupport == C.FORMAT_HANDLED }
                .thenBy { if (preferStereoEmbeddedWhenMultipleTracks) it.channelTier else 0 }
                .thenByDescending { it.mimeScore },
        )
        val best = picks.first()
        if (isMappedAudioTrackCurrentlySelected(
                player,
                mapped,
                rendererIndex,
                best.groupIndex,
                best.trackIndex,
            )
        ) {
            audioAutoSelectPassesLeft = 0
            return
        }

        val group = trackGroups[best.groupIndex]
        val safeTi = best.trackIndex.coerceIn(0, group.length - 1)
        val builder = trackSelector.parameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
            .setRendererDisabled(best.rendererIndex, false)
            .addOverride(TrackSelectionOverride(group, safeTi))
        trackSelector.setParameters(builder)
        audioAutoSelectPassesLeft = 0
    }

    /**
     * Create media session which will be used in notifications, pip mode.
     *
     * @param context                - android context
     * @return - configured MediaSession instance
     */
    @SuppressLint("InlinedApi")
    fun setupMediaSession(context: Context?): MediaSessionCompat? {
        mediaSession?.release()
        context?.let {

            val mediaButtonIntent = Intent(Intent.ACTION_MEDIA_BUTTON)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0, mediaButtonIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            val mediaSession = MediaSessionCompat(context, TAG, null, pendingIntent)
            mediaSession.setCallback(object : MediaSessionCompat.Callback() {
                override fun onSeekTo(pos: Long) {
                    sendSeekToEvent(pos)
                    super.onSeekTo(pos)
                }
            })
            mediaSession.isActive = true
//            val mediaSessionConnector = MediaSessionConnector(mediaSession)
//            mediaSessionConnector.setPlayer(exoPlayer)
            this.mediaSession = mediaSession
            return mediaSession
        }
        return null

    }

    fun onPictureInPictureStatusChanged(inPip: Boolean) {
        val event: MutableMap<String, Any> = HashMap()
        event["event"] = if (inPip) "pipStart" else "pipStop"
        eventSink.success(event)
    }

    fun disposeMediaSession() {
        if (mediaSession != null) {
            mediaSession?.release()
        }
        mediaSession = null
    }

    fun setAudioTrack(name: String, index: Int) {
        try {
            val mappedTrackInfo = trackSelector.currentMappedTrackInfo
            if (mappedTrackInfo != null) {
                for (rendererIndex in 0 until mappedTrackInfo.rendererCount) {
                    if (mappedTrackInfo.getRendererType(rendererIndex) != C.TRACK_TYPE_AUDIO) {
                        continue
                    }
                    val trackGroupArray = mappedTrackInfo.getTrackGroups(rendererIndex)
                    var hasElementWithoutLabel = false
                    var hasStrangeAudioTrack = false
                    for (groupIndex in 0 until trackGroupArray.length) {
                        val group = trackGroupArray[groupIndex]
                        for (groupElementIndex in 0 until group.length) {
                            val format = group.getFormat(groupElementIndex)
                            if (format.label == null) {
                                hasElementWithoutLabel = true
                            }
                            if (format.id != null && format.id == "1/15") {
                                hasStrangeAudioTrack = true
                            }
                        }
                    }
                    for (groupIndex in 0 until trackGroupArray.length) {
                        val group = trackGroupArray[groupIndex]
                        for (groupElementIndex in 0 until group.length) {
                            val label = group.getFormat(groupElementIndex).label
                            // Exact match by label and provided group index
                            if (name == label && index == groupIndex) {
                                setAudioTrack(rendererIndex, groupIndex, groupElementIndex)
                                return
                            }

                            ///Fallback option
                            if (!hasStrangeAudioTrack && hasElementWithoutLabel && index == groupIndex) {
                                // When labels are missing, default to the first track within the group
                                val safeTrackIndex = if (group.length > 0) 0 else groupElementIndex
                                setAudioTrack(rendererIndex, groupIndex, safeTrackIndex)
                                return
                            }
                            ///Fallback option
                            if (hasStrangeAudioTrack && name == label) {
                                setAudioTrack(rendererIndex, groupIndex, groupElementIndex)
                                return
                            }
                        }
                    }
                }
            }
        } catch (exception: Exception) {
            Log.e(TAG, "setAudioTrack failed$exception")
        }
    }

    private fun setAudioTrack(rendererIndex: Int, groupIndex: Int, trackIndex: Int) {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo
        if (mappedTrackInfo != null) {
            val trackGroups = mappedTrackInfo.getTrackGroups(rendererIndex)
            if (groupIndex >= 0 && groupIndex < trackGroups.length) {
                val group = trackGroups.get(groupIndex)
                val safeTrackIndex = trackIndex.coerceIn(0, group.length - 1)

                val builder = trackSelector.parameters
                    .buildUpon()
                    .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                    .setRendererDisabled(rendererIndex, false)
                    .addOverride(
                        TrackSelectionOverride(
                            group,
                            safeTrackIndex
                        ),
                    )

                trackSelector.setParameters(builder)
            } else {
                Log.e(TAG, "setAudioTrack: groupIndex out of bounds: $groupIndex")
            }
        }
    }

    private fun sendSeekToEvent(positionMs: Long) {
        exoPlayer?.seekTo(positionMs)
        val event: MutableMap<String, Any> = HashMap()
        event["event"] = "seek"
        event["position"] = positionMs
        eventSink.success(event)
    }

    fun setMixWithOthers(mixWithOthers: Boolean) {
        setAudioAttributes(exoPlayer, mixWithOthers)
    }

    fun dispose() {
        val tid = surfaceProducer.id()
        Log.d(SURFACE_LOG_TAG, "dispose START textureId=$tid releasing ExoPlayer + SurfaceProducer")
        disposeMediaSession()
        disposeRemoteNotifications()
        surfaceProducer.setCallback(null)
        if (isInitialized) {
            exoPlayer?.stop()
        }
        exoPlayer?.setVideoSurface(null)
        eventChannel.setStreamHandler(null)
        exoPlayer?.release()
        surfaceProducer.release()
        Log.d(SURFACE_LOG_TAG, "dispose END textureId=$tid SurfaceProducer.release() completed")
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || javaClass != other.javaClass) return false
        val that = other as BetterPlayer
        if (if (exoPlayer != null) exoPlayer != that.exoPlayer else that.exoPlayer != null) return false
        return surfaceProducer.id() == that.surfaceProducer.id()
    }

    override fun hashCode(): Int {
        var result = exoPlayer?.hashCode() ?: 0
        result = 31 * result + surfaceProducer.id().hashCode()
        return result
    }

    /**
     * [ExoPlayer.getCurrentTracks] — gömülü MKV/MP4 ses ve metin (altyazı) izleri.
     * HLS ASMS listesiyle karıştırılmaz; manifest dışı çoklu izler burada görünür.
     */
    fun getExoPlayerTracksPayload(): Map<String, Any?> {
        val player = exoPlayer
            ?: return mapOf("audio" to emptyList<Any>(), "text" to emptyList<Any>())
        val audio = ArrayList<Map<String, Any?>>()
        val text = ArrayList<Map<String, Any?>>()
        val groups = player.currentTracks.groups
        for (gIdx in groups.indices) {
            val group = groups[gIdx]
            when (group.type) {
                C.TRACK_TYPE_AUDIO, C.TRACK_TYPE_TEXT -> {
                    val target = if (group.type == C.TRACK_TYPE_AUDIO) audio else text
                    for (tIdx in 0 until group.length) {
                        if (!group.isTrackSupported(tIdx)) continue
                        val f = group.getTrackFormat(tIdx)
                        val defaultLabel =
                            if (group.type == C.TRACK_TYPE_AUDIO) {
                                "Audio ${target.size + 1}"
                            } else {
                                "Subtitle ${target.size + 1}"
                            }
                        val label = when {
                            !f.label.isNullOrEmpty() -> f.label!!
                            !f.language.isNullOrEmpty() -> f.language!!
                            else -> defaultLabel
                        }
                        target.add(
                            mapOf(
                                "tracksGroupIndex" to gIdx,
                                "trackIndex" to tIdx,
                                "trackType" to group.type,
                                "label" to label,
                                "language" to (f.language ?: ""),
                                "selected" to group.isTrackSelected(tIdx),
                                "mimeType" to (f.sampleMimeType ?: ""),
                            ),
                        )
                    }
                }
                else -> Unit
            }
        }
        return mapOf("audio" to audio, "text" to text)
    }

    /**
     * [TrackSelectionParameters] ile iz seçimi; URL yeniden yüklenmez.
     */
    fun selectExoPlayerTrack(tracksGroupIndex: Int, trackIndex: Int): Boolean {
        val player = exoPlayer ?: return false
        val groups = player.currentTracks.groups
        if (tracksGroupIndex < 0 || tracksGroupIndex >= groups.size) return false
        val group = groups[tracksGroupIndex]
        if (group.type != C.TRACK_TYPE_AUDIO && group.type != C.TRACK_TYPE_TEXT) {
            return false
        }
        if (trackIndex < 0 || trackIndex >= group.length) return false
        if (!group.isTrackSupported(trackIndex)) return false
        val trackType = group.type
        val mediaGroup = group.mediaTrackGroup
        val builder = trackSelector.parameters
            .buildUpon()
            .clearOverridesOfType(trackType)
        if (trackType == C.TRACK_TYPE_TEXT) {
            builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
        }
        if (trackType == C.TRACK_TYPE_AUDIO) {
            val mapped = trackSelector.currentMappedTrackInfo
            if (mapped != null) {
                for (ri in 0 until mapped.rendererCount) {
                    if (mapped.getRendererType(ri) == C.TRACK_TYPE_AUDIO) {
                        builder.setRendererDisabled(ri, false)
                        break
                    }
                }
            }
        }
        builder.addOverride(TrackSelectionOverride(mediaGroup, trackIndex))
        trackSelector.setParameters(builder)
        return true
    }

    /** Gömülü metin izlerini kapatır (Better harici SRT ile karışmaz). */
    fun setExoPlayerTextTrackDisabled(disabled: Boolean) {
        val builder = trackSelector.parameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_TEXT)
        builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, disabled)
        trackSelector.setParameters(builder)
    }

    companion object {
        /** Logcat: `adb logcat -s BetterPlayerSurface` */
        private const val SURFACE_LOG_TAG = "BetterPlayerSurface"
        private const val TAG = "BetterPlayer"
        private const val FORMAT_SS = "ss"
        private const val FORMAT_DASH = "dash"
        private const val FORMAT_HLS = "hls"
        private const val FORMAT_OTHER = "other"
        private const val DEFAULT_NOTIFICATION_CHANNEL = "BETTER_PLAYER_NOTIFICATION"
        private const val NOTIFICATION_ID = 20772077

        //Clear cache without accessing BetterPlayerCache.
        fun clearCache(context: Context?, result: MethodChannel.Result) {
            try {
                context?.let {
                    val file = File(it.cacheDir, "betterPlayerCache")
                    deleteDirectory(file)
                }
                result.success(null)
            } catch (exception: Exception) {
                Log.e(TAG, exception.toString())
                result.error("", "", "")
            }
        }

        private fun deleteDirectory(file: File) {
            if (file.isDirectory) {
                val entries = file.listFiles()
                if (entries != null) {
                    for (entry in entries) {
                        deleteDirectory(entry)
                    }
                }
            }
            if (!file.delete()) {
                Log.e(TAG, "Failed to delete cache dir.")
            }
        }

        //Start pre cache of video. Invoke work manager job and start caching in background.
        fun preCache(
            context: Context?, dataSource: String?, preCacheSize: Long,
            maxCacheSize: Long, maxCacheFileSize: Long, headers: Map<String, String?>,
            cacheKey: String?, result: MethodChannel.Result
        ) {
            val dataBuilder = Data.Builder()
                .putString(BetterPlayerPlugin.URL_PARAMETER, dataSource)
                .putLong(BetterPlayerPlugin.PRE_CACHE_SIZE_PARAMETER, preCacheSize)
                .putLong(BetterPlayerPlugin.MAX_CACHE_SIZE_PARAMETER, maxCacheSize)
                .putLong(BetterPlayerPlugin.MAX_CACHE_FILE_SIZE_PARAMETER, maxCacheFileSize)
            if (cacheKey != null) {
                dataBuilder.putString(BetterPlayerPlugin.CACHE_KEY_PARAMETER, cacheKey)
            }
            for (headerKey in headers.keys) {
                dataBuilder.putString(
                    BetterPlayerPlugin.HEADER_PARAMETER + headerKey,
                    headers[headerKey]
                )
            }
            if (dataSource != null && context != null) {
                val cacheWorkRequest = OneTimeWorkRequest.Builder(CacheWorker::class.java)
                    .addTag(dataSource)
                    .setInputData(dataBuilder.build()).build()
                WorkManager.getInstance(context).enqueue(cacheWorkRequest)
            }
            result.success(null)
        }

        //Stop pre cache of video with given url. If there's no work manager job for given url, then
        //it will be ignored.
        fun stopPreCache(context: Context?, url: String?, result: MethodChannel.Result) {
            if (url != null && context != null) {
                WorkManager.getInstance(context).cancelAllWorkByTag(url)
            }
            result.success(null)
        }
    }

}
