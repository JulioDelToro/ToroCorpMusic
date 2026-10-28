import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tuner/models/tuning_note.dart';
import 'package:toro_music_teleprompter/features/tuner/widgets/guitar_visualizer_widget.dart';

void main() {
  testWidgets('GuitarVisualizerWidget displays 6 string pastillas for 6-string guitar and selects string on tap', (tester) async {
    int? selectedString;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GuitarVisualizerWidget(
          guitarType: GuitarType.sixString,
          lockedStringIndex: null,
          detectedStringIndex: null,
          currentResult: const TuningResult(
            detectedFrequency: 0,
            closestNote: '--',
            targetFrequency: 0,
            centsOffset: 0,
            isInTune: false,
          ),
          onSelectString: (s) => selectedString = s,
        ),
      ),
    ));

    // Validar que se dibujan las pastillas de 6 cuerdas: 6ª, 5ª, 4ª, 3ª, 2ª, 1ª
    expect(find.text('6ª'), findsOneWidget);
    expect(find.text('5ª'), findsOneWidget);
    expect(find.text('4ª'), findsOneWidget);
    expect(find.text('3ª'), findsOneWidget);
    expect(find.text('2ª'), findsOneWidget);
    expect(find.text('1ª'), findsOneWidget);

    // Tocar la pastilla de la 6ª cuerda (E2)
    await tester.tap(find.text('6ª'));
    await tester.pumpAndSettle();

    expect(selectedString, equals(6));
  });

  testWidgets('GuitarVisualizerWidget displays 12 string pastillas for 12-string guitar and lights up selected string', (tester) async {
    int? selectedString = 11; // 11ª cuerda seleccionada (E2 de docerola)

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GuitarVisualizerWidget(
          guitarType: GuitarType.twelveString,
          lockedStringIndex: selectedString,
          detectedStringIndex: 11,
          currentResult: const TuningResult(
            detectedFrequency: 82.41,
            closestNote: 'E2',
            targetFrequency: 82.41,
            centsOffset: 0.0,
            isInTune: true,
            targetStringIndex: 11,
          ),
          onSelectString: (s) => selectedString = s,
        ),
      ),
    ));

    // Validar que se dibujan las 12 cuerdas de docerola
    expect(find.text('12ª'), findsOneWidget);
    expect(find.text('11ª'), findsOneWidget);
    expect(find.text('1ª'), findsOneWidget);
    expect(find.text('2ª'), findsOneWidget);

    // Validar icono de afinada perfecta en la pastilla seleccionada
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // Tocar botón Automático para regresar a auto-afinación
    await tester.tap(find.text('Automático'));
    await tester.pumpAndSettle();

    expect(selectedString, isNull);
  });
}
