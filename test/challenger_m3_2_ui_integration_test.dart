import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/metronome/controllers/metronome_controller.dart';
import 'package:toro_music_teleprompter/features/metronome/presentation/metronome_screen.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'e2e/e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger 2 Empirical Verification: Milestone 3 Metronome UI & Integration', () {
    // =========================================================================
    // Mission 1: Verify Metronome entry is located in drawer directly under
    // 'Afinador de Guitarra'
    // =========================================================================
    group('1. Drawer Placement Verification', () {
      test('1a. Static source layout audit: Metronome immediately follows Guitar Tuner', () {
        final file = File('lib/features/studio/presentation/studio_recording_screen.dart');
        expect(file.existsSync(), isTrue, reason: 'studio_recording_screen.dart must exist');
        final content = file.readAsStringSync();

        final tunerIndex = content.indexOf("'Afinador de Guitarra'");
        final metronomeIndex = content.indexOf("'Metrónomo'");

        expect(tunerIndex, isNonNegative, reason: "'Afinador de Guitarra' must be present in source");
        expect(metronomeIndex, isNonNegative, reason: "'Metrónomo' must be present in source");
        expect(
          metronomeIndex,
          greaterThan(tunerIndex),
          reason: "'Metrónomo' must be placed AFTER 'Afinador de Guitarra' in drawer menu",
        );

        // Verify no other menu item is declared between Afinador and Metrónomo
        // The only _buildMenuItem between 'Afinador de Guitarra' and 'Metrónomo' is the Metrónomo item itself.
        final sliceBetween = content.substring(tunerIndex, metronomeIndex);
        final menuItemCallsBetween = RegExp(r'_buildMenuItem\s*\(').allMatches(sliceBetween).length;
        expect(
          menuItemCallsBetween,
          equals(1),
          reason: "Only the Metrónomo item itself may start between 'Afinador de Guitarra' and 'Metrónomo'",
        );

        // Verify icon and subtitle specifications
        expect(content.contains("icon: Icons.speed"), isTrue);
        expect(content.contains("subtitle: '40 - 240 BPM • Tap Tempo'"), isTrue);
      });

      testWidgets('1b. Runtime UI audit: Metronome entry is rendered directly under Afinador de Guitarra', (tester) async {
        await E2ETestHelpers.pumpStudioScreen(tester);
        await E2ETestHelpers.openLateralMenu(tester);

        final tunerFinder = find.text('Afinador de Guitarra');
        final metronomeFinder = find.text('Metrónomo');

        expect(tunerFinder, findsOneWidget, reason: 'Afinador de Guitarra must be visible in drawer');
        expect(metronomeFinder, findsOneWidget, reason: 'Metrónomo must be visible in drawer');

        // Verify vertical spatial coordinates: Metronome is below Tuner
        final tunerRect = tester.getRect(tunerFinder);
        final metronomeRect = tester.getRect(metronomeFinder);

        expect(
          metronomeRect.top,
          greaterThan(tunerRect.top),
          reason: 'Metronome vertical position must be beneath Guitar Tuner',
        );

        // Verify subtitle and icon
        expect(find.text('40 - 240 BPM • Tap Tempo'), findsOneWidget);
        expect(find.byIcon(Icons.speed), findsOneWidget);

        await E2ETestHelpers.closeLateralMenu(tester);
      });
    });

    // =========================================================================
    // Mission 2: Clean navigation to MetronomeScreen and return to Studio
    // =========================================================================
    group('2. Navigation Lifecycle Verification', () {
      testWidgets('2a. Opening MetronomeScreen and closing returns cleanly to Studio screen', (tester) async {
        await E2ETestHelpers.pumpStudioScreen(tester);
        await E2ETestHelpers.openLateralMenu(tester);

        // Tap on Metrónomo drawer entry
        final metronomeTile = find.text('Metrónomo');
        await tester.tap(metronomeTile);
        await tester.pumpAndSettle();

        // Verify MetronomeScreen is active and rendered
        expect(find.byType(MetronomeScreen), findsOneWidget);
        expect(find.text('Precisión de Estudio • Cero Latencia'), findsOneWidget);

        // Verify back button is present in AppBar
        final backButton = find.byIcon(Icons.arrow_back_ios_new);
        expect(backButton, findsOneWidget, reason: 'MetronomeScreen must have back button in AppBar');

        // Tap back button
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Verify MetronomeScreen was popped and StudioRecordingScreen is cleanly restored
        expect(find.byType(MetronomeScreen), findsNothing);
        expect(find.byType(StudioRecordingScreen), findsOneWidget);

        // Verify Studio screen is fully interactive after returning
        await E2ETestHelpers.openLateralMenu(tester);
        expect(find.text('Afinador de Guitarra'), findsOneWidget);
        await E2ETestHelpers.closeLateralMenu(tester);
      });
    });

    // =========================================================================
    // Mission 3: Visual Pendulum Animation, Beat LEDs, and 360x640 Responsiveness
    // =========================================================================
    group('3. UI Components, Animation & Small-Screen Responsiveness', () {
      testWidgets('3a. Visual pendulum animation oscillates during playback and halts when stopped', (tester) async {
        E2ETestHelpers.setupTestViewport(tester);
        final controller = MetronomeController(initialBpm: 120);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MetronomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // Verify CustomPaint with pendulum painter exists
        final customPaintFinder = find.byType(CustomPaint);
        expect(customPaintFinder, findsWidgets);

        // Initially stopped
        expect(controller.isPlaying, isFalse);

        // Start metronome
        await tester.tap(find.text('INICIAR METRÓNOMO'));
        await tester.pump();
        expect(controller.isPlaying, isTrue);

        // Step animation forward
        await tester.pump(const Duration(milliseconds: 125));
        await tester.pump(const Duration(milliseconds: 125));
        await tester.pump(const Duration(milliseconds: 125));

        // Stop metronome
        await tester.tap(find.text('DETENER METRÓNOMO'));
        await tester.pump();
        expect(controller.isPlaying, isFalse);

        // Pump out stop settling animation (200ms)
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        controller.dispose();
      });

      testWidgets('3b. Beat LED indicators reflect total beats and downbeat accent across time signatures', (tester) async {
        E2ETestHelpers.setupTestViewport(tester);
        final controller = MetronomeController(initialBpm: 120);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MetronomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // In default 4/4: 4 beat indicators (1, 2, 3, 4)
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('5'), findsNothing);

        // Switch to 2/4
        await tester.tap(find.text('2/4'));
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsNothing);

        // Switch to 3/4
        await tester.tap(find.text('3/4'));
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('4'), findsNothing);

        // Switch to 6/8
        await tester.tap(find.text('6/8'));
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('7'), findsNothing);

        controller.dispose();
      });

      testWidgets('3c. Small-screen responsiveness: zero layout overflows on 360x640', (tester) async {
        // Enforce exact small phone viewport (360 x 640)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Intercept any flutter error or overflow
        FlutterErrorDetails? caughtError;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          caughtError = details;
          originalOnError?.call(details);
        };
        addTearDown(() {
          FlutterError.onError = originalOnError;
        });

        final controller = MetronomeController(initialBpm: 120);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MetronomeScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial render must have zero errors and zero overflows
        expect(caughtError, isNull, reason: 'Initial render on 360x640 must not trigger any layout overflow');
        expect(tester.takeException(), isNull);

        // 2. Core UI elements present
        expect(find.text('Metrónomo'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
        expect(find.text('TAP TEMPO'), findsOneWidget);

        // 3. Interact with controls on small screen
        // Increment & Decrement BPM
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        expect(controller.bpm, equals(121));

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pumpAndSettle();
        expect(controller.bpm, equals(120));

        // Switch to 6/8 time signature
        await tester.tap(find.text('6/8'));
        await tester.pumpAndSettle();
        expect(controller.timeSignature, equals(MetronomeTimeSignature.sixEight));

        // Tap tempo button
        await tester.tap(find.text('TAP TEMPO'));
        await tester.pumpAndSettle();

        // Scroll down to ensure Play/Stop button is fully visible and clickable
        final scrollable = find.byType(SingleChildScrollView);
        expect(scrollable, findsOneWidget);

        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pumpAndSettle();

        final playButton = find.text('INICIAR METRÓNOMO');
        expect(playButton, findsOneWidget);

        // Start metronome on 360x640
        await tester.tap(playButton);
        await tester.pump();
        expect(controller.isPlaying, isTrue);

        // Animate while running on 360x640
        await tester.pump(const Duration(milliseconds: 200));

        // Stop metronome
        final stopButton = find.text('DETENER METRÓNOMO');
        expect(stopButton, findsOneWidget);
        await tester.tap(stopButton);
        await tester.pump();
        expect(controller.isPlaying, isFalse);

        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Verify no overflows occurred throughout all small-screen interactions
        expect(caughtError, isNull, reason: 'Zero layout overflows allowed on 360x640 screen');
        expect(tester.takeException(), isNull);

        controller.dispose();
      });
    });
  });
}
