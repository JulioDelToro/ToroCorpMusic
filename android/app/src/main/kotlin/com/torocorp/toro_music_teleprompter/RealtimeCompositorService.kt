package com.torocorp.toro_music_teleprompter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * RealtimeCompositorService
 *
 * Graba en tiempo real el video de la cámara + la cápsula del teleprompter interactiva
 * compuesta directamente en cada frame, mezclando la pista de audio sin requerir
 * post-procesado posterior. El archivo MP4 resultante está listo de inmediato al presionar STOP.
 */
class RealtimeCompositorService {

    private val TAG = "RealtimeCompositorSvc"

    // ── Estado de grabación ──────────────────────────────────────────────────
    private val isRecording = AtomicBoolean(false)
    private var outputPath: String = ""
    private var videoWidth: Int = 720
    private var videoHeight: Int = 1280
    private var rotationDegrees: Int = 270
    private var isFrontCamera: Boolean = true

    // ── Hilo de procesamiento de frames en background ────────────────────────
    private val frameExecutor = Executors.newSingleThreadExecutor()
    private val isFrameProcessing = AtomicBoolean(false)

    // ── MediaCodec / MediaMuxer ──────────────────────────────────────────────
    private var videoCodec: MediaCodec? = null
    private var audioCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var videoTrackIndex: Int = -1
    private var audioTrackIndex: Int = -1
    private var muxerStarted = false
    private val muxerLock = Object()

    // ── AudioRecord (micrófono) ──────────────────────────────────────────────
    private var audioRecord: AudioRecord? = null
    private var audioThread: Thread? = null
    @Volatile private var audioAvailable = false
    private val SAMPLE_RATE = 44100
    private val AUDIO_CHANNEL = AudioFormat.CHANNEL_IN_MONO
    private val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    private val AUDIO_BITRATE = 128_000

    // ── Overlay (teleprompter bitmap) actualizable thread-safe ───────────────
    @Volatile private var overlayBitmap: Bitmap? = null
    private val overlayLock = Object()

    // ── Tiempo de referencia de grabación (para PTS) ─────────────────────────
    private var recordingStartNs: Long = 0L

    fun startRecording(
        outputPath: String,
        width: Int,
        height: Int,
        rotation: Int = 270,
        isFront: Boolean = true
    ) {
        if (isRecording.get()) {
            Log.w(TAG, "startRecording() llamado pero ya está grabando.")
            return
        }

        // Aseguramos que width y height sean pares para el encoder H.264
        this.outputPath = outputPath
        this.videoWidth = if (width % 2 == 0) width else width - 1
        this.videoHeight = if (height % 2 == 0) height else height - 1
        this.rotationDegrees = rotation
        this.isFrontCamera = isFront
        this.videoTrackIndex = -1
        this.audioTrackIndex = -1
        this.muxerStarted = false
        this.audioAvailable = false

        Log.i(TAG, "Iniciando grabación en tiempo real: $outputPath (${videoWidth}x${videoHeight}, rot=$rotation, front=$isFront)")

        try {
            val outFile = File(outputPath)
            if (outFile.exists()) outFile.delete()

            mediaMuxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            setupVideoEncoder(videoWidth, videoHeight)
            setupAudioEncoder()
            startAudioCapture()

            recordingStartNs = System.nanoTime()
            isRecording.set(true)
            Log.i(TAG, "Grabación en tiempo real iniciada correctamente.")
        } catch (e: Exception) {
            Log.e(TAG, "Error en startRecording: ${e.message}", e)
            releaseAll()
        }
    }

    fun updateOverlay(pngBytes: ByteArray) {
        if (pngBytes.isEmpty()) return
        try {
            val bmp = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size) ?: return
            synchronized(overlayLock) {
                overlayBitmap?.recycle()
                overlayBitmap = bmp
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error decodificando overlay: ${e.message}")
        }
    }

