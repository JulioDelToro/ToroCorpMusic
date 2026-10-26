import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tuner/services/pitch_detector.dart';

void main() {
  test('PitchDetector identifies A2 (110 Hz) within tolerance', () {
    final detector = PitchDetector();
    final result = detector.analyzeFrequency(110.2);
    expect(result.closestNote, equals("A2"));
    expect(result.isInTune, isTrue);
  });

  test('PitchDetector calculates flat cents offset accurately', () {
    final detector = PitchDetector();
    final result = detector.analyzeFrequency(105.0);
    expect(result.closestNote, equals("A2"));
    expect(result.centsOffset < 0, isTrue);
    expect(result.isInTune, isFalse);
  });
}
