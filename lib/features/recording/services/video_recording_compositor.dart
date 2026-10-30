import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/recording_mode.dart';
import '../../scripts/models/lyric_token.dart';
import '../../scripts/models/song_script.dart';

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
  Future<({String path, bool composited})> compositeVideoWithOverlay({
    required String videoPath,
    String? overlayPath,
    List<Map<String, dynamic>>? cues,
    String? watermarkPath,
    required String outputPath,
  }) async {
    try {
      final args = <String, dynamic>{
        'videoPath': videoPath,
        'outputPath': outputPath,
      };
      if (overlayPath != null) args['overlayPath'] = overlayPath;
      if (cues != null) args['cues'] = cues;
      if (watermarkPath != null) args['watermarkPath'] = watermarkPath;

      debugPrint('ToroCorp Music: Invocando Media3 Transformer (cues=${cues?.length ?? 0})...');
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'compositeVideoWithOverlay',
        args,
      );
      if (result != null) {
        final path = result['path'] as String? ?? videoPath;
        final composited = result['composited'] as bool? ?? false;
        debugPrint('ToroCorp Music: Media3 finalizado -> composited=$composited, path=$path');
        return (path: path, composited: composited);
      }
      return (path: videoPath, composited: false);
    } catch (e, stack) {
      debugPrint('ToroCorp Music: Error invocando Media3 Transformer: $e\n$stack');
      return (path: videoPath, composited: false);
    }
  }

  /// Renderiza una marca de agua sutil ("ToroCorp Music • Free") en PNG
  Future<String> renderWatermarkOverlayImage({
    required String outputPath,
    int width = 360,
    int height = 90,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    final rrect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(8, 8, width.toDouble() - 16, height.toDouble() - 16),
      const ui.Radius.circular(20),
    );
    final bgPaint = ui.Paint()
      ..color = const ui.Color(0xD90A0A0A)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = ui.Paint()
      ..color = const ui.Color(0x33FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    final headerBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: 20, maxLines: 1),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFF5A623), fontWeight: ui.FontWeight.bold))
      ..addText('ToroCorp Music')
      ..pushStyle(ui.TextStyle(color: const ui.Color(0x99FFFFFF), fontSize: 16))
      ..addText('  •  Free');
    final headerPara = headerBuilder.build()..layout(ui.ParagraphConstraints(width: width - 32));
    canvas.drawParagraph(headerPara, const ui.Offset(16, 26));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final file = File(outputPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return outputPath;
  }

  /// Renderiza la cápsula del teleprompter exactamente igual a la Dynamic Island de la pantalla
  /// incluyendo el botón Voz, el indicador REC con temporizador, divisor vertical,
  /// 3 líneas de letra con karaoke resaltado palabra por palabra y el botón de menú circular (☰).
  Future<String> renderTeleprompterOverlayImage({
    LyricLine? currentLyricLine,
    LyricLine? nextLyricLine,
    LyricLine? thirdLyricLine,
    int activeWordIndex = -1,
    int elapsedSeconds = 0,
    bool isSinging = true,
    Color highlightColor = const Color(0xFFFFD54F),
    String? title,
    String? currentLine,
    String? nextLine,
    String? chords,
    required String outputPath,
    int width = 1080,
    int height = 330,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    final capsuleW = width.toDouble() - 80.0;
    final capsuleH = height.toDouble() - 40.0;
    final capsuleRect = ui.Rect.fromLTWH(40, 20, capsuleW, capsuleH);

    // 1. Fondo de la cápsula: Negro puro OLED (0xF2000000) con bordes redondeados
    final rrect = ui.RRect.fromRectAndRadius(capsuleRect, const ui.Radius.circular(54));
    final bgPaint = ui.Paint()
      ..color = const ui.Color(0xF40A0A0A)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Borde sutil elegante
    final borderPaint = ui.Paint()
      ..color = const ui.Color(0x33FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // ── 2. Columna Izquierda: Botón "Voz" y "● REC mm:ss" ──
    const vozLeft = 75.0;
    const vozTop = 50.0;
    const vozWidth = 160.0;
    const vozHeight = 78.0;

    // Pastilla "Voz" dorada con halo cuando isSinging es true
    final vozRect = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(vozLeft, vozTop, vozWidth, vozHeight),
      const ui.Radius.circular(39),
    );
    final vozBg = ui.Paint()
      ..color = isSinging ? const ui.Color(0x38F5A623) : const ui.Color(0x18FFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(vozRect, vozBg);

    final vozBorder = ui.Paint()
      ..color = isSinging ? const ui.Color(0xFFF5A623) : const ui.Color(0x50FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(vozRect, vozBorder);

    // Texto "🎤 Voz"
    final vozTextColor = isSinging ? const ui.Color(0xFFF5A623) : const ui.Color(0xB3FFFFFF);
    final vozBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: 30, maxLines: 1),
    )
      ..pushStyle(ui.TextStyle(color: vozTextColor, fontWeight: ui.FontWeight.bold))
      ..addText('🎤 Voz');
    final vozPara = vozBuilder.build()..layout(const ui.ParagraphConstraints(width: vozWidth));
    canvas.drawParagraph(vozPara, const ui.Offset(vozLeft, vozTop + 20));

    // Indicador REC con punto rojo y temporizador
    final minStr = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final secStr = (elapsedSeconds % 60).toString().padLeft(2, '0');

    final redDot = ui.Paint()
      ..color = const ui.Color(0xFFFF3B30)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(const ui.Offset(102, 172), 8.5, redDot);

    final recBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 25, maxLines: 1),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFF3B30), fontWeight: ui.FontWeight.bold))
      ..addText('REC $minStr:$secStr');
    final recPara = recBuilder.build()..layout(const ui.ParagraphConstraints(width: 145));
    canvas.drawParagraph(recPara, const ui.Offset(122, 158));

    // ── 3. Separador Vertical ──
    final dividerPaint = ui.Paint()
      ..color = const ui.Color(0x38FFFFFF)
      ..strokeWidth = 2.0;
    canvas.drawLine(const ui.Offset(265, 45), const ui.Offset(265, 245), dividerPaint);

    // ── 4. Columna Derecha: Botón de Menú Circular (☰) ──
    final menuCenterX = width.toDouble() - 110.0;
    final menuCenterY = height.toDouble() / 2.0;
    const menuRadius = 46.0;

    final menuCircle = ui.Paint()
      ..color = const ui.Color(0x28FFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(ui.Offset(menuCenterX, menuCenterY), menuRadius, menuCircle);

    final menuBorder = ui.Paint()
      ..color = const ui.Color(0x40FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(ui.Offset(menuCenterX, menuCenterY), menuRadius, menuBorder);

    final barPaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..strokeWidth = 3.8
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawLine(ui.Offset(menuCenterX - 18, menuCenterY - 11), ui.Offset(menuCenterX + 18, menuCenterY - 11), barPaint);
    canvas.drawLine(ui.Offset(menuCenterX - 18, menuCenterY), ui.Offset(menuCenterX + 18, menuCenterY), barPaint);
    canvas.drawLine(ui.Offset(menuCenterX - 18, menuCenterY + 11), ui.Offset(menuCenterX + 18, menuCenterY + 11), barPaint);

    // ── 5. Área Central: Las 3 Líneas de Letra y Acordes ──
    const lyricsLeft = 295.0;
    final lyricsWidth = menuCenterX - menuRadius - lyricsLeft - 20.0;

    // Determinar línea 1 (actual)
    final LyricLine? effectiveCurLine = currentLyricLine ??
        (currentLine != null && currentLine.isNotEmpty
            ? LyricLine(
                tokens: currentLine
                    .trim()
                    .split(RegExp(r'\s+'))
                    .map((w) => LyricToken(word: w))
                    .toList())
            : null);

    // Determinar acordes
    final String? effectiveChords = chords ??
        (effectiveCurLine != null &&
                effectiveCurLine.tokens.any((t) => t.chordUnderneath != null && t.chordUnderneath!.isNotEmpty)
            ? effectiveCurLine.tokens
                .map((t) => t.chordUnderneath ?? '')
                .where((c) => c.isNotEmpty)
                .join('   ')
            : null);

    double currentY = 46.0;

    if (effectiveChords != null && effectiveChords.isNotEmpty) {
      final chordsBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 24, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFF5A623), fontWeight: ui.FontWeight.bold))
        ..addText(effectiveChords);
      final chordsPara = chordsBuilder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(chordsPara, ui.Offset(lyricsLeft, currentY));
      currentY += 34.0;
    }

    if (effectiveCurLine != null && effectiveCurLine.tokens.isNotEmpty) {
      // Línea 1: Palabras resaltadas en karaoke (amarillo) y palabras pendientes en blanco
      final line1Builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 32, maxLines: 1),
      );

      for (int i = 0; i < effectiveCurLine.tokens.length; i++) {
        final token = effectiveCurLine.tokens[i];
        final bool isSung = activeWordIndex >= 0 ? (i <= activeWordIndex) : (activeWordIndex == -1 ? true : false);

        line1Builder.pushStyle(
          ui.TextStyle(
            color: isSung ? highlightColor : const ui.Color(0xFFFFFFFF),
            fontWeight: isSung ? ui.FontWeight.w900 : ui.FontWeight.w600,
            fontSize: 32,
          ),
        );
        line1Builder.addText(token.word);
        if (i < effectiveCurLine.tokens.length - 1) {
          line1Builder.addText(' ');
        }
      }

      final line1Para = line1Builder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(line1Para, ui.Offset(lyricsLeft, currentY));
      currentY += 48.0;
    } else {
      // Si está vacía
      final emptyBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 26, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0x99FFFFFF)))
        ..addText('♪ ♪ ♪');
      final emptyPara = emptyBuilder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(emptyPara, ui.Offset(lyricsLeft, currentY));
      currentY += 48.0;
    }

    // Línea 2 (Siguiente estrofa)
    final String line2Text = nextLyricLine?.fullText ?? (nextLine ?? '');
    if (line2Text.isNotEmpty) {
      final line2Builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 25, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xB3FFFFFF), fontWeight: ui.FontWeight.w500))
        ..addText(line2Text);
      final line2Para = line2Builder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(line2Para, ui.Offset(lyricsLeft, currentY));
      currentY += 40.0;
    }

    // Línea 3 (Tercera estrofa de vista previa)
    final String line3Text = thirdLyricLine?.fullText ?? '';
    if (line3Text.isNotEmpty) {
      final line3Builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 22, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0x66FFFFFF), fontWeight: ui.FontWeight.w400))
        ..addText(line3Text);
      final line3Para = line3Builder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(line3Para, ui.Offset(lyricsLeft, currentY));
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

  /// Renderiza la cápsula del teleprompter idéntica a [renderTeleprompterOverlayImage]
  /// pero retorna los bytes PNG en memoria (Uint8List) en lugar de escribir un archivo.
  ///
  /// Ideal para el modo de grabación en tiempo real donde el overlay se envía
  /// frame a frame al compositor nativo sin necesidad de E/S en disco.
  Future<Uint8List> renderTeleprompterOverlayToBytes({
    LyricLine? currentLyricLine,
    LyricLine? nextLyricLine,
    LyricLine? thirdLyricLine,
    int activeWordIndex = -1,
    int elapsedSeconds = 0,
    bool isSinging = true,
    Color highlightColor = const Color(0xFFFFD54F),
    String? title,
    String? currentLine,
    String? nextLine,
    String? chords,
    int width = 1080,
    int height = 330,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    final capsuleW = width.toDouble() - 80.0;
    final capsuleH = height.toDouble() - 40.0;
    final capsuleRect = ui.Rect.fromLTWH(40, 20, capsuleW, capsuleH);

    // 1. Fondo de la cápsula: Negro puro OLED (0xF2000000) con bordes redondeados
    final rrect = ui.RRect.fromRectAndRadius(capsuleRect, const ui.Radius.circular(54));
    final bgPaint = ui.Paint()
      ..color = const ui.Color(0xF40A0A0A)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Borde sutil elegante
    final borderPaint = ui.Paint()
      ..color = const ui.Color(0x33FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // ── 2. Columna Izquierda: Botón "Voz" y "● REC mm:ss" ──
    const vozLeft = 75.0;
    const vozTop = 50.0;
    const vozWidth = 160.0;
    const vozHeight = 78.0;

    // Pastilla "Voz" dorada con halo cuando isSinging es true
    final vozRect = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(vozLeft, vozTop, vozWidth, vozHeight),
      const ui.Radius.circular(39),
    );
    final vozBg = ui.Paint()
      ..color = isSinging ? const ui.Color(0x38F5A623) : const ui.Color(0x18FFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(vozRect, vozBg);

    final vozBorder = ui.Paint()
      ..color = isSinging ? const ui.Color(0xFFF5A623) : const ui.Color(0x50FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(vozRect, vozBorder);

    // Texto "🎤 Voz"
    final vozTextColor = isSinging ? const ui.Color(0xFFF5A623) : const ui.Color(0xB3FFFFFF);
    final vozBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: 30, maxLines: 1),
    )
      ..pushStyle(ui.TextStyle(color: vozTextColor, fontWeight: ui.FontWeight.bold))
      ..addText('🎤 Voz');
    final vozPara = vozBuilder.build()..layout(const ui.ParagraphConstraints(width: vozWidth));
    canvas.drawParagraph(vozPara, const ui.Offset(vozLeft, vozTop + 20));

    // Indicador REC con punto rojo y temporizador
    final minStr = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final secStr = (elapsedSeconds % 60).toString().padLeft(2, '0');

    final redDot = ui.Paint()
      ..color = const ui.Color(0xFFFF3B30)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(const ui.Offset(102, 172), 8.5, redDot);

    final recBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 25, maxLines: 1),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFF3B30), fontWeight: ui.FontWeight.bold))
      ..addText('REC $minStr:$secStr');
    final recPara = recBuilder.build()..layout(const ui.ParagraphConstraints(width: 145));
    canvas.drawParagraph(recPara, const ui.Offset(122, 158));

    // ── 3. Separador Vertical ──
    final dividerPaint = ui.Paint()
      ..color = const ui.Color(0x38FFFFFF)
      ..strokeWidth = 2.0;
    canvas.drawLine(const ui.Offset(265, 45), const ui.Offset(265, 245), dividerPaint);

    // ── 4. Columna Derecha: Botón de Menú Circular (☰) ──
    final menuCenterX = width.toDouble() - 110.0;
    final menuCenterY = height.toDouble() / 2.0;
    const menuRadius = 46.0;

    final menuCircle = ui.Paint()
      ..color = const ui.Color(0x28FFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(ui.Offset(menuCenterX, menuCenterY), menuRadius, menuCircle);

    final menuBorder = ui.Paint()
      ..color = const ui.Color(0x40FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(ui.Offset(menuCenterX, menuCenterY), menuRadius, menuBorder);

    final barPaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..strokeWidth = 3.8
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawLine(ui.Offset(menuCenterX - 18, menuCenterY - 11), ui.Offset(menuCenterX + 18, menuCenterY - 11), barPaint);
    canvas.drawLine(ui.Offset(menuCenterX - 18, menuCenterY), ui.Offset(menuCenterX + 18, menuCenterY), barPaint);
    canvas.drawLine(ui.Offset(menuCenterX - 18, menuCenterY + 11), ui.Offset(menuCenterX + 18, menuCenterY + 11), barPaint);

    // ── 5. Área Central: Las 3 Líneas de Letra y Acordes ──
    const lyricsLeft = 295.0;
    final lyricsWidth = menuCenterX - menuRadius - lyricsLeft - 20.0;

    // Determinar línea 1 (actual)
    final LyricLine? effectiveCurLine = currentLyricLine ??
        (currentLine != null && currentLine.isNotEmpty
            ? LyricLine(
                tokens: currentLine
                    .trim()
                    .split(RegExp(r'\s+'))
                    .map((w) => LyricToken(word: w))
                    .toList())
            : null);

    // Determinar acordes
    final String? effectiveChords = chords ??
        (effectiveCurLine != null &&
                effectiveCurLine.tokens.any((t) => t.chordUnderneath != null && t.chordUnderneath!.isNotEmpty)
            ? effectiveCurLine.tokens
                .map((t) => t.chordUnderneath ?? '')
                .where((c) => c.isNotEmpty)
                .join('   ')
            : null);

    double currentY = 46.0;

    if (effectiveChords != null && effectiveChords.isNotEmpty) {
      final chordsBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 24, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFF5A623), fontWeight: ui.FontWeight.bold))
        ..addText(effectiveChords);
      final chordsPara = chordsBuilder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(chordsPara, ui.Offset(lyricsLeft, currentY));
      currentY += 34.0;
    }

    if (effectiveCurLine != null && effectiveCurLine.tokens.isNotEmpty) {
      // Línea 1: Palabras resaltadas en karaoke (amarillo) y palabras pendientes en blanco
      final line1Builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 32, maxLines: 1),
      );

      for (int i = 0; i < effectiveCurLine.tokens.length; i++) {
        final token = effectiveCurLine.tokens[i];
        final bool isSung = activeWordIndex >= 0 ? (i <= activeWordIndex) : (activeWordIndex == -1 ? true : false);

        line1Builder.pushStyle(
          ui.TextStyle(
            color: isSung ? highlightColor : const ui.Color(0xFFFFFFFF),
            fontWeight: isSung ? ui.FontWeight.w900 : ui.FontWeight.w600,
            fontSize: 32,
          ),
        );
        line1Builder.addText(token.word);
        if (i < effectiveCurLine.tokens.length - 1) {
          line1Builder.addText(' ');
        }
      }

      final line1Para = line1Builder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(line1Para, ui.Offset(lyricsLeft, currentY));
      currentY += 48.0;
    } else {
      // Si está vacía
      final emptyBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 26, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0x99FFFFFF)))
        ..addText('♪ ♪ ♪');
      final emptyPara = emptyBuilder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(emptyPara, ui.Offset(lyricsLeft, currentY));
      currentY += 48.0;
    }

    // Línea 2 (Siguiente estrofa)
    final String line2Text = nextLyricLine?.fullText ?? (nextLine ?? '');
    if (line2Text.isNotEmpty) {
      final line2Builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 25, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xB3FFFFFF), fontWeight: ui.FontWeight.w500))
        ..addText(line2Text);
      final line2Para = line2Builder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(line2Para, ui.Offset(lyricsLeft, currentY));
      currentY += 40.0;
    }

    // Línea 3 (Tercera estrofa de vista previa)
    final String line3Text = thirdLyricLine?.fullText ?? '';
    if (line3Text.isNotEmpty) {
      final line3Builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: 22, maxLines: 1),
      )
        ..pushStyle(ui.TextStyle(color: const ui.Color(0x66FFFFFF), fontWeight: ui.FontWeight.w400))
        ..addText(line3Text);
      final line3Para = line3Builder.build()..layout(ui.ParagraphConstraints(width: lyricsWidth));
      canvas.drawParagraph(line3Para, ui.Offset(lyricsLeft, currentY));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  /// Genera archivo de subtítulos sincronizados .srt para reproductores estándar
  Future<String> generateSrtSubtitles({
    List<String>? lines,
    int? totalDurationSeconds,
    List<({int startTimeMs, int endTimeMs, String text})>? timedCues,
    required String outputPath,
  }) async {
    final buffer = StringBuffer();

    if (timedCues != null && timedCues.isNotEmpty) {
      for (int i = 0; i < timedCues.length; i++) {
        final cue = timedCues[i];
        final startMs = cue.startTimeMs;
        final endMs = cue.endTimeMs > startMs ? cue.endTimeMs : startMs + 2000;

        buffer.writeln('${i + 1}');
        buffer.writeln('${_formatSrtTimestampMs(startMs)} --> ${_formatSrtTimestampMs(endMs)}');
        buffer.writeln(cue.text);
        buffer.writeln();
      }
    } else if (lines != null && lines.isNotEmpty && totalDurationSeconds != null && totalDurationSeconds > 0) {
      final int secondsPerLine = (totalDurationSeconds / lines.length).clamp(2, 8).toInt();
      for (int i = 0; i < lines.length; i++) {
        final startSec = i * secondsPerLine;
        final endSec = ((i + 1) * secondsPerLine).clamp(0, totalDurationSeconds);

        final startFormat = _formatSrtTimestamp(startSec);
        final endFormat = _formatSrtTimestamp(endSec > startSec ? endSec : startSec + 2);

        buffer.writeln('${i + 1}');
        buffer.writeln('$startFormat --> $endFormat');
        buffer.writeln(lines[i]);
        buffer.writeln();
      }
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

  String _formatSrtTimestampMs(int totalMs) {
    final hours = totalMs ~/ 3600000;
    final minutes = (totalMs % 3600000) ~/ 60000;
    final seconds = (totalMs % 60000) ~/ 1000;
    final millis = totalMs % 1000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')},${millis.toString().padLeft(3, '0')}';
  }
}