    fun pushCameraFrame(
        yPlane: ByteArray,
        uPlane: ByteArray,
        vPlane: ByteArray,
        width: Int,
        height: Int,
        rowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int
    ) {
        if (!isRecording.get()) return

        // Si ya hay un frame procesándose en CPU, descartamos este para no acumular latencia
        if (!isFrameProcessing.compareAndSet(false, true)) {
            return
        }

        frameExecutor.execute {
            try {
                if (!isRecording.get()) return@execute
                val codec = videoCodec ?: return@execute

                // 1. Convertir YUV_420_888 de la cámara → ARGB bitmap (orientación nativa del sensor)
                val rawBitmap = yuv420ToBitmap(
                    yPlane, uPlane, vPlane,
                    width, height, rowStride, uvRowStride, uvPixelStride
                )

                // 2. Corregir rotación del sensor y modo espejo frontal
                val matrix = Matrix()
                if (rotationDegrees != 0) {
                    matrix.postRotate(rotationDegrees.toFloat())
                }
                if (isFrontCamera) {
                    // Espejo horizontal centrado para la cámara frontal
                    matrix.postScale(-1f, 1f, rawBitmap.width / 2f, rawBitmap.height / 2f)
                }

                val rotatedBitmap = if (!matrix.isIdentity) {
                    Bitmap.createBitmap(rawBitmap, 0, 0, rawBitmap.width, rawBitmap.height, matrix, true)
                } else {
                    rawBitmap
                }

                // 3. Redimensionar exactamente a las dimensiones configuradas en el MediaCodec (videoWidth x videoHeight)
                val targetFrame = if (rotatedBitmap.width != videoWidth || rotatedBitmap.height != videoHeight) {
                    Bitmap.createScaledBitmap(rotatedBitmap, videoWidth, videoHeight, true)
                } else {
                    rotatedBitmap.copy(Bitmap.Config.ARGB_8888, true)
                }

                if (rotatedBitmap != rawBitmap) rotatedBitmap.recycle()
                rawBitmap.recycle()

                // 4. Componer overlay del teleprompter encima del cuadro vertical
                val canvas = Canvas(targetFrame)
                val overlay = synchronized(overlayLock) { overlayBitmap }
                if (overlay != null && !overlay.isRecycled) {
                    val targetW = (videoWidth * 0.92f).toInt()
                    val aspect = overlay.height.toFloat() / overlay.width.toFloat()
                    val targetH = (targetW * aspect).toInt().coerceAtLeast(60)

                    val posX = (videoWidth - targetW) / 2f
                    val posY = videoHeight * 0.04f // 4% debajo del borde superior

                    val scaledOverlay = Bitmap.createScaledBitmap(overlay, targetW, targetH, true)
                    canvas.drawBitmap(scaledOverlay, posX, posY, null)
                    scaledOverlay.recycle()
                }

                // 5. Convertir bitmap ARGB a NV12 (YUV420SemiPlanar) con dimensiones EXACTAS de videoWidth x videoHeight
                val nv12 = argbBitmapToNv12(targetFrame, videoWidth, videoHeight)
                targetFrame.recycle()

                // 6. PTS en microsegundos
                val pts = (System.nanoTime() - recordingStartNs) / 1000L

                // 7. Encolar en MediaCodec
                val inputIdx = codec.dequeueInputBuffer(10_000)
                if (inputIdx >= 0) {
                    val buf = codec.getInputBuffer(inputIdx) ?: return@execute
                    buf.clear()
                    buf.put(nv12)
                    codec.queueInputBuffer(inputIdx, 0, nv12.size, pts, 0)
                }

                // 8. Drenar encoder de video
                drainVideoEncoder(endOfStream = false)

            } catch (e: Exception) {
                Log.e(TAG, "Error procesando frame en background: ${e.message}", e)
            } finally {
                isFrameProcessing.set(false)
            }
        }
    }

