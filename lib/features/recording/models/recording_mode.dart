/// Modos de grabación seleccionables por el usuario
enum RecordingMode {
  /// Graba únicamente el video de la cámara limpio con el filtro de belleza aplicado
  clean,

  /// Graba el video con la letra, notas y efecto karaoke incrustados directamente
  withScript,
}

/// Resoluciones soportadas para grabación
enum VideoResolution {
  hd720p(width: 1280, height: 720, fps: 30, isProOnly: false, label: '720p HD'),
  fhd1080p(width: 1920, height: 1080, fps: 30, isProOnly: false, label: '1080p Full HD'),
  fourK30(width: 3840, height: 2160, fps: 30, isProOnly: true, label: '4K Ultra HD (30fps)'),
  fourK60(width: 3840, height: 2160, fps: 60, isProOnly: true, label: '4K Ultra HD (60fps)');

  final int width;
  final int height;
  final int fps;
  final bool isProOnly;
  final String label;

  const VideoResolution({
    required this.width,
    required this.height,
    required this.fps,
    required this.isProOnly,
    required this.label,
  });
}

/// Configuración calculada para una sesión de grabación
class RecordingConfig {
  final RecordingMode mode;
  final VideoResolution resolution;
  final bool burnInSubtitles;
  final bool applyWatermark;
  final String watermarkText;

  const RecordingConfig({
    required this.mode,
    required this.resolution,
    required this.burnInSubtitles,
    required this.applyWatermark,
    this.watermarkText = 'Hecho con Toro Music',
  });
}
