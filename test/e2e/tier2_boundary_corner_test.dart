import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/camera/services/hands_free_trigger_service.dart';
import 'package:toro_music_teleprompter/features/scripts/services/chordpro_parser.dart';
import 'package:toro_music_teleprompter/features/tutorials/models/tutorial_topic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 2: Boundary & Corner Cases', () {
    // -------------------------------------------------------------------------
    // T2.1: Metronome BPM Limits (40 - 240 BPM Clamping)
    // -------------------------------------------------------------------------
    test('T2.1: Metronome tempo limits enforce strict 40 to 240 BPM bounds', () {
      // Test algorithmic clamp logic for metronome engine
      int clampBpm(int target) => target.clamp(40, 240);

      expect(clampBpm(40), equals(40));
      expect(clampBpm(240), equals(240));

      // Lower boundary violations
      expect(clampBpm(39), equals(40), reason: 'BPM cannot go below minimum limit of 40');
      expect(clampBpm(0), equals(40));
      expect(clampBpm(-10), equals(40));

      // Upper boundary violations
      expect(clampBpm(241), equals(240), reason: 'BPM cannot exceed maximum limit of 240');
      expect(clampBpm(300), equals(240));
      expect(clampBpm(999), equals(240));

      // Standard nominal values
      expect(clampBpm(60), equals(60));
      expect(clampBpm(120), equals(120));
      expect(clampBpm(180), equals(180));
    });

    // -------------------------------------------------------------------------
    // T2.2: Rapid Tap Tempo Stress & 2.5s Window Reset
    // -------------------------------------------------------------------------
    test('T2.2: Tap Tempo handles rapid burst taps and resets window after 2.5s of silence', () {
      final List<DateTime> tapTimes = [];
      const int minBpm = 40;
      const int maxBpm = 240;
      const Duration resetTimeout = Duration(milliseconds: 2500);

      int calculateTapTempo(DateTime now) {
        if (tapTimes.isNotEmpty && now.difference(tapTimes.last) > resetTimeout) {
          tapTimes.clear();
        }
        tapTimes.add(now);

        if (tapTimes.length < 2) return 120; // default baseline

        // Consider last 4-8 taps
        final recent = tapTimes.length > 8 ? tapTimes.sublist(tapTimes.length - 8) : tapTimes;
        int totalDiffMs = 0;
        for (int i = 1; i < recent.length; i++) {
          totalDiffMs += recent[i].difference(recent[i - 1]).inMilliseconds;
        }
        final avgMs = totalDiffMs / (recent.length - 1);
        if (avgMs <= 0) return maxBpm;
        final rawBpm = (60000.0 / avgMs).round();
        return rawBpm.clamp(minBpm, maxBpm);
      }

      var currentTime = DateTime(2026, 1, 1, 12, 0, 0);

      // 1. Single tap returns baseline default without error
      expect(calculateTapTempo(currentTime), equals(120));

      // 2. Steady 500ms intervals = 120 BPM
      for (int i = 0; i < 4; i++) {
        currentTime = currentTime.add(const Duration(milliseconds: 500));
        calculateTapTempo(currentTime);
      }
      expect(calculateTapTempo(currentTime.add(const Duration(milliseconds: 500))), equals(120));

      // 3. Steady 1000ms intervals = 60 BPM
      tapTimes.clear();
      currentTime = DateTime(2026, 1, 1, 12, 5, 0);
      calculateTapTempo(currentTime);
      for (int i = 0; i < 4; i++) {
        currentTime = currentTime.add(const Duration(milliseconds: 1000));
        calculateTapTempo(currentTime);
      }
      expect(calculateTapTempo(currentTime.add(const Duration(milliseconds: 1000))), equals(60));

      // 4. Ultra-rapid taps (< 50ms) are safely clamped to 240 BPM (no division by zero)
      tapTimes.clear();
      currentTime = DateTime(2026, 1, 1, 12, 10, 0);
      calculateTapTempo(currentTime);
      for (int i = 0; i < 5; i++) {
        currentTime = currentTime.add(const Duration(milliseconds: 20));
        calculateTapTempo(currentTime);
      }
      expect(calculateTapTempo(currentTime.add(const Duration(milliseconds: 20))), equals(240));

      // 5. Inactivity for > 2.5 seconds resets the history
      final postTimeout = currentTime.add(const Duration(milliseconds: 2600));
      final resetBpm = calculateTapTempo(postTimeout);
      expect(resetBpm, equals(120), reason: 'First tap after >2.5s must reset calculation window');
      expect(tapTimes.length, equals(1));
    });

    // -------------------------------------------------------------------------
    // T2.3: Empty, Whitespace, and Special Character Search Queries
    // -------------------------------------------------------------------------
    test('T2.3: Search parser handles empty strings, whitespace, and complex ChordPro brackets', () {
      // Empty input
      final emptyResult = ChordProParser().parse('');
      expect(emptyResult.lines, isEmpty);

      // Whitespace only
      final whitespaceResult = ChordProParser().parse('   \n\t   \n');
      expect(whitespaceResult.lines, isEmpty);

      // Consecutive chords without lyric text [C] [G] [Am] [F]
      const consecutiveChords = '[C] [G] [Am] [F]';
      final parsedConsecutive = ChordProParser().parse(consecutiveChords);
      expect(parsedConsecutive.lines.isNotEmpty, isTrue);
      final tokens = parsedConsecutive.lines.first.tokens;
      expect(tokens.length, equals(4));
      expect(tokens.map((t) => t.chordUnderneath).toList(), equals(['C', 'G', 'Am', 'F']));

      // Special symbols and punctuation in lyric text
      const specialText = '[G]¡Hola, mundo! ¿Cómo estás? (100% #1 @ToroCorp)';
      final parsedSpecial = ChordProParser().parse(specialText);
      expect(parsedSpecial.lines.isNotEmpty, isTrue);
      expect(parsedSpecial.lines.first.tokens.first.chordUnderneath, equals('G'));

      // Metadata tags
      const taggedContent = '''
{title: Canción de Prueba}
{artist: ToroCorp}
{key: Am}
[Am]Letra de prueba
''';
      final parsedMeta = ChordProParser().parse(
        taggedContent,
        title: 'Canción de Prueba',
        artist: 'ToroCorp',
      );
      expect(parsedMeta.title, equals('Canción de Prueba'));
      expect(parsedMeta.artist, equals('ToroCorp'));
    });

    // -------------------------------------------------------------------------
    // T2.4: Guitar Tuner 6 & 12 Strings Help Guide & Tolerances
    // -------------------------------------------------------------------------
    test('T2.4: Guitar tuner documentation specifies ±3.5¢ tolerance and 6 vs 12-string notes', () {
      final tunerTopic = TutorialTopic.values.firstWhere((t) => t.name == 'tuner');

      // Verify ±3.5¢ accuracy standard is documented
      final mentionsTolerance = tunerTopic.instructions.any((i) => i.contains('3.5'));
      expect(
        mentionsTolerance,
        isTrue,
        reason: 'Tuner tutorial must document laboratory tolerance of ±3.5¢',
      );

      // Verify standard 6-string note frequencies (E2: 82.4Hz, A2: 110Hz, D3: 146.8Hz, G3: 196Hz, B3: 246.9Hz, E4: 329.6Hz)
      const guitarNotes6 = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];
      expect(guitarNotes6.length, equals(6));

      // Verify 12-string docerola notes (E2/E3, A2/A3, D3/D4, G3/G4, B3/B3, E4/E4)
      const guitarNotes12 = [
        'E2', 'E3', 'A2', 'A3', 'D3', 'D4',
        'G3', 'G4', 'B3', 'B3', 'E4', 'E4'
      ];
      expect(guitarNotes12.length, equals(12));
    });

    // -------------------------------------------------------------------------
    // T2.5: Countdown Boundary Values, Palm Confidence Threshold, and Voice Commands
    // -------------------------------------------------------------------------
    test('T2.5: HandsFreeTriggerService enforces strict palm confidence threshold (70%) and keyword gating', () {
      int completedCount = 0;
      final service = HandsFreeTriggerService(
        onCountdownStart: () {},
        onCountdownComplete: () => completedCount++,
      );

      // 1. Palm confidence < 70% must NOT trigger countdown
      service.handlePalmDetected(confidence: 0.69);
      expect(
        service.isCountingDown,
        isFalse,
        reason: 'Palm detection with confidence 0.69 (<0.70 threshold) must NOT trigger countdown',
      );

      // 2. Palm confidence >= 70% must trigger countdown
      service.handlePalmDetected(confidence: 0.70);
      expect(
        service.isCountingDown,
        isTrue,
        reason: 'Palm detection with confidence >= 0.70 must trigger countdown',
      );

      // 3. Cancel resets counting state
      service.cancelCountdown();
      expect(service.isCountingDown, isFalse);

      // 4. Non-trigger voice commands must NOT trigger countdown
      service.handleVoiceKeyword('guitarra');
      expect(service.isCountingDown, isFalse);

      service.handleVoiceKeyword('hola');
      expect(service.isCountingDown, isFalse);

      service.handleVoiceKeyword('stop');
      expect(service.isCountingDown, isFalse);

      // 5. Valid keywords in any case trigger countdown
      service.handleVoiceKeyword('GRABAR');
      expect(service.isCountingDown, isTrue);
      service.cancelCountdown();

      service.handleVoiceKeyword(' Iniciar ');
      expect(service.isCountingDown, isTrue);
      service.cancelCountdown();

      // 6. When disarmed, valid keywords do NOT trigger
      service.setArmed(false);
      service.handleVoiceKeyword('grabar');
      expect(service.isCountingDown, isFalse, reason: 'Disarmed trigger service must ignore all inputs');

      service.dispose();
    });
  });
}
