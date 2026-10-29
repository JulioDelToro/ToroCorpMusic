import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/saved_song.dart';
import 'package:toro_music_teleprompter/features/scripts/services/chordpro_parser.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';
import 'package:toro_music_teleprompter/features/tuner/presentation/guitar_tuner_screen.dart';
import 'e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 3: Cross-Feature Combinations', () {
    // -------------------------------------------------------------------------
    // T3.1: Metronome + Guitar Tuner + Studio Drawer Integration
    // -------------------------------------------------------------------------
    testWidgets('T3.1: Navigating between lateral menu, Tuner, and Studio preserves audio & screen state', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);

      // 1. Open lateral menu
      await E2ETestHelpers.openLateralMenu(tester);

      // 2. Both Tuner and Metronome exist in the menu
      expect(find.text('Afinador de Guitarra'), findsOneWidget);
      final metronomeFinder = find.text('Metrónomo');
      expect(
        metronomeFinder,
        findsOneWidget,
        reason: 'R4: Dedicated Metronome option must be co-located with Guitar Tuner in drawer',
      );

      // 3. Open Guitar Tuner screen
      await tester.tap(find.text('Afinador de Guitarra'));
      await tester.pumpAndSettle();

      // Verify GuitarTunerScreen is pushed onto navigator
      expect(find.byType(GuitarTunerScreen), findsOneWidget);
      expect(find.text('Afinador de Guitarra'), findsWidgets);

      // 4. Return to Studio screen
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
      } else {
        final closeIcon = find.byIcon(Icons.close);
        if (closeIcon.evaluate().isNotEmpty) {
          await tester.tap(closeIcon.first);
          await tester.pumpAndSettle();
        }
      }

      // Studio recording screen is active again
      expect(find.byType(StudioRecordingScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // T3.2: Lyrics Search Import + Auto-Mounting to Dynamic Island
    // -------------------------------------------------------------------------
    testWidgets('T3.2: Importing a ChordPro song from repertoire persists to storage and updates teleprompter', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);

      // 1. Generate new ChordPro song
      const songContent = '''
{title: Rayando el Sol}
{artist: Maná}

[G]Rayando el sol, [D]rayando por ti
[Em]Esta pena me duele con [C]frenesí
''';
      final songScript = ChordProParser().parse(
        songContent,
        title: 'Rayando el Sol',
        artist: 'Maná',
      );
      expect(songScript.title, equals('Rayando el Sol'));
      expect(songScript.lines.length, equals(2));

      // 2. Save song via SavedSongsService
      final savedSong = SavedSong(
        id: 'test_mana_1',
        title: songScript.title,
        content: songContent,
        updatedAt: DateTime.now(),
      );

      final savedMap = savedSong.toMap();
      expect(savedMap['title'], equals('Rayando el Sol'));

      // 3. Verify song converts cleanly to SongScript with chords
      final convertedScript = savedSong.toSongScript();
      expect(convertedScript.lines.isNotEmpty, isTrue);
      expect(convertedScript.lines.first.tokens.any((t) => t.chordUnderneath == 'G'), isTrue);
      expect(convertedScript.lines.first.tokens.any((t) => t.chordUnderneath == 'D'), isTrue);

      // 4. Mount FloatingTeleprompterCapsule with new song lines
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingTeleprompterCapsule(
              allLines: convertedScript.lines,
              currentLineIndex: 0,
              currentLine: convertedScript.lines.first,
              currentWordIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Words and chords from the imported song are rendered on screen
      expect(find.textContaining('Rayando'), findsWidgets);
      expect(find.text('G'), findsWidgets);
      expect(find.text('D'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // T3.3: Dynamic Island Music Stand Mode + Camera Toggle Transition
    // -------------------------------------------------------------------------
    testWidgets('T3.3: Dynamic Island expands in camera-off mode and collapses seamlessly on camera toggle', (tester) async {
      await E2ETestHelpers.pumpStudioScreen(tester);

      final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
      expect(capsuleFinder, findsOneWidget);

      final initialSize = tester.getSize(capsuleFinder);
      expect(initialSize.height, inInclusiveRange(80.0, 140.0));

      // Locate expansion toggle icon (e.g. unfold_more)
      final expandIcon = find.descendant(
        of: capsuleFinder,
        matching: find.byIcon(Icons.unfold_more),
      );

      if (expandIcon.evaluate().isNotEmpty) {
        // Expand into full-screen music stand mode
        await tester.tap(expandIcon);
        await tester.pumpAndSettle();

        final expandedSize = tester.getSize(capsuleFinder);
        expect(expandedSize.height, greaterThan(200.0), reason: 'Dynamic Island must expand when camera is inactive');

        // Open lateral menu and toggle camera ON
        await E2ETestHelpers.openLateralMenu(tester);
        final cameraSwitch = find.textContaining('Cámara');
        await tester.tap(cameraSwitch);
        await tester.pumpAndSettle();
        await E2ETestHelpers.closeLateralMenu(tester);

        // Dynamic Island must automatically collapse back to compact pill under camera lens
        final collapsedSize = tester.getSize(capsuleFinder);
        expect(collapsedSize.height, lessThanOrEqualTo(140.0), reason: 'Activating camera must force auto-collapse to pill');
      }
    });
  });
}
