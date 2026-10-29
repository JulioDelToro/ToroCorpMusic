import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tutorials/models/tutorial_topic.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/feature_help_dialog.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/onboarding_tour_dialog.dart';

void main() {
  group('TutorialTopic Adversarial Invariant Checks', () {
    test('all enum instances meet strict content and formatting contracts', () {
      expect(TutorialTopic.values.length, greaterThanOrEqualTo(10));

      final titlesSeen = <String>{};

      for (final topic in TutorialTopic.values) {
        // Title validation
        expect(topic.title.trim().length, greaterThanOrEqualTo(5),
            reason: '${topic.name} title too short');
        expect(titlesSeen.add(topic.title), isTrue,
            reason: 'Duplicate title found for ${topic.name}');
        expect(topic.title, isNot(contains('TODO')));
        expect(topic.title, isNot(contains('TBD')));
        expect(topic.title, isNot(contains('WIP')));

        // Icon validation
        expect(topic.icon.codePoint, greaterThan(0),
            reason: '${topic.name} has invalid icon');
        expect(topic.icon.fontFamily, equals('MaterialIcons'));

        // Summary validation
        expect(topic.summary.trim().length, greaterThanOrEqualTo(20),
            reason: '${topic.name} summary too short');
        expect(topic.summary, isNot(contains('lorem ipsum')));

        // Instructions validation
        expect(topic.instructions.length, greaterThanOrEqualTo(2),
            reason: '${topic.name} has fewer than 2 instructions');
        for (int i = 0; i < topic.instructions.length; i++) {
          final step = topic.instructions[i];
          expect(step.trim().length, greaterThanOrEqualTo(15),
              reason: '${topic.name} instruction $i is too brief');
          expect(step, isNot(contains('TODO')));
        }
      }
    });

    test('cameraAndDynamicIsland covers all R1 architectural specifications', () {
      final topic = TutorialTopic.cameraAndDynamicIsland;
      final fullText = '${topic.title} ${topic.summary} ${topic.instructions.join(' ')}';

      expect(fullText, contains('Negro Puro OLED'));
      expect(fullText, contains('cámara apagada'));
      expect(fullText, contains('pantalla completa'));
      expect(fullText, contains('6 a 10 líneas'));
      expect(fullText, contains('acordes'));
      expect(fullText, contains('menú lateral'));
      expect(fullText, contains('cápsula compacta'));
    });

    test('palmGesture and voiceCommand strictly specify 5s countdown (R2)', () {
      final palm = TutorialTopic.palmGesture;
      final voice = TutorialTopic.voiceCommand;

      final palmText = '${palm.title} ${palm.summary} ${palm.instructions.join(' ')}';
      final voiceText = '${voice.title} ${voice.summary} ${voice.instructions.join(' ')}';

      expect(palmText, contains('5 segundos'));
      expect(palmText, contains('5 → 4 → 3 → 2 → 1'));

      expect(voiceText, contains('5 segundos'));
      expect(voiceText, contains('5 → 4 → 3 → 2 → 1'));
    });

    test('metronome strictly specifies 40-240 BPM, Tap Tempo, time signatures (R4)', () {
      final metronome = TutorialTopic.metronome;
      final fullText = '${metronome.title} ${metronome.summary} ${metronome.instructions.join(' ')}';

      expect(fullText, contains('40 y 240 BPM'));
      expect(fullText, contains('Tap Tempo'));
      expect(fullText, contains('+/- 1 BPM'));
      expect(fullText, contains('2/4, 3/4, 4/4, 6/8'));
      expect(fullText, contains('tiempo 1'));
    });

    test('lyricsAndChordsSearch strictly specifies offline hits, online search, 1-tap import (R5)', () {
      final search = TutorialTopic.lyricsAndChordsSearch;
      final fullText = '${search.title} ${search.summary} ${search.instructions.join(' ')}';

      expect(fullText, contains('offline'));
      expect(fullText, contains('en línea'));
      expect(fullText, contains('acordes alineados'));
      expect(fullText, contains('Importar'));
    });

    test('tuner strictly specifies 6- and 12-string guitars with ±3.5¢ accuracy (R6)', () {
      final tuner = TutorialTopic.tuner;
      final fullText = '${tuner.title} ${tuner.summary} ${tuner.instructions.join(' ')}';

      expect(fullText, contains('6 cuerdas'));
      expect(fullText, contains('12 cuerdas'));
      expect(fullText, contains('±3.5¢'));
      expect(fullText, contains('VERDE'));
    });
  });

  group('Tutorial UI Adversarial Viewport & Layout Stress', () {
    for (final topic in TutorialTopic.values) {
      testWidgets('FeatureHelpDialog renders "${topic.name}" without overflow on ultra-compact screen (320x480)', (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FeatureHelpDialog(topic: topic),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(topic.title), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Overflow or render error on topic ${topic.name}');

        await tester.ensureVisible(find.text('Entendido'));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('FeatureHelpDialog renders without overflow on landscape viewport (800x360)', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureHelpDialog(topic: TutorialTopic.cameraAndDynamicIsland),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(TutorialTopic.cameraAndDynamicIsland.title), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Entendido'));
      await tester.pumpAndSettle();
    });

    testWidgets('OnboardingTourDialog completes full tour through all 7 steps to dismissal without error', (tester) async {
      bool dialogDismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (c) => const OnboardingTourDialog(),
                  );
                  dialogDismissed = true;
                },
                child: const Text('Launch Tour'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Tour'));
      await tester.pumpAndSettle();

      // Step 1 to 6 use 'Siguiente', Step 7 uses '¡Empezar a grabar!'
      for (int step = 1; step <= 6; step++) {
        expect(find.text('$step de 7'), findsOneWidget);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }

      // Step 7
      expect(find.text('7 de 7'), findsOneWidget);
      expect(find.text('¡Empezar a grabar!'), findsOneWidget);
      await tester.tap(find.text('¡Empezar a grabar!'));
      await tester.pumpAndSettle();

      expect(dialogDismissed, isTrue);
    });

    testWidgets('OnboardingTourDialog "Omitir" button dismisses immediately', (tester) async {
      bool dialogDismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (c) => const OnboardingTourDialog(),
                  );
                  dialogDismissed = true;
                },
                child: const Text('Launch Tour'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Tour'));
      await tester.pumpAndSettle();

      expect(find.text('Omitir'), findsOneWidget);
      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();

      expect(dialogDismissed, isTrue);
    });

    testWidgets('OnboardingTourDialog renders and advances without overflow on ultra-compact viewport (320x480)', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool dialogDismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (c) => const OnboardingTourDialog(),
                  );
                  dialogDismissed = true;
                },
                child: const Text('Launch Tour'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Tour'));
      await tester.pumpAndSettle();

      for (int step = 1; step <= 6; step++) {
        expect(find.text('$step de 7'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Overflow exception at step $step on 320x480');
        final nextBtn = find.text('Siguiente');
        await tester.ensureVisible(nextBtn);
        await tester.pumpAndSettle();
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
      }

      expect(find.text('7 de 7'), findsOneWidget);
      final finishBtn = find.text('¡Empezar a grabar!');
      expect(finishBtn, findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Overflow exception at step 7 on 320x480');

      await tester.ensureVisible(finishBtn);
      await tester.pumpAndSettle();
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();

      expect(dialogDismissed, isTrue);
    });
  });
}
