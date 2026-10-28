import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tuner/models/tuning_note.dart';
import 'package:toro_music_teleprompter/features/tuner/widgets/guitar_visualizer_widget.dart';

void main() {
  testWidgets('GuitarVisualizerWidget displays GuitarTuna style pastillas (D, A, E, G, B, E) and selects string on tap', (tester) async {
    int? selectedString;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: GuitarVisualizerWidget(
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
      ),
    ));

    // Validar que se dibujan las pastillas circulares de 6 cuerdas: D, A, E, G, B, E
    expect(find.text('D'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('E'), findsNWidgets(2)); // Mi grave (6ª) y Mi aguda (1ª)

    // Tocar la pastilla de la 4ª cuerda (D)
    await tester.tap(find.text('D'));
    await tester.pumpAndSettle();

    expect(selectedString, equals(4));
  });

  testWidgets('GuitarVisualizerWidget displays 12 string pastillas for docerola and highlights selected string', (tester) async {
    int? selectedString = 11; // 11ª cuerda seleccionada (E2 de docerola)

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: GuitarVisualizerWidget(
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
      ),
    ));

    // En docerola (12 cuerdas): pares D, D, A, A, E, E en izquierda; G, G, B, B, E, E en derecha
    expect(find.text('D'), findsNWidgets(2));
    expect(find.text('A'), findsNWidgets(2));
    expect(find.text('G'), findsNWidgets(2));
    expect(find.text('B'), findsNWidgets(2));
    expect(find.text('E'), findsNWidgets(4)); // 2 pares de E

    // Tocar la primera pastilla de D para seleccionarla
    await tester.tap(find.text('D').first);
    await tester.pumpAndSettle();

    expect(selectedString, equals(8)); // Primera D es la cuerda 8
  });
}
