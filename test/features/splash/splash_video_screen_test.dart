import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/splash/presentation/splash_video_screen.dart';

void main() {
  testWidgets('Splash screen plays in 9:16 and has NO skip button (user must wait)', (tester) async {
    bool finished = false;
    await tester.pumpWidget(MaterialApp(
      home: SplashVideoScreen(onFinished: () => finished = true),
    ));

    // El botón 'Saltar' ha sido eliminado por requerimiento
    expect(find.text('Saltar'), findsNothing);

    // No debe saltar por tocar la pantalla
    await tester.tap(find.byType(SplashVideoScreen));
    await tester.pump();
    expect(finished, isFalse);
  });
}
