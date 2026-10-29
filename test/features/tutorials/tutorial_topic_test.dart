import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tutorials/models/tutorial_topic.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/feature_help_dialog.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/onboarding_tour_dialog.dart';

void main() {
  group('TutorialTopic Model Tests', () {
    test('contains all expected enum values with non-empty fields', () {
      final expectedTopics = [
        TutorialTopic.cameraAndDynamicIsland,
        TutorialTopic.palmGesture,
        TutorialTopic.voiceCommand,
        TutorialTopic.metronome,
        TutorialTopic.tuner,
        TutorialTopic.vocalTracking,
        TutorialTopic.chordDictionary,
        TutorialTopic.beautyFilter,
        TutorialTopic.pdfImport,
      ];

      expect(TutorialTopic.values.length, expectedTopics.length);

      for (final topic in TutorialTopic.values) {
        expect(topic.title, isNotEmpty);
        expect(topic.summary, isNotEmpty);
        expect(topic.instructions, isNotEmpty);
        expect(topic.icon, isNotNull);
        for (final instruction in topic.instructions) {
          expect(instruction, isNotEmpty);
        }
      }
    });

    test('cameraAndDynamicIsland specifies OLED pure black and music stand expansion', () {
      final topic = TutorialTopic.cameraAndDynamicIsland;
      expect(topic.title, contains('Atril'));
      expect(topic.summary, contains('OLED'));

      final allInstructions = topic.instructions.join(' ');
      expect(allInstructions, contains('cámara apagada'));
      expect(allInstructions, contains('Negro Puro OLED'));
      expect(allInstructions, contains('Isla Dinámica'));
      expect(allInstructions, contains('pantalla completa'));
      expect(allInstructions, contains('6 a 10 líneas'));
      expect(allInstructions, contains('menú lateral'));
    });

    test('palmGesture specifies 5-second countdown sequence', () {
      final topic = TutorialTopic.palmGesture;
      expect(topic.title, contains('5s'));
      final allInstructions = topic.instructions.join(' ');
      expect(allInstructions, contains('5 → 4 → 3 → 2 → 1'));
      expect(allInstructions, contains('5 segundos'));
    });

    test('voiceCommand specifies 5-second countdown sequence', () {
      final topic = TutorialTopic.voiceCommand;
      expect(topic.title, contains('5s'));
      final allInstructions = topic.instructions.join(' ');
      expect(allInstructions, contains('5 segundos'));
      expect(allInstructions, contains('5 → 4 → 3 → 2 → 1'));
    });

    test('metronome specifies 40-240 BPM, Tap Tempo and time signatures', () {
      final topic = TutorialTopic.metronome;
      expect(topic.title, contains('Metrónomo'));
      final allInstructions = topic.instructions.join(' ');
      expect(allInstructions, contains('40 y 240 BPM'));
      expect(allInstructions, contains('Tap Tempo'));
      expect(allInstructions, contains('2/4, 3/4, 4/4, 6/8'));
      expect(allInstructions, contains('+/- 1 BPM'));
    });

    test('tuner specifies 6- and 12-string guitars, detection and +/-3.5 cent accuracy', () {
      final topic = TutorialTopic.tuner;
      expect(topic.title, contains('6 y 12 Cuerdas'));
      final allInstructions = topic.instructions.join(' ');
      expect(allInstructions, contains('6 cuerdas'));
      expect(allInstructions, contains('12 cuerdas'));
      expect(allInstructions, contains('±3.5¢'));
      expect(allInstructions, contains('VERDE'));
    });
  });

  group('Tutorial Dialogs Integration Tests', () {
    for (final topic in TutorialTopic.values) {
      testWidgets('FeatureHelpDialog renders topic "${topic.name}" properly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FeatureHelpDialog(topic: topic),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(topic.title), findsOneWidget);
        expect(find.text(topic.summary), findsOneWidget);
        expect(find.text('Entendido'), findsOneWidget);

        // Scroll and tap Entendido
        await tester.ensureVisible(find.text('Entendido'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('OnboardingTourDialog steps through topics including new ones', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OnboardingTourDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First step is cameraAndDynamicIsland
      expect(find.text(TutorialTopic.cameraAndDynamicIsland.title), findsOneWidget);
      expect(find.text('1 de 6'), findsOneWidget);

      // Advance to next: palmGesture
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(TutorialTopic.palmGesture.title), findsOneWidget);
      expect(find.text('2 de 6'), findsOneWidget);

      // Advance to next: metronome
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(TutorialTopic.metronome.title), findsOneWidget);
      expect(find.text('3 de 6'), findsOneWidget);

      // Advance to next: tuner
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(TutorialTopic.tuner.title), findsOneWidget);
      expect(find.text('4 de 6'), findsOneWidget);
    });
  });
}
