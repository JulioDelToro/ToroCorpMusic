import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Servicio de grabación en tiempo real que compone el feed de la cámara
/// con el overlay del teleprompter karaoke directamente en el dispositivo,
/// produciendo un MP4 listo sin post-procesado.
///
/// Arquitectura:
/// - Flutter envía frames de cámara (YUV_420_888 via [pushCameraFrame]) y
///   el overlay renderizado en PNG (via [pushOverlayFrame]) al canal nativo.
/// - El servicio Kotlin [RealtimeCompositorService] compone ambas capas en CPU,
///   codifica con MediaCodec (H.264 hardware) y mezcla audio del micrófono
///   (AAC-LC) en MediaMuxer → MP4.
class RealtimeRecordingService {
  static const MethodChannel _channel =
      MethodChannel('com.torocorp.toro_music_teleprompter/realtime_compositor');

  /// Inicia la grabación en tiempo real.
  ///
  /// [outputPath] Ruta completa del MP4 de salida en el almacenamiento interno.
  /// [width]      Ancho del video de salida (ej. 720).
  /// [height]     Alto del video de salida (ej. 1280).
  /// [rotationDegrees] Rotación del sensor de cámara (ej. 270 para frontal portrait).
  /// [isFront]     Indica si es la cámara frontal para aplicar modo espejo.
  Future<void> startRecording({
    required String outputPath,
    required int width,
    required int height,
    int rotationDegrees = 270,
    bool isFront = true,
  }) async {
    await _channel.invokeMethod<bool>('startRecording', {
      'outputPath': outputPath,
      'width': width,
      'height': height,
      'rotationDegrees': rotationDegrees,
      'isFront': isFront,
    });
  }

  /// Envía un frame de cámara en formato YUV_420_888 al compositor nativo.
  ///
  /// Extrae los planos Y, U, V y sus strides del [CameraImage] y los envía
  /// al canal para que Kotlin los componga con el overlay y los encodifique.
  ///
  /// Nota: este método se llama desde el stream de cámara a ~30fps; se ejecuta
  /// de forma no bloqueante para no obstruir el hilo de imagen de la cámara.
  Future<void> pushCameraFrame(CameraImage image) async {
    if (image.planes.length < 3) return;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // Invocar sin await para no bloquear el stream de imagen de la cámara.
    // Los frames que no se puedan procesar a tiempo son descartados por el lado Kotlin.
    _channel.invokeMethod<bool>('pushCameraFrame', {
      'yPlane': yPlane.bytes,
      'uPlane': uPlane.bytes,
      'vPlane': vPlane.bytes,
      'width': image.width,
      'height': image.height,
      'rowStride': yPlane.bytesPerRow,
      'uvRowStride': uPlane.bytesPerRow,
      'uvPixelStride': uPlane.bytesPerPixel ?? 1,
    });
  }

  /// Envía el PNG del overlay del teleprompter al compositor nativo.
  ///
  /// [pngBytes] Bytes PNG del overlay renderizado por [VideoRecordingCompositor.renderTeleprompterOverlayToBytes].
  /// Se mantiene el último overlay hasta que se llame de nuevo con uno nuevo.
  Future<void> pushOverlayFrame(Uint8List pngBytes) async {
    if (pngBytes.isEmpty) return;
    await _channel.invokeMethod<bool>('updateOverlay', {
      'pngBytes': pngBytes,
    });
  }

  /// Detiene la grabación y finaliza el MP4.
  ///
  /// Retorna la ruta del archivo MP4 generado, o una cadena vacía si hubo error.
  Future<String> stopRecording() async {
    final path = await _channel.invokeMethod<String>('stopRecording');
    return path ?? '';
  }
}
