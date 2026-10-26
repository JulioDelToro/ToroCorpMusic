import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tuner/models/tuning_note.dart';
import 'package:toro_music_teleprompter/features/tuner/services/pitch_detector.dart';

void main() {
  group('PitchDetector 6-String Tests', () {
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

    test('PitchDetector string locking checks exact selected string', () {
      final detector = PitchDetector();
      // Locked to 1st string E4 (329.63 Hz)
      final result = detector.analyzeFrequency(
        329.60,
        guitarType: GuitarType.sixString,
        lockedStringIndex: 1,
      );
      expect(result.closestNote, equals("E4"));
      expect(result.targetStringIndex, equals(1));
      expect(result.isInTune, isTrue);
    });
  });

  group('PitchDetector 12-String Tests (Docerola)', () {
    test('12-string tuning has 12 reference notes', () {
      expect(PitchDetector.standard12StringTuning.length, equals(12));
    });

    test('PitchDetector identifies 12-string octave string (G4 - 392 Hz)', () {
      final detector = PitchDetector();
      final result = detector.analyzeFrequency(
        392.1,
        guitarType: GuitarType.twelveString,
        lockedStringIndex: 6,
      );
      expect(result.closestNote, equals("G4"));
      expect(result.targetStringIndex, equals(6));
      expect(result.isInTune, isTrue);
    });

    test('PitchDetector handles zero frequency with locked string', () {
      final detector = PitchDetector();
      final result = detector.analyzeFrequency(
        0,
        guitarType: GuitarType.twelveString,
        lockedStringIndex: 3,
      );
      expect(result.closestNote, equals("B3"));
      expect(result.targetStringIndex, equals(3));
      expect(result.isInTune, isFalse);
    });
  });
}
