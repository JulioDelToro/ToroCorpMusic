import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/camera/widgets/camera_viewfinder_widget.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/floating_teleprompter_capsule.dart';

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

  testWidgets('Drawer excludes Tipo de Grabación, provides Camera toggle, and Island expands in camera-off mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(
      home: StudioRecordingScreen(),
    ));

    // 1. Estado inicial: cámara apagada por defecto
    final viewfinder = tester.widget<CameraViewfinderWidget>(find.byType(CameraViewfinderWidget));
    expect(viewfinder.isCameraActive, isFalse);

    // La isla dinámica inicia en forma de cápsula compacta
    final capsuleFinder = find.byType(FloatingTeleprompterCapsule);
    expect(capsuleFinder, findsOneWidget);
    final initialSize = tester.getSize(capsuleFinder);
    expect(initialSize.height, inInclusiveRange(80.0, 140.0));

    // 2. Expandir isla dinámica a Modo Atril en pantalla completa con cámara apagada
    final expandBtn = find.descendant(
      of: capsuleFinder,
      matching: find.byIcon(Icons.unfold_more),
    );
    expect(expandBtn, findsOneWidget);
    await tester.tap(expandBtn);
    await tester.pumpAndSettle();

    final expandedSize = tester.getSize(capsuleFinder);
    expect(expandedSize.height, greaterThan(200.0));
    expect(find.text('Modo Atril'), findsOneWidget);

    // 3. Abrir menú hamburguesa lateral
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();

    // R1: "Tipo de Grabación" ya no existe en el menú
    expect(find.text('Tipo de Grabación'), findsNothing);

    // R1: Opción de conmutación de Cámara a demanda presente
    final cameraTile = find.textContaining('Cámara');
    expect(cameraTile, findsOneWidget);

    // Encender la cámara desde el menú lateral
    await tester.tap(cameraTile);
    await tester.pumpAndSettle();

    // Cerrar menú
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();

    // R1: La isla dinámica regresa automáticamente a su cápsula compacta superior bajo la cámara
    final collapsedSize = tester.getSize(capsuleFinder);
    expect(collapsedSize.height, lessThanOrEqualTo(140.0));

    // Con la cámara activa, el botón de expansión no está disponible
    expect(
      find.descendant(of: capsuleFinder, matching: find.byIcon(Icons.unfold_more)),
      findsNothing,
    );
  });
}
