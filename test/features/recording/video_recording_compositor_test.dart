import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/recording/models/recording_mode.dart';
import 'package:toro_music_teleprompter/features/recording/services/video_recording_compositor.dart';

void main() {
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
}
