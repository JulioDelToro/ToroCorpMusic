package com.torocorp.toro_music_teleprompter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
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

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

                    try {
                        val loadedCues = mutableListOf<DynamicCue>()

                        // 1. Cargar cues dinámicas si fueron provistas
                        if (cuesData != null && cuesData.isNotEmpty()) {
                            for (item in cuesData) {
                                val entry = item as? Map<*, *> ?: continue
                                val path = entry["imagePath"] as? String ?: continue
                                val timeMs = (entry["startTimeMs"] as? Number)?.toLong() ?: 0L
                                val file = File(path)
                                if (file.exists()) {
                                    val bmp = BitmapFactory.decodeFile(path)
                                    if (bmp != null) {
                                        loadedCues.add(DynamicCue(timeMs * 1000L, bmp))
                                    }
                                }
                            }
                            loadedCues.sortBy { it.startTimeUs }
                        }

                        // 2. Fallback a overlayPath estático si no hubo lista de cues
                        if (loadedCues.isEmpty() && overlayPath != null) {
                            val singleFile = File(overlayPath)
                            if (singleFile.exists()) {
                                val bmp = BitmapFactory.decodeFile(overlayPath)
                                if (bmp != null) {
                                    loadedCues.add(DynamicCue(0L, bmp))
                                }
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
                        } catch (e: Exception) {
                            Log.w(TAG, "No se pudieron extraer dimensiones de video: ${e.message}")
                        }

                        // 3. Crear overlay de teleprompter dinámico
                        if (loadedCues.isNotEmpty()) {
                            // Proporción exacta de la cápsula (1080x320) respecto al fotograma de video
                            val scaleX = 0.92f
                            val scaleY = (scaleX * (320f / 1080f) * (videoW / videoH)).coerceIn(0.12f, 0.25f)

                            // En coordenadas NDC OpenGL: +Y es arriba (cerca de la cámara frontal), 0 es centro
                            val teleprompterSettings = OverlaySettings.Builder()
                                .setScale(scaleX, scaleY)
                                .setBackgroundFrameAnchor(0f, 0.70f)
                                .setOverlayFrameAnchor(0f, 0f)
                                .setAlphaScale(1.0f)
                                .build()

                            val teleprompterOverlay = object : BitmapOverlay() {
                                override fun getBitmap(presentationTimeUs: Long): Bitmap {
                                    var activeBitmap = loadedCues.first().bitmap
                                    for (cue in loadedCues) {
                                        if (cue.startTimeUs <= presentationTimeUs) {
                                            activeBitmap = cue.bitmap
                                        } else {
                                            break
                                        }
                                    }
                                    return activeBitmap
                                }

                                override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
                                    return teleprompterSettings
                                }
                            }
                            textureOverlays.add(teleprompterOverlay)
                        }

                        // 4. Marca de agua "ToroCorp Music" si se solicita
                        if (watermarkPath != null) {
                            val wmFile = File(watermarkPath)
                            if (wmFile.exists()) {
                                val wmBmp = BitmapFactory.decodeFile(watermarkPath)
                                if (wmBmp != null) {
                                    val wmScaleX = 0.35f
                                    val wmScaleY = (wmScaleX * (90f / 360f) * (videoW / videoH)).coerceIn(0.04f, 0.10f)

                                    val wmSettings = OverlaySettings.Builder()
                                        .setScale(wmScaleX, wmScaleY)
                                        .setBackgroundFrameAnchor(0.70f, -0.85f)
                                        .setOverlayFrameAnchor(0f, 0f)
                                        .setAlphaScale(0.85f)
                                        .build()
                                    textureOverlays.add(BitmapOverlay.createStaticBitmapOverlay(wmBmp, wmSettings))
                                }
                            }
                        }

                        // Si no hay ningún overlay que incrustar, retornar el video original de inmediato
                        if (textureOverlays.isEmpty()) {
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

                        // Factory con fallback habilitado para compatibilidad universal en cualquier sensor/hardware
                        val encoderFactory = DefaultEncoderFactory.Builder(applicationContext)
                            .setEnableFallback(true)
                            .build()

                        val transformer = Transformer.Builder(applicationContext)
                            .setEncoderFactory(encoderFactory)
                            .addListener(object : Transformer.Listener {
                                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                                    Log.i(TAG, "Video con teleprompter procesado exitosamente: ${outputFile.absolutePath}")
                                    safeReply(outputPath, true)
                                }

                                override fun onError(
                                    composition: Composition,
                                    exportResult: ExportResult,
                                    exportException: ExportException
                                ) {
                                    Log.e(TAG, "Media3 Transformer error: ${exportException.message} (${exportException.errorCodeName})", exportException)
                                    // Fallback seguro al video de la cámara
                                    safeReply(videoPath, false)
                                }
                            })
                            .build()

                        transformer.start(editedMediaItem, outputFile.absolutePath)
                    } catch (t: Throwable) {
                        Log.e(TAG, "Error iniciando composición: ${t.message}", t)
                        safeReply(videoPath, false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
