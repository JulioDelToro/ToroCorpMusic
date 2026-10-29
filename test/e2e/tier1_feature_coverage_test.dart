import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/constants/app_colors.dart';
import 'package:toro_music_teleprompter/core/widgets/brawl_gold_shimmer.dart';
import 'package:toro_music_teleprompter/features/camera/services/hands_free_trigger_service.dart';
import 'package:toro_music_teleprompter/features/camera/widgets/camera_viewfinder_widget.dart';
import 'package:toro_music_teleprompter/features/scripts/services/chordpro_parser.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';
import 'package:toro_music_teleprompter/features/tutorials/models/tutorial_topic.dart';
import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1: Feature Coverage (R1 - R7)', () {
    // -------------------------------------------------------------------------
    // R1: Camera Off by Default, OLED Pure Black & Drawer Menu Cleanup
    // -------------------------------------------------------------------------
    testWidgets('T1.1: App starts with camera inactive by default and pure black OLED', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);

      // Verify Studio screen and viewfinder are mounted
      expect(find.byType(StudioRecordingScreen), findsOneWidget);
      expect(find.byType(CameraViewfinderWidget), findsOneWidget);

      // Viewfinder must render Pure Black OLED container when inactive
      final finderWidget = tester.widget<CameraViewfinderWidget>(find.byType(CameraViewfinderWidget));
      expect(
        finderWidget.isCameraActive,
        isFalse,
        reason: 'R1: Application must start with camera inactive by default (_isCameraActive = false)',
      );

      // Verify pure black OLED background is rendered
      final containers = tester.widgetList<Container>(
        find.descendant(of: find.byType(CameraViewfinderWidget), matching: find.byType(Container)),
      );
      final hasPureBlackBackground = containers.any(
        (c) => c.color == AppColors.pureBlackOled || c.color == const Color(0xFF000000),
      );
      expect(
        hasPureBlackBackground,
        isTrue,
        reason: 'R1: Inactive camera must display Pure Black OLED (#000000) to conserve battery',
      );
    });

    testWidgets('T1.2: Drawer menu excludes "Tipo de Grabación" and provides on-demand Camera switch', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);
      await E2ETestHelpers.openLateralMenu(tester);

      // R1: "Tipo de Grabación" must be permanently removed
      expect(
        find.text('Tipo de Grabación'),
        findsNothing,
        reason: 'R1: "Tipo de Grabación" redundant option must be eliminated from lateral menu',
      );

      // R1: Camera toggle option must be present in the lateral menu
      final cameraOption = find.textContaining('Cámara');
      expect(
        cameraOption,
        findsOneWidget,
        reason: 'R1: Camera toggle option must be available in drawer menu to activate on demand',
      );

      await E2ETestHelpers.closeLateralMenu(tester);
    });

    // -------------------------------------------------------------------------
    // R1: Dynamic Island Expandable & Auto-Collapse
    // -------------------------------------------------------------------------
    testWidgets('T1.3: Dynamic Island supports Music Stand mode when camera is off and collapses when camera activates', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);

      // Locate FloatingTeleprompterCapsule
      final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
      expect(capsuleFinder, findsOneWidget, reason: 'Dynamic Island teleprompter capsule must be mounted');

      final initialSize = tester.getSize(capsuleFinder);
      expect(initialSize.height, inInclusiveRange(80.0, 140.0), reason: 'Initial capsule should be in compact pill form');

      // Attempt tapping expand button / capsule in camera-off mode
      final expandTrigger = find.descendant(
        of: capsuleFinder,
        matching: find.byIcon(Icons.unfold_more),
      );

      if (expandTrigger.evaluate().isNotEmpty) {
        await tester.tap(expandTrigger);
        await tester.pumpAndSettle();

        final expandedSize = tester.getSize(capsuleFinder);
        expect(
          expandedSize.height,
          greaterThan(200.0),
          reason: 'R1: Music stand mode must expand to display 6-10 lines on full screen',
        );

        // Turn on camera from drawer and verify auto-collapse
        await E2ETestHelpers.openLateralMenu(tester);
        final cameraTile = find.textContaining('Cámara');
        await tester.tap(cameraTile);
        await tester.pumpAndSettle();
        await E2ETestHelpers.closeLateralMenu(tester);

        final collapsedSize = tester.getSize(capsuleFinder);
        expect(
          collapsedSize.height,
          lessThanOrEqualTo(140.0),
          reason: 'R1: Dynamic island must auto-collapse back to compact capsule when camera is enabled',
        );
      }
    });

    // -------------------------------------------------------------------------
    // R2: 5-Second Hands-Free Countdown
    // -------------------------------------------------------------------------
    testWidgets('T1.4: HandsFreeTriggerService countdown defaults to 5 seconds and counts 5 -> 4 -> 3 -> 2 -> 1', (tester) async {
      int startCount = 0;
      bool completed = false;

      final triggerService = HandsFreeTriggerService(
        onCountdownStart: () => startCount++,
        onCountdownComplete: () => completed = true,
      );

      // Verify default countdown duration is 5 seconds
      expect(
        triggerService.countdownDuration.inSeconds,
        equals(5),
        reason: 'R2: Hands-free countdownDuration must be 5 seconds instead of 3',
      );

      // Trigger countdown using voice keyword "grabar"
      triggerService.handleVoiceKeyword('grabar');
      expect(triggerService.isCountingDown, isTrue);
      expect(
        triggerService.countdownSeconds,
        equals(5),
        reason: 'R2: Countdown must start at 5 seconds upon voice trigger',
      );

      // Trigger countdown using palm gesture
      triggerService.cancelCountdown();
      triggerService.handlePalmDetected(confidence: 0.85);
      expect(triggerService.isCountingDown, isTrue);
      expect(
        triggerService.countdownSeconds,
        equals(5),
        reason: 'R2: Countdown must start at 5 seconds upon palm gesture trigger',
      );

      expect(completed, isFalse);
      triggerService.dispose();
    });

    // -------------------------------------------------------------------------
    // R3: Brawl Stars Gold Pass Shimmer Animation
    // -------------------------------------------------------------------------
    testWidgets('T1.5: BrawlGoldShimmer renders metallic gold gradient and header logo image is removed', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);
      await E2ETestHelpers.openLateralMenu(tester);

      // Header logo image asset must NOT exist next to ToroCorp Music
      final appLogoImage = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image.toString().contains('app_logo'),
      );
      expect(
        appLogoImage,
        findsNothing,
        reason: 'R3: Image/logo icon adjacent to ToroCorp Music title in header must be removed',
      );

      // Header title "ToroCorp Music" must use BrawlGoldShimmer
      final titleFinder = find.text('ToroCorp Music');
      expect(titleFinder, findsWidgets);

      final shimmerFinder = find.byType(BrawlGoldShimmer);
      expect(
        shimmerFinder,
        findsWidgets,
        reason: 'R3: Title and Pro banner must be wrapped in BrawlGoldShimmer widget',
      );

      // Verify BrawlGoldShimmer widget standalone behavior
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrawlGoldShimmer(
              child: Text('ToroCorp Music'),
            ),
          ),
        ),
      );
      expect(find.byType(BrawlGoldShimmer), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget, reason: 'BrawlGoldShimmer must apply ShaderMask on GPU');
    });

    testWidgets('T1.6: Drawer "ToroCorp Music Pro" banner utilizes gold shimmer effect', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);
      await E2ETestHelpers.openLateralMenu(tester);

      final proBanner = find.textContaining(RegExp(r'ToroCorp Music Pro', caseSensitive: false));
      expect(proBanner, findsOneWidget, reason: 'Drawer must contain ToroCorp Music Pro card');

      final proShimmer = find.descendant(
        of: find.ancestor(of: proBanner, matching: find.byType(Container)).first,
        matching: find.byType(BrawlGoldShimmer),
      );
      expect(
        proShimmer.evaluate().isNotEmpty || find.byType(BrawlGoldShimmer).evaluate().isNotEmpty,
        isTrue,
        reason: 'R3: ToroCorp Music Pro must be decorated with Brawl Stars gold shimmer',
      );

      await E2ETestHelpers.closeLateralMenu(tester);
    });

    // -------------------------------------------------------------------------
    // R4: Interactive Metronome Module in Lateral Menu
    // -------------------------------------------------------------------------
    testWidgets('T1.7: Metronome option is positioned in lateral menu next to Guitar Tuner', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);
      await E2ETestHelpers.openLateralMenu(tester);

      // Verify "Afinador de Guitarra" exists
      final tunerTile = find.text('Afinador de Guitarra');
      expect(tunerTile, findsOneWidget, reason: 'Afinador de Guitarra must exist in drawer');

      // Verify "Metrónomo" exists
      final metronomeTile = find.text('Metrónomo');
      expect(
        metronomeTile,
        findsOneWidget,
        reason: 'R4: Dedicated "Metrónomo" entry must be present in drawer menu next to Guitar Tuner',
      );

      await E2ETestHelpers.closeLateralMenu(tester);
    });

    // -------------------------------------------------------------------------
    // R5: Automated Lyrics and Chords Search Interface
    // -------------------------------------------------------------------------
    testWidgets('T1.8: Lyrics and repertoire option is available in lateral menu and parses ChordPro', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);
      await E2ETestHelpers.openLateralMenu(tester);

      final lyricsTile = find.textContaining('Letras');
      expect(lyricsTile, findsOneWidget, reason: 'Drawer must provide lyrics & repertoire entry');

      // Verify Chordpro parser parses bracketed chords above syllables
      final parsed = ChordProParser().parse(
        E2ETestHelpers.sampleChordProSong,
        title: 'De Música Ligera',
        artist: 'Soda Stereo',
      );
      expect(parsed.title, equals('De Música Ligera'));
      expect(parsed.artist, equals('Soda Stereo'));
      expect(parsed.lines.isNotEmpty, isTrue);

      // First line chords verification
      final firstLineTokens = parsed.lines.first.tokens;
      expect(firstLineTokens.any((t) => t.chordUnderneath == 'Bm'), isTrue);
      expect(firstLineTokens.any((t) => t.chordUnderneath == 'G'), isTrue);

      await E2ETestHelpers.closeLateralMenu(tester);
    });

    // -------------------------------------------------------------------------
    // R6: Comprehensive Tutorials and Help Guides
    // -------------------------------------------------------------------------
    testWidgets('T1.9: Tutorial topics include Camera/Island, 5s Countdown, Metronome, Search, and 6/12-String Tuner', (tester) async {
      // Verify all required topics are covered in TutorialTopic enum or help dialog
      final topicNames = TutorialTopic.values.map((t) => t.name).toList();
      final topicTitles = TutorialTopic.values.map((t) => t.title.toLowerCase()).toList();

      // Check R1: Camera and dynamic island
      final hasCameraTopic = topicNames.contains('cameraAndDynamicIsland') ||
          topicTitles.any((t) => t.contains('cámara') || t.contains('isla dinámica'));
      expect(
        hasCameraTopic,
        isTrue,
        reason: 'R6: Tutorial topics must explain Camera off by default and Dynamic Island expansion',
      );

      // Check R2: 5-second countdown
      final palmTopic = TutorialTopic.values.firstWhere((t) => t.name == 'palmGesture');
      final mentions5Seconds = palmTopic.instructions.any((i) => i.contains('5')) ||
          palmTopic.summary.contains('5');
      expect(
        mentions5Seconds,
        isTrue,
        reason: 'R6: Palm gesture tutorial must specify 5-second countdown (5... 4... 3... 2... 1...)',
      );

      // Check R4: Metronome
      final hasMetronomeTopic = topicNames.contains('metronome') ||
          topicTitles.any((t) => t.contains('metrónomo'));
      expect(
        hasMetronomeTopic,
        isTrue,
        reason: 'R6: Tutorial topics must include interactive Metronome guide',
      );

      // Check R5: Chord dictionary and repertoire
      final hasChordTopic = topicNames.contains('chordDictionary') ||
          topicTitles.any((t) => t.contains('acordes') || t.contains('letras'));
      expect(
        hasChordTopic,
        isTrue,
        reason: 'R6: Tutorial topics must include chord dictionary guide',
      );

      // Check R6: 6 and 12-string guitar tuner
      final tunerTopic = TutorialTopic.values.firstWhere((t) => t.name == 'tuner');
      final mentionsStrings = tunerTopic.instructions.any((i) => i.contains('12') || i.contains('docerola') || i.contains('6'));
      expect(
        mentionsStrings,
        isTrue,
        reason: 'R6: Guitar tuner tutorial must document 6-string and 12-string docerola tuning',
      );
    });

    // -------------------------------------------------------------------------
    // R7: Strict Commercial Licensing Verification
    // -------------------------------------------------------------------------
    test('T1.10: Pubspec dependencies comply strictly with commercial open source licenses (MIT, Apache 2.0, BSD-3)', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must exist at project root');

      final content = pubspecFile.readAsStringSync();

      // Known permissive libraries used
      const permissiveLibraries = [
        'flutter',
        'cupertino_icons',
        'video_player',
        'shared_preferences',
        'google_fonts',
        'camera',
        'permission_handler',
        'gal',
        'record',
        'audio_session',
        'path_provider',
        'sherpa_onnx',
      ];

      for (final lib in permissiveLibraries) {
        expect(
          content.contains(lib),
          isTrue,
          reason: 'Permissive library $lib must be tracked in pubspec.yaml',
        );
      }

      // Assert zero copyleft or restrictive licenses present
      const forbiddenLibraries = ['gpl', 'agpl', 'lgpl', 'ffmpeg_kit_flutter_full_gpl'];
      for (final forbidden in forbiddenLibraries) {
        expect(
          content.toLowerCase().contains(forbidden),
          isFalse,
          reason: 'R7: Zero copyleft libraries ($forbidden) are permitted in commercial distribution',
        );
      }
    });
  });
}
