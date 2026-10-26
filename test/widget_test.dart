import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'package:toro_music_teleprompter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test mounts ToroMusicApp and StudioRecordingScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const ToroMusicApp(showSplash: false));
    expect(find.byType(StudioRecordingScreen), findsOneWidget);
  });
}
