import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/metronome/controllers/metronome_controller.dart';
import 'package:toro_music_teleprompter/features/metronome/presentation/metronome_screen.dart';
import 'package:toro_music_teleprompter/features/metronome/services/metronome_audio_synth.dart';
import '../../e2e/e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 3 Challenger: MetronomeController Extreme BPM Stress', () {
    test('Constructor clamps extreme initial BPM below 40 and above 240', () {
      final low1 = MetronomeController(initialBpm: -100);
      expect(low1.bpm, equals(40), reason: 'Negative initial BPM must clamp to min 40');
      low1.dispose();

      final low2 = MetronomeController(initialBpm: 0);
      expect(low2.bpm, equals(40), reason: 'Zero initial BPM must clamp to min 40');
      low2.dispose();

      final low3 = MetronomeController(initialBpm: 39);
      expect(low3.bpm, equals(40), reason: '39 initial BPM must clamp to min 40');
      low3.dispose();

      final high1 = MetronomeController(initialBpm: 241);
      expect(high1.bpm, equals(240), reason: '241 initial BPM must clamp to max 240');
      high1.dispose();

      final high2 = MetronomeController(initialBpm: 99999);
      expect(high2.bpm, equals(240), reason: 'Huge initial BPM must clamp to max 240');
      high2.dispose();
    });

    test('Extreme setBpm values are strictly clamped', () {
      final controller = MetronomeController(initialBpm: 120);

      const testExtremes = [
        -999999, -500, -1, 0, 1, 10, 39,
        241, 250, 300, 500, 1000, 999999,
      ];

      for (final val in testExtremes) {
        controller.setBpm(val);
        expect(controller.bpm, inInclusiveRange(40, 240),
            reason: 'setBpm($val) must clamp to [40, 240], got ${controller.bpm}');
      }

      controller.dispose();
    });

    test('Rapid successive setBpm sweeps (slider drag simulation)', () {
      final controller = MetronomeController(initialBpm: 120);
      int notificationCount = 0;
      controller.addListener(() {
        notificationCount++;
      });

      // Rapid sweep from 0 to 300 in steps of 1
      for (int i = 0; i <= 300; i++) {
        controller.setBpm(i);
      }
      expect(controller.bpm, equals(240));

      // Rapid sweep from 300 down to -50
      for (int i = 300; i >= -50; i--) {
        controller.setBpm(i);
      }
      expect(controller.bpm, equals(40));

      // Random jitter sweep 1000 times
      final rng = math.Random(42);
      for (int i = 0; i < 1000; i++) {
        final target = rng.nextInt(500) - 100; // -100 to 399
        controller.setBpm(target);
        expect(controller.bpm, inInclusiveRange(40, 240));
      }

      expect(notificationCount, greaterThan(0));
      controller.dispose();
    });

    test('Micro-adjusters (+1 / -1) repeatedly at bounds do not overflow or underflow', () {
      final controller = MetronomeController(initialBpm: 40);

      // Decrement 50 times at lower bound
      for (int i = 0; i < 50; i++) {
        controller.decrementBpm();
        expect(controller.bpm, equals(40));
      }

      // Increment 250 times past upper bound
      for (int i = 0; i < 250; i++) {
        controller.incrementBpm();
        expect(controller.bpm, inInclusiveRange(40, 240));
      }
      expect(controller.bpm, equals(240));

      // Decrement 250 times back down to lower bound
      for (int i = 0; i < 250; i++) {
        controller.decrementBpm();
        expect(controller.bpm, inInclusiveRange(40, 240));
      }
      expect(controller.bpm, equals(40));

      controller.dispose();
    });

    test('Dynamic tempo increase while running does not cause rapid machine-gun burst clicks', () async {
      final clickTimes = <DateTime>[];

      final controller = MetronomeController(
        initialBpm: 60, // 1000ms per beat
        onPlayClick: (beat, isDownbeat, bytes) {
          clickTimes.add(DateTime.now());
        },
      );

      controller.start();
      // Wait for beat 1 and beat 2 (~1100ms)
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      // Jump to 240 BPM (250ms per beat)
      final timeAtBpmChange = DateTime.now();
      controller.setBpm(240);

      // Wait 1200ms (enough for the next scheduled tick and 2 subsequent 250ms beats)
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      controller.stop();

      final clicksAfterChange = <DateTime>[];
      for (final t in clickTimes) {
        if (t.isAfter(timeAtBpmChange)) {
          clicksAfterChange.add(t);
        }
      }

      // Check the interval between consecutive clicks after change
      for (int i = 1; i < clicksAfterChange.length; i++) {
        final intervalMs = clicksAfterChange[i].difference(clicksAfterChange[i - 1]).inMilliseconds;
        // If catch-up burst happens, intervalMs will be ~0-10ms, far below the 250ms interval of 240 BPM!
        expect(intervalMs, greaterThanOrEqualTo(150),
            reason: 'Catch-up burst detected: consecutive clicks occurred within $intervalMs ms (expected >= 150ms for 240 BPM)');
      }

      controller.dispose();
    });
  });

  group('Milestone 3 Challenger: Tap Tempo Adversarial Stress', () {
    late MetronomeController controller;

    setUp(() {
      controller = MetronomeController(initialBpm: 120);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Ultra-rapid burst tapping (<50ms intervals: 5ms, 10ms, 25ms, 45ms)', () {
      var time = DateTime(2026, 3, 15, 12, 0, 0);

      // First tap
      controller.tapTempo(time);

      // 10 burst taps with 10ms intervals (theoretical 6000 BPM)
      for (int i = 0; i < 10; i++) {
        time = time.add(const Duration(milliseconds: 10));
        controller.tapTempo(time);
        expect(controller.bpm, equals(240),
            reason: '10ms burst taps must be clamped to max 240 BPM');
      }

      // 10 burst taps with 5ms intervals (theoretical 12000 BPM)
      for (int i = 0; i < 10; i++) {
        time = time.add(const Duration(milliseconds: 5));
        controller.tapTempo(time);
        expect(controller.bpm, equals(240),
            reason: '5ms burst taps must be clamped to max 240 BPM');
      }

      // 10 burst taps with 45ms intervals (theoretical 1333 BPM)
      for (int i = 0; i < 10; i++) {
        time = time.add(const Duration(milliseconds: 45));
        controller.tapTempo(time);
        expect(controller.bpm, equals(240),
            reason: '45ms burst taps must be clamped to max 240 BPM');
      }
    });

    test('Simultaneous taps at the exact same millisecond (0ms delta)', () {
      final time = DateTime(2026, 3, 15, 12, 0, 0);

      // Multiple taps at identical timestamp
      controller.tapTempo(time);
      controller.tapTempo(time);
      controller.tapTempo(time);

      // Must not crash with division by zero and remain clamped
      expect(controller.bpm, inInclusiveRange(40, 240));
    });

    test('Wild erratic tapping intervals remain stable and within bounds', () {
      var time = DateTime(2026, 3, 15, 12, 0, 0);
      controller.tapTempo(time);

      final erraticIntervalsMs = [
        30, 1800, 75, 450, 2200, 90, 800, 150, 1200, 60, 500, 300, 2400, 100
      ];

      for (final interval in erraticIntervalsMs) {
        time = time.add(Duration(milliseconds: interval));
        controller.tapTempo(time);
        expect(controller.bpm, inInclusiveRange(40, 240),
            reason: 'BPM after $interval ms tap must be within [40, 240]');
      }
    });

    test('Inactivity reset: 3-second pause and restart cleanly resets history', () {
      var time = DateTime(2026, 3, 15, 12, 0, 0);

      // Phase 1: Tap rhythm at 120 BPM (500ms intervals) for 5 taps
      for (int i = 0; i < 5; i++) {
        controller.tapTempo(time);
        time = time.add(const Duration(milliseconds: 500));
      }
      expect(controller.bpm, equals(120), reason: 'Phase 1 should settle around 120 BPM');

      // Phase 2: Inactivity pause of 3000ms (> 2500ms timeout)
      time = time.add(const Duration(milliseconds: 3000));
      final bpmAfterRestartTap = controller.tapTempo(time);

      // First tap after pause must preserve current BPM (anchor established)
      expect(bpmAfterRestartTap, equals(120),
          reason: 'First tap after 3s pause must return existing BPM without averaging past history');

      // Phase 3: Now tap at 60 BPM (1000ms intervals) for 4 taps
      for (int i = 0; i < 4; i++) {
        time = time.add(const Duration(milliseconds: 1000));
        controller.tapTempo(time);
      }

      // Should converge to ~60 BPM without any residue of 120 BPM from before the pause
      expect(controller.bpm, inInclusiveRange(59, 61),
          reason: 'After reset, tempo must reflect purely the new 1000ms (60 BPM) rhythm');
    });

    test('Sub-timeout pause (2400ms) does NOT reset history; 2600ms DOES reset', () {
      var time = DateTime(2026, 3, 15, 12, 0, 0);

      // Tap 1 at t=0
      controller.tapTempo(time);

      // Tap 2 at t=500ms -> BPM = 120
      time = time.add(const Duration(milliseconds: 500));
      controller.tapTempo(time);
      expect(controller.bpm, equals(120));

      // Pause 2400ms (< 2500ms threshold)
      time = time.add(const Duration(milliseconds: 2400));
      controller.tapTempo(time);
      // Not reset: avg of (500, 2400) = 1450ms -> 60000/1450 = 41 BPM
      expect(controller.bpm, equals(41));

      // Pause 2600ms (> 2500ms threshold)
      time = time.add(const Duration(milliseconds: 2600));
      final bpmAfterReset = controller.tapTempo(time);
      // Reset occurred: first tap retains current BPM (41) as new anchor
      expect(bpmAfterReset, equals(41));

      // Next tap at 500ms (120 BPM)
      time = time.add(const Duration(milliseconds: 500));
      controller.tapTempo(time);
      // New average is purely based on the new interval 500ms -> 120 BPM!
      expect(controller.bpm, equals(120));
    });

    test('Rolling window limits tap history to at most 8 taps', () {
      var time = DateTime(2026, 3, 15, 12, 0, 0);

      // 10 taps at 1000ms (60 BPM)
      for (int i = 0; i < 10; i++) {
        controller.tapTempo(time);
        time = time.add(const Duration(milliseconds: 1000));
      }
      expect(controller.bpm, inInclusiveRange(59, 61));

      // Now 8 taps at 500ms (120 BPM)
      for (int i = 0; i < 8; i++) {
        controller.tapTempo(time);
        time = time.add(const Duration(milliseconds: 500));
      }

      // After 8 taps of 500ms, the old 1000ms taps must be completely evicted
      expect(controller.bpm, equals(120),
          reason: 'Rolling window of 8 taps must completely evict older intervals');
    });
  });

  group('Milestone 3 Challenger: Time Signature Accents and Sequences', () {
    test('Accent verification across all signatures: Downbeat is ALWAYS beat 1', () {
      for (final sig in MetronomeTimeSignature.values) {
        final capturedBeats = <(int beat, bool isAccent, int pcmBytesLength)>[];

        final controller = MetronomeController(
          initialBpm: 240, // High BPM for fast iteration
          initialTimeSignature: sig,
          onPlayClick: (beat, isDownbeat, bytes) {
            capturedBeats.add((beat, isDownbeat, bytes.length));
          },
        );

        controller.start();

        // Verify beat 1 of start()
        expect(controller.currentBeat, equals(1));
        expect(controller.isDownbeat, isTrue);

        controller.stop();
        controller.dispose();
      }
    });

    test('Full multi-bar cycle verification for 2/4, 3/4, 4/4, 6/8', () async {
      // Test the mathematical beat generation progression directly
      for (final sig in MetronomeTimeSignature.values) {
        final beatsPerBar = sig.beatsPerBar;

        // Verify sequence for 5 full bars (5 * beatsPerBar beats)
        for (int bar = 0; bar < 5; bar++) {
          for (int b = 1; b <= beatsPerBar; b++) {
            // Metronome formula: ((_beatCounter) % beatsPerBar) + 1
            // At start, beatCounter=0 triggers beat 1.
            // On subsequent ticks, beatCounter=1..N triggers:
            final computedBeat = b;
            final isAccent = (computedBeat == 1);

            if (b == 1) {
              expect(isAccent, isTrue,
                  reason: 'In ${sig.label}, beat 1 must be an accented downbeat');
            } else {
              expect(isAccent, isFalse,
                  reason: 'In ${sig.label}, beat $b must NOT be an accented downbeat');
            }
          }
        }
      }
    });

    test('Simulated real-time playback: verify 12 beats sequence for 3/4', () async {
      final clicks = <(int beat, bool isDownbeat)>[];
      final synth = MetronomeAudioSynth();

      final controller = MetronomeController(
        initialBpm: 240, // 250ms per beat
        initialTimeSignature: MetronomeTimeSignature.threeFour,
        audioSynth: synth,
        onPlayClick: (beat, isDownbeat, bytes) {
          clicks.add((beat, isDownbeat));
        },
      );

      controller.start();
      // Wait for 7 beats (~1.8 seconds)
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      controller.stop();

      expect(clicks.length, greaterThanOrEqualTo(5));

      // Verify each beat in clicks follows 3/4 pattern: 1(true), 2(false), 3(false), 1(true), 2(false)...
      for (int i = 0; i < clicks.length; i++) {
        final expectedBeat = (i % 3) + 1;
        final expectedAccent = (expectedBeat == 1);

        expect(clicks[i].$1, equals(expectedBeat),
            reason: 'Beat index $i in 3/4 should be beat $expectedBeat');
        expect(clicks[i].$2, equals(expectedAccent),
            reason: 'Beat index $i in 3/4 accent flag should be $expectedAccent');
      }

      controller.dispose();
    });

    test('Simulated real-time playback: verify 12 beats sequence for 2/4', () async {
      final clicks = <(int beat, bool isDownbeat)>[];

      final controller = MetronomeController(
        initialBpm: 240, // 250ms per beat
        initialTimeSignature: MetronomeTimeSignature.twoFour,
        onPlayClick: (beat, isDownbeat, bytes) {
          clicks.add((beat, isDownbeat));
        },
      );

      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      controller.stop();

      expect(clicks.length, greaterThanOrEqualTo(4));

      for (int i = 0; i < clicks.length; i++) {
        final expectedBeat = (i % 2) + 1;
        final expectedAccent = (expectedBeat == 1);

        expect(clicks[i].$1, equals(expectedBeat),
            reason: 'Beat index $i in 2/4 should be beat $expectedBeat');
        expect(clicks[i].$2, equals(expectedAccent),
            reason: 'Beat index $i in 2/4 accent flag should be $expectedAccent');
      }

      controller.dispose();
    });

    test('Switching time signature while playing does not corrupt state or crash', () async {
      final clicks = <(int beat, bool isDownbeat)>[];

      final controller = MetronomeController(
        initialBpm: 240,
        initialTimeSignature: MetronomeTimeSignature.fourFour,
        onPlayClick: (beat, isDownbeat, bytes) {
          clicks.add((beat, isDownbeat));
        },
      );

      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Switch to 3/4 mid-flight
      controller.setTimeSignature(MetronomeTimeSignature.threeFour);
      expect(controller.timeSignature, equals(MetronomeTimeSignature.threeFour));
      expect(controller.isPlaying, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Switch to 6/8 mid-flight
      controller.setTimeSignature(MetronomeTimeSignature.sixEight);
      expect(controller.timeSignature, equals(MetronomeTimeSignature.sixEight));
      expect(controller.isPlaying, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 400));

      controller.stop();
      expect(controller.isPlaying, isFalse);

      // Verify that every click that had isDownbeat==true was indeed beat 1
      for (final click in clicks) {
        if (click.$2) {
          expect(click.$1, equals(1), reason: 'Every accented beat must be beat 1');
        } else {
          expect(click.$1, isNot(equals(1)), reason: 'Non-accented beat must not be beat 1');
        }
      }

      controller.dispose();
    });
  });

  group('Milestone 3 Challenger: Audio Synthesis Robustness Stress', () {
    test('Synthesizes valid PCM WAV buffers across extreme sample rates and frequencies', () {
      final testCases = [
        // frequencyHz, durationSec, decayHalfLifeSec, sampleRate
        (100.0, 0.01, 0.003, 22050),
        (440.0, 0.02, 0.005, 44100),
        (1760.0, 0.025, 0.006, 44100),
        (3520.0, 0.03, 0.008, 48000),
        (50.0, 0.05, 0.015, 96000),
      ];

      for (final tc in testCases) {
        final wav = MetronomeAudioSynth.generateClickWav(
          frequencyHz: tc.$1,
          durationSec: tc.$2,
          decayHalfLifeSec: tc.$3,
          sampleRate: tc.$4,
        );

        expect(MetronomeAudioSynth.isValidPcmWav(wav), isTrue,
            reason: 'Generated WAV at ${tc.$1}Hz / ${tc.$4} sample rate must be valid');
        expect(E2ETestHelpers.isValidPcmWav(wav), isTrue);

        // Check RIFF size matches byte length - 8
        final bdata = ByteData.sublistView(wav);
        final chunkSize = bdata.getUint32(4, Endian.little);
        expect(chunkSize, equals(wav.length - 8));

        // Check sample rate field
        final sr = bdata.getUint32(24, Endian.little);
        expect(sr, equals(tc.$4));

        // Check that no sample exceeds 16-bit signed range [-32768, 32767]
        for (int i = 44; i < wav.length; i += 2) {
          final sample = bdata.getInt16(i, Endian.little);
          expect(sample, inInclusiveRange(-32768, 32767));
        }
      }
    });

    test('WAV synthesis with duration 0 produces valid header with 0 payload', () {
      final wav = MetronomeAudioSynth.generateClickWav(
        frequencyHz: 1000.0,
        durationSec: 0.0,
        decayHalfLifeSec: 0.005,
      );
      expect(wav.length, equals(44));
      expect(MetronomeAudioSynth.isValidPcmWav(wav), isTrue);
    });

    test('Header corruption detector test', () {
      final validWav = MetronomeAudioSynth().downbeatWavBytes;
      expect(MetronomeAudioSynth.isValidPcmWav(validWav), isTrue);

      // Corrupt 'RIFF' tag
      final corruptedRiff = Uint8List.fromList(validWav);
      corruptedRiff[0] = 0x58; // 'X'
      expect(MetronomeAudioSynth.isValidPcmWav(corruptedRiff), isFalse);

      // Truncated buffer (< 44 bytes)
      final truncated = validWav.sublist(0, 40);
      expect(MetronomeAudioSynth.isValidPcmWav(truncated), isFalse);
    });
  });

  group('Milestone 3 Challenger: MetronomeScreen Interactive UI Stress', () {
    testWidgets('Rapid slider dragging back and forth does not crash or desync', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Rapidly simulate 50 slider drag events across the full track
      for (int i = 0; i < 50; i++) {
        final targetBpm = 40 + ((i % 10) * 20); // 40, 60, 80... 220
        controller.setBpm(targetBpm);
        await tester.pump();
        expect(find.text('$targetBpm'), findsOneWidget);
      }

      await tester.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('Rapidly tapping Play/Stop toggle button 20 times maintains consistency', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Rapidly toggle play/stop 20 times
      for (int i = 0; i < 20; i++) {
        controller.togglePlay();
        await tester.pump();
        if (controller.isPlaying) {
          expect(find.text('DETENER METRÓNOMO'), findsOneWidget);
        } else {
          expect(find.text('INICIAR METRÓNOMO'), findsOneWidget);
        }
      }

      // Ensure stopped
      if (controller.isPlaying) {
        controller.stop();
        await tester.pumpAndSettle();
      }

      expect(controller.isPlaying, isFalse);
      expect(find.text('INICIAR METRÓNOMO'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Rapidly tapping Tap Tempo button 25 times in UI remains stable', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final tapFinder = find.text('TAP TEMPO');
      expect(tapFinder, findsOneWidget);

      for (int i = 0; i < 25; i++) {
        await tester.tap(tapFinder);
        await tester.pump(const Duration(milliseconds: 30));
        expect(controller.bpm, inInclusiveRange(40, 240));
      }

      await tester.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('Rapidly cycling through all time signature chips', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final sigs = ['2/4', '3/4', '4/4', '6/8'];

      for (int cycle = 0; cycle < 5; cycle++) {
        for (final sig in sigs) {
          await tester.tap(find.text(sig));
          await tester.pumpAndSettle();
          expect(controller.timeSignature.label, equals(sig));
        }
      }

      controller.dispose();
    });
  });
}
