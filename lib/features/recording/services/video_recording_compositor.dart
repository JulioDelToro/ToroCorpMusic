import 'dart:io';
import '../models/recording_mode.dart';

/// Servicio de composición y preparación de grabación de video.
/// Coordina la codificación de hardware (H.264/AAC), el modo de salida (limpio vs con guion)
/// y la aplicación de marcas de agua según el estado de suscripción del usuario.
class VideoRecordingCompositor {
  RecordingConfig buildConfig({
    RecordingMode mode = RecordingMode.clean,
    VideoResolution resolution = VideoResolution.fhd1080p,
    required bool isProUser,
    bool hasUnlockedSinglePass = false,
  }) {
    // Si solicita 4K pero no es Pro ni vio anuncio rewarded, se ajusta a 1080p
    VideoResolution effectiveResolution = resolution;
    if (resolution.isProOnly && !isProUser && !hasUnlockedSinglePass) {
      effectiveResolution = VideoResolution.fhd1080p;
    }

    final applyWatermark = !isProUser && !hasUnlockedSinglePass;
    final burnInSubtitles = mode == RecordingMode.withScript;

    return RecordingConfig(
      mode: mode,
      resolution: effectiveResolution,
      burnInSubtitles: burnInSubtitles,
      applyWatermark: applyWatermark,
    );
  }

  /// Genera una ruta local con marca de tiempo para guardar la grabación
  String generateOutputFilePath(String baseDirectory, {String extension = 'mp4'}) {
    final now = DateTime.now();
    final timestamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    final separator = Platform.pathSeparator;
    return '$baseDirectory${separator}ToroMusic_$timestamp.$extension';
  }
}
