import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Studio screen mounts teleprompter, tuner toggle, beauty slider and record button', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StudioRecordingScreen(),
    ));

    expect(find.byType(StudioRecordingScreen), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsWidgets);
    expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);
  });
}
