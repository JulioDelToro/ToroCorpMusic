import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/constants/app_colors.dart';
import 'package:toro_music_teleprompter/core/widgets/brawl_gold_shimmer.dart';
import 'package:toro_music_teleprompter/features/camera/services/hands_free_trigger_service.dart';
import 'package:toro_music_teleprompter/features/camera/widgets/camera_viewfinder_widget.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';
import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 4: Real-World Scenarios', () {
    // -------------------------------------------------------------------------
    // Scenario 4.1: End-to-End Solo Rehearsal Workflow
    // -------------------------------------------------------------------------
    testWidgets('T4.1: Musician executes complete solo rehearsal workflow (Battery saving -> Metronome -> Lyrics Search -> Music Stand)', (tester) async {
      // Step 1: Musician launches app
      await E2ETestHelpers.pumpStudioScreen(tester);
      expect(find.byType(StudioRecordingScreen), findsOneWidget);

      // Verify camera starts inactive (Pure Black OLED) to maximize battery during rehearsal
      final viewfinder = tester.widget<CameraViewfinderWidget>(find.byType(CameraViewfinderWidget));
      expect(
        viewfinder.isCameraActive,
        isFalse,
        reason: 'Rehearsal: Camera must be off by default to conserve battery for extended practice',
      );

      // Step 2: Musician opens lateral drawer menu
      await E2ETestHelpers.openLateralMenu(tester);

      // Verify header displays gold shimmer title "ToroCorp Music" without logo image
      expect(find.byType(BrawlGoldShimmer), findsWidgets);
      expect(find.text('ToroCorp Music'), findsWidgets);

      // Verify "Tipo de Grabación" is absent and "Metrónomo" is present
      expect(find.text('Tipo de Grabación'), findsNothing);
      expect(find.text('Metrónomo'), findsOneWidget);

      // Step 4: Musician selects repertoire / lyrics
      expect(find.textContaining('Letras'), findsOneWidget);
      await E2ETestHelpers.closeLateralMenu(tester);

      // Step 5: Mount sample song into teleprompter
      final songScript = E2ETestHelpers.createSampleSong();
      expect(songScript.lines.length, equals(4));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.pureBlackOled,
            body: FloatingTeleprompterCapsule(
              allLines: songScript.lines,
              currentLineIndex: 0,
              currentLine: songScript.lines.first,
              currentWordIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Words and chords are visible on screen
      expect(find.text('Ella'), findsWidgets);
      expect(find.text('durmió'), findsWidgets);
      expect(find.text('Bm'), findsWidgets);
      expect(find.text('G'), findsWidgets);

      // Step 6: Musician inspects Music Stand mode
      final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
      expect(capsuleFinder, findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 4.2: End-to-End Live Performance & 5s Hands-Free Recording Workflow
    // -------------------------------------------------------------------------
    testWidgets('T4.2: Musician executes live recording workflow with 5-second hands-free countdown', (tester) async {
      // Step 1: Musician launches app and sets up rehearsal
      await E2ETestHelpers.pumpStudioScreen(tester);

      // Step 2: Configure HandsFreeTriggerService with 5-second countdown
      bool countdownTriggered = false;
      bool recordingStarted = false;

      final triggerService = HandsFreeTriggerService(
        onCountdownStart: () => countdownTriggered = true,
        onCountdownComplete: () => recordingStarted = true,
      );

      expect(
        triggerService.countdownDuration.inSeconds,
        equals(5),
        reason: 'Performance: Countdown must be 5 seconds (R2) so hands can return to guitar neck',
      );

      // Step 3: Musician arms hands-free trigger
      expect(triggerService.isArmed, isTrue);

      // Step 4: Musician says "grabar" without taking hands off guitar
      triggerService.handleVoiceKeyword('grabar');

      expect(countdownTriggered, isTrue);
      expect(triggerService.isCountingDown, isTrue);
      expect(
        triggerService.countdownSeconds,
        equals(5),
        reason: 'Performance: Countdown starts cleanly at 5 seconds',
      );

      // Step 5: Dynamic Island teleprompter capsule remains anchored directly under front camera
      final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
      expect(capsuleFinder, findsOneWidget);
      final capsuleSize = tester.getSize(capsuleFinder);
      expect(
        capsuleSize.height,
        lessThanOrEqualTo(140.0),
        reason: 'Performance: Compact capsule under camera maintains eye contact with lens during recording',
      );

      expect(recordingStarted, isFalse);
      triggerService.dispose();
    });
  });
}
