package com.torocorp.toro_music_teleprompter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.OverlaySettings
import androidx.media3.transformer.Composition
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

@UnstableApi
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.torocorp.toro_music_teleprompter/video_compositor"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "compositeVideoWithOverlay" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val overlayPath = call.argument<String>("overlayPath")
                    val outputPath = call.argument<String>("outputPath")

                    if (videoPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "videoPath y outputPath son requeridos", null)
                        return@setMethodCallHandler
                    }

                    val inputFile = File(videoPath)
                    if (!inputFile.exists()) {
                        result.error("FILE_NOT_FOUND", "El archivo de video no existe: $videoPath", null)
                        return@setMethodCallHandler
                    }

                    if (overlayPath == null || !File(overlayPath).exists()) {
                        result.success(videoPath)
                        return@setMethodCallHandler
                    }

                    try {
                        val overlayBitmap = BitmapFactory.decodeFile(overlayPath)
                        if (overlayBitmap == null) {
                            result.success(videoPath)
                            return@setMethodCallHandler
                        }

                        val overlaySettings = OverlaySettings.Builder()
                            .setScale(0.92f, 0.92f)
                            .setBackgroundFrameAnchor(0f, -0.65f)
                            .setOverlayFrameAnchor(0f, 0f)
                            .setAlphaScale(1.0f)
                            .build()

                        val bitmapOverlay = BitmapOverlay.createStaticBitmapOverlay(overlayBitmap, overlaySettings)
                        val overlays = ImmutableList.of<androidx.media3.effect.TextureOverlay>(bitmapOverlay)
                        val overlayEffect = OverlayEffect(overlays)

                        val mediaItem = MediaItem.Builder().setUri(Uri.fromFile(inputFile)).build()
                        val videoEffects = listOf<Effect>(overlayEffect)
                        val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                            .setEffects(Effects(emptyList(), videoEffects))
                            .build()

                        val outputFile = File(outputPath)
                        if (outputFile.exists()) {
                            outputFile.delete()
                        }

                        val handler = Handler(Looper.getMainLooper())
                        val transformer = Transformer.Builder(applicationContext)
                            .setVideoMimeType(MimeTypes.VIDEO_H264)
                            .setAudioMimeType(MimeTypes.AUDIO_AAC)
                            .addListener(object : Transformer.Listener {
                                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                                    handler.post {
                                        result.success(outputPath)
                                    }
                                }

                                override fun onError(
                                    composition: Composition,
                                    exportResult: ExportResult,
                                    exportException: ExportException
                                ) {
                                    handler.post {
                                        result.success(videoPath)
                                    }
                                }
                            })
                            .build()

                        transformer.start(editedMediaItem, outputFile.absolutePath)
                    } catch (e: Exception) {
                        result.success(videoPath)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