    fun stopRecording(): String {
        if (!isRecording.get()) {
            Log.w(TAG, "stopRecording() llamado sin grabación activa.")
            return ""
        }

        Log.i(TAG, "Deteniendo grabación en tiempo real...")
        isRecording.set(false)

        try {
            // Señal fin de stream al encoder de video
            videoCodec?.let { codec ->
                val inputIdx = codec.dequeueInputBuffer(20_000)
                if (inputIdx >= 0) {
                    codec.queueInputBuffer(inputIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                }
                drainVideoEncoder(endOfStream = true)
            }

            // Detener captura de audio
            audioThread?.join(1500)
            try { audioRecord?.stop() } catch (_: Exception) {}
            try { audioRecord?.release() } catch (_: Exception) {}
            audioRecord = null

            // Señal fin de stream al encoder de audio
            audioCodec?.let { codec ->
                val inputIdx = codec.dequeueInputBuffer(20_000)
                if (inputIdx >= 0) {
                    codec.queueInputBuffer(inputIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                }
                drainAudioEncoder(endOfStream = true)
            }

            // Finalizar muxer
            synchronized(muxerLock) {
                if (muxerStarted) {
                    try { mediaMuxer?.stop() } catch (e: Exception) { Log.w(TAG, "Error parando muxer: ${e.message}") }
                    muxerStarted = false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error en stopRecording: ${e.message}", e)
        } finally {
            releaseAll()
        }

        val exists = File(outputPath).exists()
        Log.i(TAG, "Grabación finalizada. Archivo: $outputPath (existe=$exists)")
        return if (exists) outputPath else ""
    }

    private fun setupVideoEncoder(width: Int, height: Int) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, 5_000_000) // 5 Mbps
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar)
        }

        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        videoCodec = codec
        Log.d(TAG, "Encoder de video H.264 configurado (${width}x${height})")
    }

