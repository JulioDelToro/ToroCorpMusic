import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Studio screen mounts teleprompter, hamburger menu and record button', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StudioRecordingScreen(),
    ));

    expect(find.byType(StudioRecordingScreen), findsOneWidget);
    expect(find.byType(AnimatedIcon), findsOneWidget);
    expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);

    // Abrir menú hamburguesa
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();

    // Las opciones del menú ahora están visibles
    expect(find.text('ToroCorp Music'), findsWidgets);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.lyrics), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
    expect(find.byIcon(Icons.palette), findsOneWidget);

    // Cerrar menú
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.tune), findsNothing);
  });
}
