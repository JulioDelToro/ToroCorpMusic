import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/recording/models/recording_mode.dart';
import 'package:toro_music_teleprompter/features/recording/services/video_recording_compositor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RecordingCompositor configures clean mode without overlay', () {
    final compositor = VideoRecordingCompositor();
    final config = compositor.buildConfig(mode: RecordingMode.clean, isProUser: false);

    expect(config.burnInSubtitles, isFalse);
    expect(config.applyWatermark, isTrue); // Free user gets watermark
  });

  test('RecordingCompositor enables overlay and removes watermark for Pro user', () {
    final compositor = VideoRecordingCompositor();
    final config = compositor.buildConfig(
      mode: RecordingMode.withScript,
      resolution: VideoResolution.fourK30,
      isProUser: true,
    );

    expect(config.burnInSubtitles, isTrue);
    expect(config.applyWatermark, isFalse);
    expect(config.resolution, equals(VideoResolution.fourK30));
  });

  test('RecordingCompositor generates standard SRT subtitles', () async {
    final compositor = VideoRecordingCompositor();
    final tempDir = Directory.systemTemp;
    final srtFile = '${tempDir.path}/test_subtitles_${DateTime.now().millisecondsSinceEpoch}.srt';

    final result = await compositor.generateSrtSubtitles(
      lines: ['Ella durmió al calor de las masas', 'Y yo desperté queriendo soñarla'],
      totalDurationSeconds: 10,
      outputPath: srtFile,
    );

    expect(File(result).existsSync(), isTrue);
    final content = await File(result).readAsString();
    expect(content, contains('1'));
    expect(content, contains('00:00:00,000 --> 00:00:05,000'));
    expect(content, contains('Ella durmió al calor de las masas'));
    expect(content, contains('2'));
    expect(content, contains('Y yo desperté queriendo soñarla'));

    // Limpieza
    try {
      await File(result).delete();
    } catch (_) {}
  });

  test('RecordingCompositor generates SRT subtitles from timed cues', () async {
    final compositor = VideoRecordingCompositor();
    final tempDir = Directory.systemTemp;
    final srtFile = '${tempDir.path}/test_timed_cues_${DateTime.now().millisecondsSinceEpoch}.srt';

    final result = await compositor.generateSrtSubtitles(
      timedCues: [
        (startTimeMs: 1200, endTimeMs: 4500, text: 'Primera línea cantada'),
        (startTimeMs: 4500, endTimeMs: 8200, text: 'Segunda línea cantada'),
      ],
      outputPath: srtFile,
    );

    expect(File(result).existsSync(), isTrue);
    final content = await File(result).readAsString();
    expect(content, contains('1'));
    expect(content, contains('00:00:01,200 --> 00:00:04,500'));
    expect(content, contains('Primera línea cantada'));
    expect(content, contains('2'));
    expect(content, contains('00:00:04,500 --> 00:00:08,200'));
    expect(content, contains('Segunda línea cantada'));

    try {
      await File(result).delete();
    } catch (_) {}
  });

  test('RecordingCompositor renders watermark overlay image to PNG', () async {
    final compositor = VideoRecordingCompositor();
    final tempDir = Directory.systemTemp;
    final pngFile = '${tempDir.path}/test_wm_${DateTime.now().millisecondsSinceEpoch}.png';

    final result = await compositor.renderWatermarkOverlayImage(
      outputPath: pngFile,
    );

    expect(File(result).existsSync(), isTrue);
    final bytes = await File(result).readAsBytes();
    expect(bytes.isNotEmpty, isTrue);
    expect(bytes[0], equals(0x89));
    expect(bytes[1], equals(0x50));

    try {
      await File(result).delete();
    } catch (_) {}
  });

  test('RecordingCompositor renders teleprompter overlay image to PNG', () async {
    final compositor = VideoRecordingCompositor();
    final tempDir = Directory.systemTemp;
    final pngFile = '${tempDir.path}/test_overlay_${DateTime.now().millisecondsSinceEpoch}.png';

    final result = await compositor.renderTeleprompterOverlayImage(
      title: 'De música ligera',
      currentLine: 'Ella durmió al calor de las masas',
      nextLine: 'Y yo desperté queriendo soñarla',
      chords: 'Bm  G  D  A',
      outputPath: pngFile,
    );

    expect(File(result).existsSync(), isTrue);
    final bytes = await File(result).readAsBytes();
    expect(bytes.isNotEmpty, isTrue);
    // Verificar firma de archivo PNG (primeros 4 bytes: 0x89 0x50 0x4E 0x47)
    expect(bytes[0], equals(0x89));
    expect(bytes[1], equals(0x50)); // 'P'
    expect(bytes[2], equals(0x4E)); // 'N'
    expect(bytes[3], equals(0x47)); // 'G'

    // Limpieza
    try {
      await File(result).delete();
    } catch (_) {}
  });
}
