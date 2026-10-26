import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tutorials/models/tutorial_topic.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/feature_help_dialog.dart';

void main() {
  testWidgets('FeatureHelpDialog displays explanation for palm gesture', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeatureHelpDialog(topic: TutorialTopic.palmGesture)),
    ));
    expect(find.textContaining("Palma"), findsOneWidget);
  });

  testWidgets('FeatureHelpDialog displays explanation for guitar tuner', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeatureHelpDialog(topic: TutorialTopic.tuner)),
    ));
    expect(find.textContaining("Afinador"), findsOneWidget);
  });
}
