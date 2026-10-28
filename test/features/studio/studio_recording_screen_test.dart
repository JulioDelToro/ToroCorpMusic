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

  testWidgets('Tapping Tipo de Grabación opens modal with Video Limpio and Con Guion options', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(
      home: StudioRecordingScreen(),
    ));

    // Abrir menú hamburguesa
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();

    // Buscar y presionar "Tipo de Grabación"
    final tipoGrabacionTile = find.text('Tipo de Grabación');
    expect(tipoGrabacionTile, findsOneWidget);
    await tester.tap(tipoGrabacionTile);
    await tester.pumpAndSettle();

    // Verificar que el modal de selección de tipo de grabación está abierto con las 2 opciones claras
    expect(find.text('Video Limpio (Solo Cámara)'), findsOneWidget);
    expect(find.text('Con Guion (Cámara + Letra)'), findsOneWidget);
    expect(find.text('Puro Video'), findsOneWidget);
    expect(find.text('Teleprompter'), findsOneWidget);

    // Seleccionar "Con Guion"
    await tester.tap(find.text('Con Guion (Cámara + Letra)'));
    await tester.pumpAndSettle();

    // El modal se cierra tras la selección
    expect(find.text('Video Limpio (Solo Cámara)'), findsNothing);
  });
}
