import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../models/recording_mode.dart';

/// Servicio de composición y preparación de grabación de video.
/// Coordina la codificación de hardware (H.264/AAC), el modo de salida (limpio vs con guion),
/// la incrustación nativa del teleprompter mediante AndroidX Media3 y subtítulos .srt.
class VideoRecordingCompositor {
  static const MethodChannel _channel = MethodChannel('com.torocorp.toro_music_teleprompter/video_compositor');

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

  /// Compone el video con la imagen del teleprompter incrustada utilizando aceleración por hardware en Android
  Future<String> compositeVideoWithOverlay({
    required String videoPath,
    required String overlayPath,
    required String outputPath,
  }) async {
    try {
      final String? result = await _channel.invokeMethod<String>('compositeVideoWithOverlay', {
        'videoPath': videoPath,
        'overlayPath': overlayPath,
        'outputPath': outputPath,
      });
      return result ?? videoPath;
    } catch (_) {
      // Fallback seguro al video original si el compositor nativo no está disponible (e.g. en tests)
      return videoPath;
    }
  }

  /// Renderiza la cápsula del teleprompter como imagen PNG de alta definición con fondo transparente
  Future<String> renderTeleprompterOverlayImage({
    required String title,
    required String currentLine,
    String? nextLine,
    String? chords,
    required String outputPath,
    int width = 1080,
    int height = 320,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // Fondo cápsula oscura OLED con esquinas redondeadas
    final rrect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(30, 20, width.toDouble() - 60, height.toDouble() - 40),
      const ui.Radius.circular(28),
    );
    final bgPaint = ui.Paint()
      ..color = const ui.Color(0xE60A0A0A)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Borde elegante sutil
    final borderPaint = ui.Paint()
      ..color = const ui.Color(0x33FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // Cabecera superior: Logo e identificador
    final headerBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 22, maxLines: 1),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFF5A623), fontWeight: ui.FontWeight.bold))
      ..addText('🎤 TOROCORP MUSIC  ')
      ..pushStyle(ui.TextStyle(color: const ui.Color(0x99FFFFFF), fontSize: 18))
      ..addText('•  ${title.toUpperCase()}');
    final headerPara = headerBuilder.build()..layout(ui.ParagraphConstraints(width: width - 120));
    canvas.drawParagraph(headerPara, const ui.Offset(60, 42));

    // Acordes si existen
    double yOffset = 85;
    if (chords != null && chords.isNotEmpty) {
      final chordsBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 26, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFF5A623), fontWeight: ui.FontWeight.w600))
        ..addText(chords);
      final chordsPara = chordsBuilder.build()..layout(ui.ParagraphConstraints(width: width - 120));
      canvas.drawParagraph(chordsPara, ui.Offset(60, yOffset));
      yOffset += 40;
    }

    // Línea actual de la canción (en amarillo resplandeciente / karaoke)
    final currentBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 36, maxLines: 2),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFD54F), fontWeight: ui.FontWeight.bold))
      ..addText(currentLine.isNotEmpty ? currentLine : '♪ ♪ ♪');
    final currentPara = currentBuilder.build()..layout(ui.ParagraphConstraints(width: width - 120));
    canvas.drawParagraph(currentPara, ui.Offset(60, yOffset));
    yOffset += 55;

    // Línea siguiente (vista previa en blanco suave)
    if (nextLine != null && nextLine.isNotEmpty) {
      final nextBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 26, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0x99FFFFFF)))
        ..addText(nextLine);
      final nextPara = nextBuilder.build()..layout(ui.ParagraphConstraints(width: width - 120));
      canvas.drawParagraph(nextPara, ui.Offset(60, yOffset));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final file = File(outputPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return outputPath;
  }

  /// Genera archivo de subtítulos sincronizados .srt para reproductores estándar
  Future<String> generateSrtSubtitles({
    required List<String> lines,
    required int totalDurationSeconds,
    required String outputPath,
  }) async {
    final buffer = StringBuffer();
    if (lines.isEmpty || totalDurationSeconds <= 0) {
      final file = File(outputPath);
      await file.writeAsString(buffer.toString());
      return outputPath;
    }

    final int secondsPerLine = (totalDurationSeconds / lines.length).clamp(2, 8).toInt();
    for (int i = 0; i < lines.length; i++) {
      final startSec = i * secondsPerLine;
      final endSec = ((i + 1) * secondsPerLine).clamp(0, totalDurationSeconds);

      final startFormat = _formatSrtTimestamp(startSec);
      final endFormat = _formatSrtTimestamp(endSec);

      buffer.writeln('${i + 1}');
      buffer.writeln('$startFormat --> $endFormat');
      buffer.writeln(lines[i]);
      buffer.writeln();
    }

    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
    return outputPath;
  }

  String _formatSrtTimestamp(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')},000';
  }
}