    private fun setupAudioEncoder() {
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BITRATE)
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }

        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        audioCodec = codec
        Log.d(TAG, "Encoder de audio AAC-LC configurado ($SAMPLE_RATE Hz mono, $AUDIO_BITRATE bps)")
    }

    private fun startAudioCapture() {
        try {
            val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, AUDIO_CHANNEL, AUDIO_FORMAT)
            val bufSize = maxOf(minBuf, 4096)

            val record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AUDIO_CHANNEL,
                AUDIO_FORMAT,
                bufSize
            )

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                Log.w(TAG, "AudioRecord no se pudo inicializar (micrófono en uso). Grabando video puro.")
                record.release()
                audioAvailable = false
                tryStartMuxer()
                return
            }

            record.startRecording()
            audioRecord = record
            audioAvailable = true

            audioThread = Thread({
                val pcmBuf = ByteArray(bufSize)
                Log.d(TAG, "Hilo de captura de audio iniciado.")

                while (isRecording.get()) {
                    val read = record.read(pcmBuf, 0, pcmBuf.size)
                    if (read <= 0) continue

                    val codec = audioCodec ?: break
                    val pts = (System.nanoTime() - recordingStartNs) / 1000L

                    val inputIdx = codec.dequeueInputBuffer(10_000)
                    if (inputIdx >= 0) {
                        val buf = codec.getInputBuffer(inputIdx) ?: continue
                        buf.clear()
                        buf.put(pcmBuf, 0, read)
                        codec.queueInputBuffer(inputIdx, 0, read, pts, 0)
                    }
                    drainAudioEncoder(endOfStream = false)
                }
                Log.d(TAG, "Hilo de captura de audio finalizado.")
            }, "RealtimeAudioCapture")

            audioThread!!.start()
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord excepción: ${e.message}. Continuando video.")
            audioAvailable = false
            tryStartMuxer()
        }
    }

    private fun drainVideoEncoder(endOfStream: Boolean) {
        val codec = videoCodec ?: return
        val bufferInfo = MediaCodec.BufferInfo()

        while (true) {
            val outputIdx = codec.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outputIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) break
                }
                outputIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    synchronized(muxerLock) {
                        videoTrackIndex = mediaMuxer!!.addTrack(codec.outputFormat)
                        Log.d(TAG, "Video track añadido al muxer: index=$videoTrackIndex")
                        tryStartMuxer()
                    }
                }
                outputIdx >= 0 -> {
                    val encodedData = codec.getOutputBuffer(outputIdx) ?: run {
                        codec.releaseOutputBuffer(outputIdx, false)
                        continue
                    }
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }
                    if (bufferInfo.size > 0) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        synchronized(muxerLock) {
                            if (muxerStarted && videoTrackIndex >= 0) {
                                mediaMuxer?.writeSampleData(videoTrackIndex, encodedData, bufferInfo)
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outputIdx, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
                else -> break
            }
        }
    }

    private fun drainAudioEncoder(endOfStream: Boolean) {
        val codec = audioCodec ?: return
        val bufferInfo = MediaCodec.BufferInfo()

        while (true) {
            val outputIdx = codec.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outputIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) break
                }
                outputIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    synchronized(muxerLock) {
                        audioTrackIndex = mediaMuxer!!.addTrack(codec.outputFormat)
                        Log.d(TAG, "Audio track añadido al muxer: index=$audioTrackIndex")
                        tryStartMuxer()
                    }
                }
                outputIdx >= 0 -> {
                    val encodedData = codec.getOutputBuffer(outputIdx) ?: run {
                        codec.releaseOutputBuffer(outputIdx, false)
                        continue
                    }
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }
                    if (bufferInfo.size > 0) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        synchronized(muxerLock) {
                            if (muxerStarted && audioTrackIndex >= 0) {
                                mediaMuxer?.writeSampleData(audioTrackIndex, encodedData, bufferInfo)
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outputIdx, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
                else -> break
            }
        }
    }

    private fun tryStartMuxer() {
        synchronized(muxerLock) {
            if (!muxerStarted && videoTrackIndex >= 0) {
                if (audioTrackIndex >= 0 || !audioAvailable) {
                    try {
                        mediaMuxer?.start()
                        muxerStarted = true
                        Log.i(TAG, "MediaMuxer iniciado (video=$videoTrackIndex, audio=$audioTrackIndex, audioAvail=$audioAvailable)")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error iniciando MediaMuxer: ${e.message}", e)
                    }
                }
            }
        }
    }

    private fun yuv420ToBitmap(
        yPlane: ByteArray,
        uPlane: ByteArray,
        vPlane: ByteArray,
        width: Int,
        height: Int,
        rowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int
    ): Bitmap {
        val nv21 = buildNv21(yPlane, uPlane, vPlane, width, height, rowStride, uvRowStride, uvPixelStride)
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, out)
        val jpegBytes = out.toByteArray()
        return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
            ?: Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    }

    private fun buildNv21(
        yPlane: ByteArray,
        uPlane: ByteArray,
        vPlane: ByteArray,
        width: Int,
        height: Int,
        rowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int
    ): ByteArray {
        val nv21 = ByteArray(width * height * 3 / 2)

        var dstIdx = 0
        for (row in 0 until height) {
            val srcOffset = row * rowStride
            val copyLen = minOf(width, yPlane.size - srcOffset)
            if (copyLen > 0) {
                System.arraycopy(yPlane, srcOffset, nv21, dstIdx, copyLen)
            }
            dstIdx += width
        }

        val uvHeight = height / 2
        val uvWidth = width / 2
        for (row in 0 until uvHeight) {
            for (col in 0 until uvWidth) {
                val uvOffset = row * uvRowStride + col * uvPixelStride
                val vByte = if (uvOffset < vPlane.size) vPlane[uvOffset] else 0
                val uByte = if (uvOffset < uPlane.size) uPlane[uvOffset] else 0
                nv21[dstIdx++] = vByte
                nv21[dstIdx++] = uByte
            }
        }

        return nv21
    }

    private fun argbBitmapToNv12(bitmap: Bitmap, width: Int, height: Int): ByteArray {
        val argb = IntArray(width * height)
        bitmap.getPixels(argb, 0, width, 0, 0, width, height)

        val nv12 = ByteArray(width * height * 3 / 2)
        var yIdx = 0
        var uvIdx = width * height

        for (row in 0 until height) {
            for (col in 0 until width) {
                val pixel = argb[row * width + col]
                val r = (pixel shr 16) and 0xFF
                val g = (pixel shr 8) and 0xFF
                val b = pixel and 0xFF

                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                nv12[yIdx++] = y.coerceIn(0, 255).toByte()

                if (row % 2 == 0 && col % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    nv12[uvIdx++] = u.coerceIn(0, 255).toByte()
                    nv12[uvIdx++] = v.coerceIn(0, 255).toByte()
                }
            }
        }

        return nv12
    }

    private fun releaseAll() {
        try { videoCodec?.stop() } catch (_: Exception) {}
        try { videoCodec?.release() } catch (_: Exception) {}
        videoCodec = null

        try { audioCodec?.stop() } catch (_: Exception) {}
        try { audioCodec?.release() } catch (_: Exception) {}
        audioCodec = null

        try { mediaMuxer?.release() } catch (_: Exception) {}
        mediaMuxer = null

        synchronized(overlayLock) {
            overlayBitmap?.recycle()
            overlayBitmap = null
        }

        Log.d(TAG, "Todos los recursos del compositor en tiempo real liberados.")
    }
}
