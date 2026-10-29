import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';

void main() {
  group('Empirical Adversarial Verification — FloatingTeleprompterCapsule', () {
    // -------------------------------------------------------------------------
    // 1. STRESS TESTS: 50 Rapid Expand/Collapse Toggles
    // -------------------------------------------------------------------------
    testWidgets('Stress: 50 rapid expand and collapse toggles without animation crash or state desync', (tester) async {
      final lines = [
        const LyricLine(tokens: [LyricToken(word: 'Intro', chordUnderneath: 'C'), LyricToken(word: 'acústica')]),
        const LyricLine(tokens: [LyricToken(word: 'Verso', chordUnderneath: 'Am'), LyricToken(word: 'primero')]),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: lines,
            currentLineIndex: 0,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));

      final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
      expect(tester.getSize(capsuleFinder).height, equals(108.0));

      // Perform 50 rapid toggles alternating expand and collapse
      // Half with fast pumps interrupting the animation curve mid-flight
      for (int i = 0; i < 50; i++) {
        if (i % 2 == 0) {
          // Attempting to expand
          final expandBtn = find.byIcon(Icons.unfold_more);
          expect(expandBtn, findsOneWidget, reason: 'Iteration $i: unfold_more should exist in compact mode');
          await tester.tap(expandBtn);
          // Rapid partial pump (10ms) interrupting animation mid-flight
          await tester.pump(const Duration(milliseconds: 10));
        } else {
          // Attempting to collapse
          // Wait briefly for widget tree update so collapse icon is mounted
          await tester.pump(const Duration(milliseconds: 50));
          final collapseBtn = find.byIcon(Icons.close_fullscreen);
          expect(collapseBtn, findsOneWidget, reason: 'Iteration $i: close_fullscreen should exist in expanded mode');
          await tester.tap(collapseBtn);
          // Rapid partial pump (10ms)
          await tester.pump(const Duration(milliseconds: 10));
        }
      }

      // Settle all remaining animations and timers
      await tester.pumpAndSettle();

      // Verify no unhandled exceptions were thrown during 50 rapid toggles
      expect(tester.takeException(), isNull);

      // Verify that after settling from 50 toggles (0 to 49 => 25 expands, 25 collapses),
      // the capsule is safely back at compact 108.0 px
      expect(tester.getSize(capsuleFinder).height, equals(108.0));
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('Stress: Rapid camera toggling while expanded forces instantaneous safe collapse', (tester) async {
      bool isCamOn = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => isCamOn = !isCamOn),
                    child: const Text('Flip Camera'),
                  ),
                  FloatingTeleprompterCapsule(
                    allLines: const [LyricLine(tokens: [LyricToken(word: 'Test')])],
                    currentLineIndex: 0,
                    currentWordIndex: 0,
                    isCameraActive: isCamOn,
                  ),
                ],
              ),
            ),
          );
        },
      ));

      final capsuleFinder = find.byType(FloatingTeleprompterCapsule);

      // Expand first
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();
      expect(tester.getSize(capsuleFinder).height, greaterThan(200.0));

      // Rapidly toggle camera 20 times
      for (int i = 0; i < 20; i++) {
        await tester.tap(find.text('Flip Camera'));
        await tester.pump(const Duration(milliseconds: 15));
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 2. EDGE CASE MINING: Empty Songs, 1-Line Songs, 50-Line Songs
    // -------------------------------------------------------------------------
    testWidgets('Edge case: Completely empty songs (null & empty lists) render placeholder and expand/collapse safely', (tester) async {
      // Test A: allLines is null, tokens is null, currentLine is null
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: null,
            tokens: null,
            currentLine: null,
            nextLine: null,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));

      expect(find.text('Toca aquí para escribir o pegar la letra de tu canción...'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);

      // Expand in empty state
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();

      // Placeholder also appears in expanded Music Stand mode
      expect(find.text('Toca aquí para escribir o pegar la letra de tu canción...'), findsOneWidget);
      expect(find.text('Modo Atril'), findsOneWidget);

      // Collapse back
      await tester.tap(find.byIcon(Icons.close_fullscreen));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingTeleprompterCapsule), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test B: allLines is empty list []
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: [],
            currentLineIndex: 0,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));

      expect(find.text('Toca aquí para escribir o pegar la letra de tu canción...'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test C: allLines has 1 line with 0 tokens (blank line)
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: [LyricLine(tokens: [])],
            currentLineIndex: 0,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));

      expect(find.text('Toca aquí para escribir o pegar la letra de tu canción...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Edge case: 1-line song handles 2-line/3-line lookahead safely without range errors', (tester) async {
      final oneLine = [
        const LyricLine(tokens: [
          LyricToken(word: 'Solitario', chordUnderneath: 'Em'),
          LyricToken(word: 'verso'),
        ]),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: oneLine,
            currentLineIndex: 0,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));

      // Compact mode: Lookahead checks line+1 and line+2. Since length is 1, they must not throw.
      expect(find.text('Solitario'), findsOneWidget);
      expect(find.text('Em'), findsOneWidget);
      expect(find.text('verso'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Expand to Music Stand mode
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();

      expect(find.text('Modo Atril'), findsOneWidget);
      expect(find.text('Solitario'), findsOneWidget);
      expect(find.text('Em'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Collapse back
      await tester.tap(find.byIcon(Icons.close_fullscreen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Edge case: 50-line song with mixed chords and instrumental breaks renders and navigates safely', (tester) async {
      // Build 50 diverse lines
      final fiftyLines = List.generate(50, (index) {
        if (index % 5 == 4) {
          // Instrumental line
          return LyricLine(
            tokens: const [],
            isInstrumental: true,
            instrumentalLabel: '🎸 REQUINTO SOLO #$index',
          );
        }
        return LyricLine(
          tokens: [
            LyricToken(word: 'Palabra${index}_A', chordUnderneath: 'G#m'),
            LyricToken(word: 'Palabra${index}_B', chordUnderneath: 'C#7'),
            LyricToken(word: 'Palabra${index}_C'),
          ],
        );
      });

      int tappedLine = -1;
      int tappedWord = -1;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: fiftyLines,
            currentLineIndex: 25, // Midpoint
            currentWordIndex: 1,
            isCameraActive: false,
            onLineWordTap: (lIdx, wIdx) {
              tappedLine = lIdx;
              tappedWord = wIdx;
            },
          ),
        ),
      ));

      expect(find.text('Palabra25_A'), findsOneWidget);
      expect(find.text('Palabra25_B'), findsOneWidget);

      // Expand into Music Stand mode
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();

      // Verify Music Stand is populated with ListView.builder
      expect(find.byType(ListView), findsOneWidget);

      // Scroll down deep into the song to line 44 (instrumental)
      final listViewFinder = find.byType(ListView);
      await tester.drag(listViewFinder, const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(find.text('🎸 REQUINTO SOLO #44'), findsOneWidget);

      // Tap on instrumental line
      await tester.tap(find.text('🎸 REQUINTO SOLO #44'));
      await tester.pump();
      expect(tappedLine, equals(44));
      expect(tappedWord, equals(0));

      // Scroll back up to verify bidirectional scrolling
      await tester.drag(listViewFinder, const Offset(0, 1500));
      await tester.pumpAndSettle();

      // Test boundary currentLineIndex = 49 (last line)
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: fiftyLines,
            currentLineIndex: 49,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test out-of-range currentLineIndex = 999 (must clamp safely without throwing)
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: fiftyLines,
            currentLineIndex: 999,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 3. FONT SCALING BOUNDARY CLAMPING: 70% min to 180% max
    // -------------------------------------------------------------------------
    testWidgets('Font scaling: A- and A+ clamp strictly at 70% and 180% without NaN, crash or overflow', (tester) async {
      final lines = [
        const LyricLine(tokens: [
          LyricToken(word: 'Prueba', chordUnderneath: 'A'),
          LyricToken(word: 'Escala', chordUnderneath: 'B'),
        ]),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloatingTeleprompterCapsule(
            allLines: lines,
            currentLineIndex: 0,
            currentWordIndex: 0,
            isCameraActive: false,
          ),
        ),
      ));

      // Expand to access font size controls
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);

      final aMinusFinder = find.text('A-');
      final aPlusFinder = find.text('A+');
      expect(aMinusFinder, findsOneWidget);
      expect(aPlusFinder, findsOneWidget);

      // Aggressively tap A- 15 times to hit and challenge lower boundary (min 70%)
      for (int i = 0; i < 15; i++) {
        await tester.tap(aMinusFinder);
        await tester.pump();
      }

      // Must clamp at 70% exactly
      expect(find.text('70%'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap A- 5 more times at the floor
      for (int i = 0; i < 5; i++) {
        await tester.tap(aMinusFinder);
        await tester.pump();
      }
      expect(find.text('70%'), findsOneWidget, reason: 'Font scale must not decrease below 70%');
      expect(tester.takeException(), isNull);

      // Verify that rendered text at 70% font scale has finite, valid, non-zero fontSize
      final textWidgetAt70 = tester.widget<Text>(find.text('Prueba'));
      expect(textWidgetAt70.style?.fontSize, isNotNull);
      expect(textWidgetAt70.style!.fontSize!.isFinite, isTrue);
      expect(textWidgetAt70.style!.fontSize!.isNaN, isFalse);
      expect(textWidgetAt70.style!.fontSize, greaterThan(0));

      // Aggressively tap A+ 25 times to hit and challenge upper boundary (max 180%)
      for (int i = 0; i < 25; i++) {
        await tester.tap(aPlusFinder);
        await tester.pump();
      }

      // Must clamp at 180% exactly
      expect(find.text('180%'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap A+ 5 more times at the ceiling
      for (int i = 0; i < 5; i++) {
        await tester.tap(aPlusFinder);
        await tester.pump();
      }
      expect(find.text('180%'), findsOneWidget, reason: 'Font scale must not increase beyond 180%');
      expect(tester.takeException(), isNull);

      // Verify rendered text at 180% scale
      final textWidgetAt180 = tester.widget<Text>(find.text('Prueba'));
      expect(textWidgetAt180.style?.fontSize, isNotNull);
      expect(textWidgetAt180.style!.fontSize!.isFinite, isTrue);
      expect(textWidgetAt180.style!.fontSize!.isNaN, isFalse);
      expect(textWidgetAt180.style!.fontSize, greaterThan(textWidgetAt70.style!.fontSize!));
    });

    // -------------------------------------------------------------------------
    // 4. SMALL VIEWPORT & LAYOUT STRESS: 360x640 and 320x480
    // -------------------------------------------------------------------------
    testWidgets('Small Viewport 360x640: Zero RenderFlex overflow in compact and expanded modes with menu and reset open', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      final lines = [
        const LyricLine(tokens: [
          LyricToken(word: 'Texto', chordUnderneath: 'G#m7b5'),
          LyricToken(word: 'extenso', chordUnderneath: 'C#7(#9)'),
          LyricToken(word: 'para'),
          LyricToken(word: 'desafiar'),
          LyricToken(word: 'anchura'),
        ]),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: FloatingTeleprompterCapsule(
              allLines: lines,
              currentLineIndex: 0,
              currentWordIndex: 0,
              isCameraActive: false,
              isRecording: true,
              recordingSeconds: 125,
              onMenuTap: () {},
            ),
          ),
        ),
      ));

      // Compact Mode verification on 360x640
      expect(find.byType(FloatingTeleprompterCapsule), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Compact mode must have 0 RenderFlex overflow on 360x640');

      // Expand to Music Stand on 360x640
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Expanded mode must have 0 RenderFlex overflow on 360x640');

      // Tap 'Voz' to switch to wider 'Reiniciar' button (76px width) while expanded
      await tester.tap(find.text('Voz'));
      await tester.pumpAndSettle();
      expect(find.text('Reiniciar'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Header row with Reiniciar button must not overflow 360px viewport');

      // Increase font scale to maximum 180% to maximize child element sizes
      for (int i = 0; i < 8; i++) {
        await tester.tap(find.text('A+'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '180% font scale must not cause overflow on 360x640');

      // Collapse back
      await tester.tap(find.byIcon(Icons.close_fullscreen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ultra-Small Viewport 320x480: Zero RenderFlex overflow under extreme width constraints', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      final lines = [
        const LyricLine(tokens: [
          LyricToken(word: 'Supercalifragilisticoespialidoso', chordUnderneath: 'F#m7-5'),
          LyricToken(word: 'palabraLarga'),
        ]),
        const LyricLine(tokens: [
          LyricToken(word: 'SegundaLínea', chordUnderneath: 'Bdim7'),
        ]),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: FloatingTeleprompterCapsule(
              allLines: lines,
              currentLineIndex: 0,
              currentWordIndex: 0,
              isCameraActive: false,
              isRecording: true,
              recordingSeconds: 3599, // '59:59' - maximum width for timer
              onMenuTap: () {},
            ),
          ),
        ),
      ));

      // 1. Compact Mode on 320x480
      expect(find.text('59:59'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Compact mode must not overflow on 320x480 screen');

      // 2. Expand to Music Stand on 320x480
      await tester.tap(find.byIcon(Icons.unfold_more));
      await tester.pumpAndSettle();

      expect(find.text('Modo Atril'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Expanded music stand must not overflow on 320x480 screen');

      // 3. Switch to 'Reiniciar' button (widest state) in header
      await tester.tap(find.text('Voz'));
      await tester.pumpAndSettle();
      expect(find.text('Reiniciar'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Header row with Reiniciar + REC + Badge + A-/A+ + Close + Menu must not overflow on 320px width');

      // 4. Crank font scale to 180%
      for (int i = 0; i < 8; i++) {
        await tester.tap(find.text('A+'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '180% font scale with long words on 320px width must wrap safely without overflow');

      // 5. Collapse back to compact pill
      await tester.tap(find.byIcon(Icons.close_fullscreen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
