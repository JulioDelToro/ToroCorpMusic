import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/main.dart';

void main() {
  testWidgets('App smoke test mounts ToroMusicApp with splash disabled', (WidgetTester tester) async {
    await tester.pumpWidget(const ToroMusicApp(showSplash: false));
    expect(find.text('Toro Music Studio'), findsOneWidget);
  });
}
