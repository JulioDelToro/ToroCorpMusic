import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/camera/services/hands_free_trigger_service.dart';
import 'package:toro_music_teleprompter/features/camera/widgets/camera_viewfinder_widget.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 Empirical Verification: Tipo de Grabación Absence', () {
    test('Empirical: studio_recording_screen.dart file has 0 occurrences of Tipo de Grabación', () {
      final file = File('lib/features/studio/presentation/studio_recording_screen.dart');
      expect(file.existsSync(), isTrue, reason: 'studio_recording_screen.dart must exist');

      final content = file.readAsStringSync();
      expect(content.toLowerCase().contains('tipo de grabación'), isFalse,
          reason: 'studio_recording_screen.dart must not contain "tipo de grabación"');
      expect(content.toLowerCase().contains('tipo de grabacion'), isFalse,
          reason: 'studio_recording_screen.dart must not contain "tipo de grabacion"');
      expect(content.contains('_openRecordingModeModal'), isFalse,
          reason: '_openRecordingModeModal must be removed');
      expect(content.contains('_buildRecordingModeTile'), isFalse,
          reason: '_buildRecordingModeTile must be removed');
    });

    testWidgets('Empirical: Drawer widget tree has 0 occurrences of Tipo de Grabación', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: StudioRecordingScreen(),
      ));

      // Open drawer menu
      await tester.tap(find.byType(AnimatedIcon));
      await tester.pumpAndSettle();

      // Verify complete absence of Tipo de Grabación
      expect(find.text('Tipo de Grabación'), findsNothing);
      expect(find.textContaining('Grabación ('), findsNothing);
      expect(find.textContaining('Grabacion'), findsNothing);
    });
  });

  group('Milestone 2 Empirical Verification: HandsFreeTriggerService Countdown Progression & Reset', () {
    testWidgets('Empirical: Countdown progression runs precisely 5 -> 4 -> 3 -> 2 -> 1 -> trigger', (tester) async {
      final progression = <int>[];
      bool completed = false;

      final service = HandsFreeTriggerService(
        onCountdownStart: () {
          // Record current countdown seconds on each tick
        },
        onCountdownComplete: () {
          completed = true;
        },
      );

      expect(service.countdownSeconds, equals(5));
      expect(service.isCountingDown, isFalse);

      // Trigger via voice
      service.handleVoiceKeyword('grabar');
      expect(service.isCountingDown, isTrue);
      expect(service.countdownSeconds, equals(5));
      progression.add(service.countdownSeconds);

      // Tick 1 second -> 4
      await tester.pump(const Duration(seconds: 1));
      expect(service.countdownSeconds, equals(4));
      expect(service.isCountingDown, isTrue);
      expect(completed, isFalse);
      progression.add(service.countdownSeconds);

      // Tick 2 seconds -> 3
      await tester.pump(const Duration(seconds: 1));
      expect(service.countdownSeconds, equals(3));
      expect(service.isCountingDown, isTrue);
      expect(completed, isFalse);
      progression.add(service.countdownSeconds);

      // Tick 3 seconds -> 2
      await tester.pump(const Duration(seconds: 1));
      expect(service.countdownSeconds, equals(2));
      expect(service.isCountingDown, isTrue);
      expect(completed, isFalse);
      progression.add(service.countdownSeconds);

      // Tick 4 seconds -> 1
      await tester.pump(const Duration(seconds: 1));
      expect(service.countdownSeconds, equals(1));
      expect(service.isCountingDown, isTrue);
      expect(completed, isFalse);
      progression.add(service.countdownSeconds);

      // Tick 5 seconds -> triggers completion
      await tester.pump(const Duration(seconds: 1));
      expect(service.countdownSeconds, equals(0));
      expect(service.isCountingDown, isFalse);
      expect(completed, isTrue);
      progression.add(service.countdownSeconds);

      expect(progression, equals([5, 4, 3, 2, 1, 0]),
          reason: 'Countdown must step through 5, 4, 3, 2, 1, and complete at 0');

      service.dispose();
    });

    testWidgets('Empirical: Cancellation mid-countdown resets cleanly to 5 and suppresses completion callback', (tester) async {
      bool completed = false;
      int triggerCount = 0;

      final service = HandsFreeTriggerService(
        onCountdownStart: () => triggerCount++,
        onCountdownComplete: () => completed = true,
      );

      // Start countdown
      service.handleVoiceKeyword('grabar');
      expect(service.isCountingDown, isTrue);
      expect(service.countdownSeconds, equals(5));

      // Advance 2 seconds to reach 3
      await tester.pump(const Duration(seconds: 2));
      expect(service.countdownSeconds, equals(3));
      expect(service.isCountingDown, isTrue);

      // Cancel countdown
      service.cancelCountdown();
      expect(service.isCountingDown, isFalse, reason: 'isCountingDown must be false after cancel');
      expect(service.countdownSeconds, equals(5), reason: 'countdownSeconds must reset cleanly to 5 after cancel');

      // Advance 10 more seconds to prove timer is truly dead and will not trigger callback
      await tester.pump(const Duration(seconds: 10));
      expect(completed, isFalse, reason: 'Cancelled countdown must never invoke onCountdownComplete');
      expect(service.countdownSeconds, equals(5));

      // Re-trigger after cancellation: must start cleanly from 5 again
      service.handleVoiceKeyword('grabar');
      expect(service.isCountingDown, isTrue);
      expect(service.countdownSeconds, equals(5));

      // Allow full 5 seconds to complete
      await tester.pump(const Duration(seconds: 5));
      expect(completed, isTrue);
      expect(service.isCountingDown, isFalse);
      expect(triggerCount, greaterThanOrEqualTo(2));

      service.dispose();
    });

    testWidgets('Empirical: Multiple rapid cancel and re-trigger cycles always reset to 5', (tester) async {
      final service = HandsFreeTriggerService(
        onCountdownStart: () {},
        onCountdownComplete: () {},
      );

      for (int i = 0; i < 10; i++) {
        service.handleVoiceKeyword('grabar');
        expect(service.isCountingDown, isTrue);
        expect(service.countdownSeconds, equals(5));

        // Advance 1 to 3 seconds
        await tester.pump(Duration(seconds: (i % 3) + 1));
        expect(service.countdownSeconds, lessThan(5));

        // Cancel
        service.cancelCountdown();
        expect(service.isCountingDown, isFalse);
        expect(service.countdownSeconds, equals(5), reason: 'Cycle $i: must reset to 5 on cancel');
      }

      service.dispose();
    });
  });

  group('Milestone 2 Empirical Verification: Voice Utterance Triggering', () {
    test('Empirical: Case variations, whitespace, and Spanish trigger words fire countdown', () {
      final validCommands = [
        'grabar',
        'GRABAR',
        'Grabar',
        '  grabar  ',
        'graba',
        'iniciar',
        'comenzar',
        'record',
        'start',
      ];

      for (final cmd in validCommands) {
        bool started = false;
        final service = HandsFreeTriggerService(onCountdownStart: () => started = true);

        service.handleVoiceKeyword(cmd);
        expect(started, isTrue, reason: 'Command "$cmd" must trigger countdown');
        expect(service.isCountingDown, isTrue);
        expect(service.countdownSeconds, equals(5));

        service.dispose();
      }
    });

    test('Empirical: Non-triggering words and partial words do NOT fire countdown', () {
      final invalidCommands = [
        'cantar',
        'detener',
        'pausa',
        'parar',
        'hola',
        'grabadora',
        'desgrabar',
        '',
        '   ',
      ];

      for (final cmd in invalidCommands) {
        bool started = false;
        final service = HandsFreeTriggerService(onCountdownStart: () => started = true);

        service.handleVoiceKeyword(cmd);
        expect(started, isFalse, reason: 'Command "$cmd" must NOT trigger countdown');
        expect(service.isCountingDown, isFalse);

        service.dispose();
      }
    });

    test('Empirical: Disarmed service ignores voice commands', () {
      bool started = false;
      final service = HandsFreeTriggerService(onCountdownStart: () => started = true);
      service.setArmed(false);

      service.handleVoiceKeyword('grabar');
      expect(started, isFalse, reason: 'Disarmed service must ignore "grabar"');
      expect(service.isCountingDown, isFalse);

      service.setArmed(true);
      service.handleVoiceKeyword('grabar');
      expect(started, isTrue, reason: 'Re-armed service must accept "grabar"');
      expect(service.isCountingDown, isTrue);

      service.dispose();
    });

    testWidgets('Empirical: Utterance while countdown is active does NOT reset or restart the countdown', (tester) async {
      int startCount = 0;
      final service = HandsFreeTriggerService(
        onCountdownStart: () => startCount++,
        onCountdownComplete: () {},
      );

      service.handleVoiceKeyword('grabar');
      expect(startCount, equals(1));
      expect(service.countdownSeconds, equals(5));

      // Advance 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(service.countdownSeconds, equals(3));

      // Attempt second utterance
      service.handleVoiceKeyword('grabar');
      expect(service.countdownSeconds, equals(3), reason: 'Second utterance must not reset countdown');
      expect(service.isCountingDown, isTrue);

      // Finish remaining 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(service.countdownSeconds, equals(0));
      expect(service.isCountingDown, isFalse);

      service.dispose();
    });
  });

  group('Milestone 2 Empirical Verification: Camera On-Demand Switch & Dynamic Island Collapse', () {
    testWidgets('Empirical: Camera switch toggles camera and forces dynamic island to collapse', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: StudioRecordingScreen(),
      ));

      final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
      expect(capsuleFinder, findsOneWidget);

      // 1. Initial State: Camera inactive, Dynamic island compact
      final viewfinder = tester.widget<CameraViewfinderWidget>(find.byType(CameraViewfinderWidget));
      expect(viewfinder.isCameraActive, isFalse, reason: 'Camera must start inactive by default');
      expect(tester.getSize(capsuleFinder).height, inInclusiveRange(80.0, 140.0));

      // 2. Expand Dynamic Island to Music Stand mode while camera is off
      final expandBtn = find.descendant(
        of: capsuleFinder,
        matching: find.byIcon(Icons.unfold_more),
      );
      expect(expandBtn, findsOneWidget, reason: 'Expand button must exist when camera is off');
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      expect(tester.getSize(capsuleFinder).height, greaterThan(200.0), reason: 'Island must expand to Music Stand');
      expect(find.text('Modo Atril'), findsOneWidget);

      // 3. Open drawer menu
      await tester.tap(find.byType(AnimatedIcon));
      await tester.pumpAndSettle();

      // Find Camera on-demand switch in drawer
      final cameraSwitchFinder = find.byType(Switch);
      expect(cameraSwitchFinder, findsOneWidget, reason: 'Drawer must contain camera switch');
      final cameraSwitchBefore = tester.widget<Switch>(cameraSwitchFinder);
      expect(cameraSwitchBefore.value, isFalse, reason: 'Camera switch must initially be off');

      // 4. Toggle camera switch to ON
      await tester.tap(cameraSwitchFinder);
      await tester.pumpAndSettle();

      // Close menu if still open
      if (find.byIcon(Icons.tune).evaluate().isNotEmpty) {
        await tester.tap(find.byType(AnimatedIcon));
        await tester.pumpAndSettle();
      }

      // 5. Verify camera is now active
      final viewfinderActive = tester.widget<CameraViewfinderWidget>(find.byType(CameraViewfinderWidget));
      expect(viewfinderActive.isCameraActive, isTrue, reason: 'Camera must now be active');

      // 6. Verify Dynamic Island has automatically and smoothly collapsed back to compact capsule
      final collapsedHeight = tester.getSize(capsuleFinder).height;
      expect(collapsedHeight, lessThanOrEqualTo(140.0),
          reason: 'Dynamic island must auto-collapse to compact capsule when camera turns on');
      expect(find.text('Modo Atril'), findsNothing);

      // 7. Verify expand button is completely absent while camera is active
      expect(
        find.descendant(of: capsuleFinder, matching: find.byIcon(Icons.unfold_more)),
        findsNothing,
        reason: 'Expand button must not be available when camera is active',
      );

      // 8. Re-open drawer and toggle camera switch back OFF
      await tester.tap(find.byType(AnimatedIcon));
      await tester.pumpAndSettle();

      final cameraSwitchTurnOff = find.byType(Switch);
      expect(cameraSwitchTurnOff, findsOneWidget);
      final cameraSwitchActive = tester.widget<Switch>(cameraSwitchTurnOff);
      expect(cameraSwitchActive.value, isTrue);

      await tester.tap(cameraSwitchTurnOff);
      await tester.pumpAndSettle();

      if (find.byIcon(Icons.tune).evaluate().isNotEmpty) {
        await tester.tap(find.byType(AnimatedIcon));
        await tester.pumpAndSettle();
      }

      // 9. Camera is off again, expand button reappears
      final viewfinderInactiveAgain = tester.widget<CameraViewfinderWidget>(find.byType(CameraViewfinderWidget));
      expect(viewfinderInactiveAgain.isCameraActive, isFalse);

      final expandBtnReappeared = find.descendant(
        of: capsuleFinder,
        matching: find.byIcon(Icons.unfold_more),
      );
      expect(expandBtnReappeared, findsOneWidget, reason: 'Expand button must reappear when camera is toggled off');

      // 10. Re-expand island to verify functionality remains intact
      await tester.tap(expandBtnReappeared);
      await tester.pumpAndSettle();
      expect(tester.getSize(capsuleFinder).height, greaterThan(200.0));
      expect(find.text('Modo Atril'), findsOneWidget);
    });
  });
}
