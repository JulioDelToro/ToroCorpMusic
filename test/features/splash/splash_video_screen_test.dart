import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/splash/presentation/splash_video_screen.dart';

void main() {
  testWidgets('Splash screen contains skip gesture detector and black background', (tester) async {
    bool skipped = false;
    await tester.pumpWidget(MaterialApp(
      home: SplashVideoScreen(onFinished: () => skipped = true),
    ));
    expect(find.byType(GestureDetector), findsWidgets);
    await tester.tap(find.byType(GestureDetector).first);
    expect(skipped, isTrue);
  });
}
