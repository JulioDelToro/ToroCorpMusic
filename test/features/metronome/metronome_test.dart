import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/metronome/controllers/metronome_controller.dart';
import 'package:toro_music_teleprompter/features/metronome/presentation/metronome_screen.dart';
import 'package:toro_music_teleprompter/features/metronome/services/metronome_audio_synth.dart';
import '../../e2e/e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R4 & R7: MetronomeAudioSynth (Procedural Audio Synthesis)', () {
    test('Synthesizes valid 16-bit PCM RIFF WAV audio buffers for downbeat (1760 Hz)', () {
      final synth = MetronomeAudioSynth();
      final downbeatWav = synth.downbeatWavBytes;

      // 1. Minimum WAV header size
      expect(downbeatWav.length, greaterThanOrEqualTo(44));

      // 2. Verified via E2ETestHelpers.isValidPcmWav
      expect(
        E2ETestHelpers.isValidPcmWav(downbeatWav),
        isTrue,
        reason: 'Downbeat audio buffer must conform to standard RIFF/WAV format',
      );

      // 3. Verified via MetronomeAudioSynth.isValidPcmWav
      expect(MetronomeAudioSynth.isValidPcmWav(downbeatWav), isTrue);

      // 4. Header byte layout inspection
      final bdata = ByteData.sublistView(downbeatWav);
      expect(String.fromCharCodes(downbeatWav.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(downbeatWav.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(downbeatWav.sublist(12, 16)), equals('fmt '));
      expect(bdata.getUint16(20, Endian.little), equals(1), reason: 'Audio format must be Linear PCM (1)');
      expect(bdata.getUint16(22, Endian.little), equals(1), reason: 'Channel count must be Mono (1)');
      expect(bdata.getUint32(24, Endian.little), equals(44100), reason: 'Sample rate must be 44.1 kHz');
      expect(bdata.getUint16(34, Endian.little), equals(16), reason: 'Bits per sample must be 16-bit');
      expect(String.fromCharCodes(downbeatWav.sublist(36, 40)), equals('data'));

      // 5. Sample payload inspection: verify non-zero waveform values
      bool hasNonZeroSample = false;
      for (int i = 44; i < downbeatWav.length; i += 2) {
        if (bdata.getInt16(i, Endian.little) != 0) {
          hasNonZeroSample = true;
          break;
        }
      }
      expect(hasNonZeroSample, isTrue, reason: 'PCM audio data must contain real synthesized audio samples');
    });

    test('Synthesizes valid 16-bit PCM RIFF WAV audio buffers for regular beat (880 Hz)', () {
      final synth = MetronomeAudioSynth();
      final regularWav = synth.regularWavBytes;

      expect(regularWav.length, greaterThanOrEqualTo(44));
      expect(E2ETestHelpers.isValidPcmWav(regularWav), isTrue);
      expect(MetronomeAudioSynth.isValidPcmWav(regularWav), isTrue);

      // Downbeat (1760 Hz) and Regular click (880 Hz) must have distinct audio buffers
      expect(
        synth.downbeatWavBytes,
        isNot(equals(synth.regularWavBytes)),
        reason: 'Downbeat (high pitch) and regular beat must produce distinct frequency waveforms',
      );

      // getBeatSound helper
      expect(synth.getBeatSound(isDownbeat: true), equals(synth.downbeatWavBytes));
      expect(synth.getBeatSound(isDownbeat: false), equals(synth.regularWavBytes));
    });

    test('Custom parameter generation produces conforming WAV buffers', () {
      final customWav = MetronomeAudioSynth.generateClickWav(
        frequencyHz: 440.0,
        durationSec: 0.05,
        decayHalfLifeSec: 0.01,
        sampleRate: 22050,
      );

      expect(MetronomeAudioSynth.isValidPcmWav(customWav), isTrue);
      final bdata = ByteData.sublistView(customWav);
      expect(bdata.getUint32(24, Endian.little), equals(22050));
    });
  });

  group('R4: MetronomeController', () {
    late MetronomeController controller;

    setUp(() {
      controller = MetronomeController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initializes with nominal defaults (120 BPM, 4/4 time signature, stopped)', () {
      expect(controller.bpm, equals(120));
      expect(controller.timeSignature, equals(MetronomeTimeSignature.fourFour));
      expect(controller.isPlaying, isFalse);
      expect(controller.currentBeat, equals(0));
      expect(controller.tempoMarking, equals('Allegro'));
    });

    test('BPM clamping strictly enforces range [40, 240]', () {
      controller.setBpm(40);
      expect(controller.bpm, equals(40));

      controller.setBpm(39);
      expect(controller.bpm, equals(40), reason: 'BPM cannot decrement below 40');

      controller.setBpm(0);
      expect(controller.bpm, equals(40));

      controller.decrementBpm();
      expect(controller.bpm, equals(40), reason: 'decrementBpm at 40 remains 40');

      controller.setBpm(240);
      expect(controller.bpm, equals(240));

      controller.setBpm(241);
      expect(controller.bpm, equals(240), reason: 'BPM cannot exceed 240');

      controller.incrementBpm();
      expect(controller.bpm, equals(240), reason: 'incrementBpm at 240 remains 240');

      controller.setBpm(135);
      expect(controller.bpm, equals(135));
      controller.incrementBpm();
      expect(controller.bpm, equals(136));
      controller.decrementBpm();
      expect(controller.bpm, equals(135));
    });

    test('Tempo markings accurately reflect classical Italian musical terms', () {
      controller.setBpm(50);
      expect(controller.tempoMarking, equals('Largo'));

      controller.setBpm(62);
      expect(controller.tempoMarking, equals('Larghetto'));

      controller.setBpm(72);
      expect(controller.tempoMarking, equals('Adagio'));

      controller.setBpm(90);
      expect(controller.tempoMarking, equals('Andante'));

      controller.setBpm(115);
      expect(controller.tempoMarking, equals('Moderato'));

      controller.setBpm(130);
      expect(controller.tempoMarking, equals('Allegro'));

      controller.setBpm(165);
      expect(controller.tempoMarking, equals('Vivace'));

      controller.setBpm(185);
      expect(controller.tempoMarking, equals('Presto'));

      controller.setBpm(220);
      expect(controller.tempoMarking, equals('Prestissimo'));
    });

    test('Tap Tempo computes accurate BPM and handles 2.5s inactivity reset', () {
      var time = DateTime(2026, 1, 1, 10, 0, 0);

      // 1. Single tap: returns current BPM
      expect(controller.tapTempo(time), equals(120));

      // 500ms intervals (120 BPM)
      time = time.add(const Duration(milliseconds: 500));
      expect(controller.tapTempo(time), equals(120));

      // Inactivity > 2.5s resets tap history before testing 60 BPM
      time = time.add(const Duration(milliseconds: 2600));
      controller.tapTempo(time); // First tap after reset establishes new anchor
      time = time.add(const Duration(milliseconds: 1000));
      controller.tapTempo(time);
      time = time.add(const Duration(milliseconds: 1000));
      expect(controller.tapTempo(time), inInclusiveRange(58, 62));

      // Rapid bursts clamped to 240 (filling the 8-tap rolling buffer)
      for (int i = 0; i < 8; i++) {
        time = time.add(const Duration(milliseconds: 30));
        controller.tapTempo(time);
      }
      expect(controller.bpm, equals(240));

      // Inactivity > 2.5s resets tap history
      final postSilence = time.add(const Duration(milliseconds: 2600));
      final bpmAfterSilence = controller.tapTempo(postSilence);
      expect(bpmAfterSilence, equals(240), reason: 'First tap after reset returns existing BPM without calculation');
    });

    test('Time signature changes update beats per bar', () {
      controller.setTimeSignature(MetronomeTimeSignature.twoFour);
      expect(controller.timeSignature.beatsPerBar, equals(2));
      expect(controller.timeSignature.label, equals('2/4'));

      controller.setTimeSignature(MetronomeTimeSignature.threeFour);
      expect(controller.timeSignature.beatsPerBar, equals(3));
      expect(controller.timeSignature.label, equals('3/4'));

      controller.setTimeSignature(MetronomeTimeSignature.sixEight);
      expect(controller.timeSignature.beatsPerBar, equals(6));
      expect(controller.timeSignature.label, equals('6/8'));

      controller.setTimeSignature(MetronomeTimeSignature.fourFour);
      expect(controller.timeSignature.beatsPerBar, equals(4));
    });

    test('Start and stop cycle manages state and dispatches audio clicks', () {
      final clicks = <(int beat, bool isDownbeat)>[];

      final testController = MetronomeController(
        initialBpm: 120,
        onPlayClick: (beat, isDownbeat, bytes) {
          clicks.add((beat, isDownbeat));
        },
      );

      expect(testController.isPlaying, isFalse);
      expect(testController.currentBeat, equals(0));

      testController.start();
      expect(testController.isPlaying, isTrue);
      expect(testController.currentBeat, equals(1));
      expect(testController.isDownbeat, isTrue);
      expect(clicks.isNotEmpty, isTrue);
      expect(clicks.first.$1, equals(1));
      expect(clicks.first.$2, isTrue, reason: 'First beat must be an accented downbeat');

      testController.stop();
      expect(testController.isPlaying, isFalse);
      expect(testController.currentBeat, equals(0));
      expect(testController.isDownbeat, isFalse);

      testController.dispose();
    });

    test('Dynamic tempo decrease while running re-anchors clock without excessive delay', () async {
      final clickTimes = <DateTime>[];

      final testController = MetronomeController(
        initialBpm: 240, // 250ms per beat
        onPlayClick: (beat, isDownbeat, bytes) {
          clickTimes.add(DateTime.now());
        },
      );

      testController.start();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final timeAtChange = DateTime.now();
      testController.setBpm(120); // 500ms per beat

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      testController.stop();

      final clicksAfterChange = clickTimes.where((t) => t.isAfter(timeAtChange)).toList();
      expect(clicksAfterChange.length, greaterThanOrEqualTo(2));

      for (int i = 1; i < clicksAfterChange.length; i++) {
        final intervalMs = clicksAfterChange[i].difference(clicksAfterChange[i - 1]).inMilliseconds;
        // At 120 BPM (500ms per beat), interval should be around 500ms, not multi-second delay or burst
        expect(intervalMs, inInclusiveRange(400, 650));
      }

      testController.dispose();
    });
  });

  group('R4: MetronomeScreen (Widget & Interaction)', () {
    testWidgets('Renders all required controls: BPM readout, Slider, chips, Tap Tempo, Play/Stop', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: MetronomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. App Bar title
      expect(find.text('Metrónomo'), findsOneWidget);
      expect(find.text('Precisión de Estudio • Cero Latencia'), findsOneWidget);

      // 2. Large BPM readout
      expect(find.text('120'), findsOneWidget);
      expect(find.text('ALLEGRO'), findsOneWidget);

      // 3. Micro-adjuster buttons
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);

      // 4. Slider
      expect(find.byType(Slider), findsOneWidget);

      // 5. Time signature chips
      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);
      expect(find.text('6/8'), findsOneWidget);

      // 6. Tap Tempo button
      expect(find.text('TAP TEMPO'), findsOneWidget);

      // 7. Play / Stop button
      expect(find.text('INICIAR METRÓNOMO'), findsOneWidget);
    });

    testWidgets('Tapping +/- 1 BPM buttons increments and decrements tempo', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('120'), findsOneWidget);

      // Tap +1
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(controller.bpm, equals(121));
      expect(find.text('121'), findsOneWidget);

      // Tap -1 twice
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(controller.bpm, equals(119));
      expect(find.text('119'), findsOneWidget);
    });

    testWidgets('Tapping time signature chips changes active signature and LED pulse count', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Initial 4/4 has 4 beat dots
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsNothing);

      // Switch to 3/4
      await tester.tap(find.text('3/4'));
      await tester.pumpAndSettle();
      expect(controller.timeSignature, equals(MetronomeTimeSignature.threeFour));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsNothing);

      // Switch to 6/8
      await tester.tap(find.text('6/8'));
      await tester.pumpAndSettle();
      expect(controller.timeSignature, equals(MetronomeTimeSignature.sixEight));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('Tapping Iniciar/Detener toggles playback state and button text', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INICIAR METRÓNOMO'), findsOneWidget);
      expect(controller.isPlaying, isFalse);

      // Start metronome
      await tester.tap(find.text('INICIAR METRÓNOMO'));
      await tester.pump();
      expect(controller.isPlaying, isTrue);
      expect(find.text('DETENER METRÓNOMO'), findsOneWidget);

      // Stop metronome
      await tester.tap(find.text('DETENER METRÓNOMO'));
      await tester.pump();
      expect(controller.isPlaying, isFalse);
      expect(find.text('INICIAR METRÓNOMO'), findsOneWidget);
    });

    testWidgets('Tapping Tap Tempo button calculates tempo', (tester) async {
      E2ETestHelpers.setupTestViewport(tester);
      final controller = MetronomeController(initialBpm: 120);

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final tapButton = find.text('TAP TEMPO');
      expect(tapButton, findsOneWidget);

      await tester.tap(tapButton);
      await tester.pump();
      // Should not throw or crash
      expect(controller.bpm, equals(120));
    });

    testWidgets('Ultra-small screen responsiveness: zero layout overflows on 320x480 with Prestissimo', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? caughtError;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtError = details;
        originalOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      final controller = MetronomeController(initialBpm: 220); // 'Prestissimo' - longest marking

      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(caughtError, isNull, reason: 'Must not trigger RenderFlex overflow on 320px screen');
      expect(tester.takeException(), isNull);
      expect(find.text('220'), findsOneWidget);
      expect(find.text('PRESTISSIMO'), findsOneWidget);

      controller.dispose();
    });
  });
}
