package com.torocorp.toro_music_teleprompter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.ToneGenerator
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.OverlaySettings
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

private data class DynamicCue(val startTimeUs: Long, val bitmap: Bitmap)

@UnstableApi
class MainActivity : FlutterActivity() {
    private val TAG = "ToroCorpMusic"
    private val CHANNEL = "com.torocorp.toro_music_teleprompter/video_compositor"
    private val METRONOME_CHANNEL = "com.torocorp.toro_music_teleprompter/metronome"
    private val REALTIME_CHANNEL = "com.torocorp.toro_music_teleprompter/realtime_compositor"

    private var toneGeneratorHigh: ToneGenerator? = null
    private var toneGeneratorLow: ToneGenerator? = null

    // Servicio de composición en tiempo real (cámara + overlay karaoke → MP4 directo)
    private val realtimeCompositor = RealtimeCompositorService()

    // Función auxiliar para decodificar Bitmap asegurando formato ARGB_8888 (requerido por OpenGL y Media3)
    private fun decodeArgb8888Bitmap(path: String): Bitmap? {
        val file = File(path)
        if (!file.exists() || file.length() == 0L) return null
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inScaled = false
            inMutable = false
        }
        return BitmapFactory.decodeFile(path, options)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            toneGeneratorHigh = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
            toneGeneratorLow = ToneGenerator(AudioManager.STREAM_MUSIC, 85)
        } catch (e: Throwable) {
            Log.w(TAG, "No se pudo inicializar ToneGenerator: ${e.message}")
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METRONOME_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playBeat" -> {
                    val isDownbeat = call.argument<Boolean>("isDownbeat") ?: false
                    try {
                        if (isDownbeat) {
                            toneGeneratorHigh?.startTone(ToneGenerator.TONE_PROP_BEEP2, 45)
                        } else {
                            toneGeneratorLow?.startTone(ToneGenerator.TONE_PROP_BEEP, 30)
                        }
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("TONE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "compositeVideoWithOverlay" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val outputPath = call.argument<String>("outputPath")
                    val cuesData = call.argument<List<*>>("cues")
                    val overlayPath = call.argument<String>("overlayPath")
                    val watermarkPath = call.argument<String>("watermarkPath")

                    if (videoPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "videoPath y outputPath son requeridos", null)
                        return@setMethodCallHandler
                    }

                    val inputFile = File(videoPath)
                    if (!inputFile.exists()) {
                        result.error("FILE_NOT_FOUND", "El archivo de video no existe: $videoPath", null)
                        return@setMethodCallHandler
                    }

                    val handler = Handler(Looper.getMainLooper())
                    var hasReplied = false

                    fun safeReply(path: String, composited: Boolean) {
                        if (!hasReplied) {
                            hasReplied = true
                            handler.post {
                                result.success(
                                    mapOf(
                                        "path" to path,
                                        "composited" to composited
                                    )
                                )
                            }
                        }
                    }

                    val loadedCues = mutableListOf<DynamicCue>()
                    val dummyBitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
                    val cleanUpBitmaps = {
                        for (cue in loadedCues) {
                            try {
                                if (!cue.bitmap.isRecycled) {
                                    cue.bitmap.recycle()
                                }
                            } catch (_: Throwable) {}
                        }
                        loadedCues.clear()
                        try {
                            if (!dummyBitmap.isRecycled) {
                                dummyBitmap.recycle()
                            }
                        } catch (_: Throwable) {}
                    }

                    try {
                        Log.i(TAG, "Iniciando composición de teleprompter: input=$videoPath, output=$outputPath")

                        // 1. Cargar cues dinámicas si fueron provistas con formato ARGB_8888 garantizado
                        if (cuesData != null && cuesData.isNotEmpty()) {
                            for (item in cuesData) {
                                val entry = item as? Map<*, *> ?: continue
                                val path = entry["imagePath"] as? String ?: continue
                                val timeMs = (entry["startTimeMs"] as? Number)?.toLong() ?: 0L
                                val bmp = decodeArgb8888Bitmap(path)
                                if (bmp != null) {
                                    loadedCues.add(DynamicCue(timeMs * 1000L, bmp))
                                }
                            }
                            loadedCues.sortBy { it.startTimeUs }
                            Log.i(TAG, "Cues decodificadas para teleprompter: ${loadedCues.size}")
                        }

                        // 2. Fallback a overlayPath estático si no hubo lista de cues
                        if (loadedCues.isEmpty() && overlayPath != null) {
                            val bmp = decodeArgb8888Bitmap(overlayPath)
                            if (bmp != null) {
                                loadedCues.add(DynamicCue(0L, bmp))
                                Log.i(TAG, "Overlay estático cargado como cue inicial.")
                            }
                        }

                        // Lista de superposiciones (Overlays)
                        val textureOverlays = mutableListOf<TextureOverlay>()

                        // Determinar dimensiones efectivas del video para escala proporcional
                        var videoW = 1080f
                        var videoH = 1920f
                        try {
                            val retriever = MediaMetadataRetriever()
                            retriever.setDataSource(inputFile.absolutePath)
                            val rotStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: "0"
                            val rot = rotStr.toIntOrNull() ?: 0
                            val rawW = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toFloatOrNull() ?: 1080f
                            val rawH = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toFloatOrNull() ?: 1920f
                            retriever.release()

                            if (rot == 90 || rot == 270) {
                                videoW = rawH
                                videoH = rawW
                            } else {
                                videoW = rawW
                                videoH = rawH
                            }
                            Log.i(TAG, "Dimensiones video detectadas: ${videoW}x${videoH} (rotación=$rot)")
                        } catch (e: Exception) {
                            Log.w(TAG, "No se pudieron extraer dimensiones de video: ${e.message}")
                        }

                        // 3. Crear overlay de teleprompter dinámico
                        if (loadedCues.isNotEmpty()) {
                            // Proporción exacta de la cápsula (1080x330) respecto al fotograma de video
                            val scaleX = 0.92f
                            val scaleY = (scaleX * (330f / 1080f) * (videoW / videoH)).coerceIn(0.10f, 0.35f)

                            // En coordenadas NDC OpenGL: +Y es arriba (cerca de la cámara frontal), 0 es centro
                            val teleprompterSettings = OverlaySettings.Builder()
                                .setScale(scaleX, scaleY)
                                .setBackgroundFrameAnchor(0f, 0.72f)
                                .setOverlayFrameAnchor(0f, 0f)
                                .setAlphaScale(1.0f)
                                .build()

                            val teleprompterOverlay = object : BitmapOverlay() {
                                override fun getBitmap(presentationTimeUs: Long): Bitmap {
                                    if (loadedCues.isEmpty()) return dummyBitmap
                                    var current = loadedCues[0].bitmap
                                    for (cue in loadedCues) {
                                        if (cue.startTimeUs <= presentationTimeUs) {
                                            current = cue.bitmap
                                        } else {
                                            break
                                        }
                                    }
                                    return current
                                }

                                override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
                                    return teleprompterSettings
                                }
                            }
                            textureOverlays.add(teleprompterOverlay)
                        }

                        // 4. Marca de agua "ToroCorp Music" si se solicita
                        if (watermarkPath != null) {
                            val wmBmp = decodeArgb8888Bitmap(watermarkPath)
                            if (wmBmp != null) {
                                val wmScaleX = 0.35f
                                val wmScaleY = (wmScaleX * (90f / 360f) * (videoW / videoH)).coerceIn(0.04f, 0.12f)

                                val wmSettings = OverlaySettings.Builder()
                                    .setScale(wmScaleX, wmScaleY)
                                    .setBackgroundFrameAnchor(0.60f, -0.85f)
                                    .setOverlayFrameAnchor(0f, 0f)
                                    .setAlphaScale(0.85f)
                                    .build()
                                textureOverlays.add(BitmapOverlay.createStaticBitmapOverlay(wmBmp, wmSettings))
                            }
                        }

                        // Si no hay ningún overlay que incrustar, retornar el video original de inmediato
                        if (textureOverlays.isEmpty()) {
                            Log.w(TAG, "No se encontraron overlays válidos para incrustar, retornando original.")
                            cleanUpBitmaps()
                            safeReply(videoPath, false)
                            return@setMethodCallHandler
                        }

                        val overlayEffect = OverlayEffect(ImmutableList.copyOf(textureOverlays))
                        val mediaItem = MediaItem.Builder().setUri(Uri.fromFile(inputFile)).build()
                        val videoEffects = listOf<Effect>(overlayEffect)
                        val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                            .setEffects(Effects(emptyList(), videoEffects))
                            .build()

                        val outputFile = File(outputPath)
                        if (outputFile.exists()) {
                            outputFile.delete()
                        }

                        // Configurar codificador con fallback y especificar formato estándar compatible con todo hardware
                        val encoderFactory = DefaultEncoderFactory.Builder(applicationContext)
                            .setEnableFallback(true)
                            .build()

                        val transformer = Transformer.Builder(applicationContext)
                            .setEncoderFactory(encoderFactory)
                            .setVideoMimeType(MimeTypes.VIDEO_H264)
                            .setAudioMimeType(MimeTypes.AUDIO_AAC)
                            .addListener(object : Transformer.Listener {
                                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                                    Log.i(TAG, "Video con teleprompter procesado exitosamente: ${outputFile.absolutePath} (tam=${outputFile.length()})")
                                    cleanUpBitmaps()
                                    safeReply(outputPath, true)
                                }

                                override fun onError(
                                    composition: Composition,
                                    exportResult: ExportResult,
                                    exportException: ExportException
                                ) {
                                    Log.e(TAG, "Media3 Transformer error: ${exportException.message} | Code: ${exportException.errorCode} (${exportException.errorCodeName})", exportException)
                                    exportException.cause?.let {
                                        Log.e(TAG, "Media3 Transformer inner cause: ${it.message}", it)
                                    }
                                    cleanUpBitmaps()
                                    // Fallback seguro al video de la cámara
                                    safeReply(videoPath, false)
                                }
                            })
                            .build()

                        Log.i(TAG, "Iniciando Transformer.start hacia ${outputFile.absolutePath}...")
                        transformer.start(editedMediaItem, outputFile.absolutePath)
                    } catch (t: Throwable) {
                        Log.e(TAG, "Error iniciando composición: ${t.message}", t)
                        cleanUpBitmaps()
                        safeReply(videoPath, false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── Canal de composición en tiempo real (cámara + overlay karaoke → MP4 sin post-proceso) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REALTIME_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val outputPath = call.argument<String>("outputPath")
                    val width = call.argument<Int>("width") ?: 720
                    val height = call.argument<Int>("height") ?: 1280
                    val rotationDegrees = call.argument<Int>("rotationDegrees") ?: 270
                    val isFront = call.argument<Boolean>("isFront") ?: true

                    if (outputPath == null) {
                        result.error("INVALID_ARGS", "outputPath es requerido", null)
                        return@setMethodCallHandler
                    }

                    try {
                        realtimeCompositor.startRecording(outputPath, width, height, rotationDegrees, isFront)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error en startRecording (realtime): ${e.message}", e)
                        result.error("START_ERROR", e.message, null)
                    }
                }

                "updateOverlay" -> {
                    val pngBytes = call.argument<ByteArray>("pngBytes")
                    if (pngBytes != null && pngBytes.isNotEmpty()) {
                        try {
                            realtimeCompositor.updateOverlay(pngBytes)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.w(TAG, "updateOverlay error: ${e.message}")
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }

                "pushCameraFrame" -> {
                    val yPlane = call.argument<ByteArray>("yPlane")
                    val uPlane = call.argument<ByteArray>("uPlane")
                    val vPlane = call.argument<ByteArray>("vPlane")
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    val rowStride = call.argument<Int>("rowStride") ?: width
                    val uvRowStride = call.argument<Int>("uvRowStride") ?: (width / 2)
                    val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1

                    if (yPlane != null && uPlane != null && vPlane != null && width > 0 && height > 0) {
                        try {
                            realtimeCompositor.pushCameraFrame(
                                yPlane, uPlane, vPlane,
                                width, height, rowStride, uvRowStride, uvPixelStride
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            Log.w(TAG, "pushCameraFrame error: ${e.message}")
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Planos YUV y dimensiones son requeridos", null)
                    }
                }

                "stopRecording" -> {
                    try {
                        val finalPath = realtimeCompositor.stopRecording()
                        result.success(finalPath)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error en stopRecording (realtime): ${e.message}", e)
                        result.error("STOP_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            toneGeneratorHigh?.release()
            toneGeneratorLow?.release()
        } catch (_: Throwable) {}
        toneGeneratorHigh = null
        toneGeneratorLow = null
        super.onDestroy()
    }
}
