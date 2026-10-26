import 'dart:math' as math;
import '../models/tuning_note.dart';

/// Detector de afinación musical para guitarra de 6 cuerdas estándar.
class PitchDetector {
  static const List<ReferenceNote> standardGuitarTuning = [
    ReferenceNote(name: 'E2', frequency: 82.41, stringIndex: 6),
    ReferenceNote(name: 'A2', frequency: 110.00, stringIndex: 5),
    ReferenceNote(name: 'D3', frequency: 146.83, stringIndex: 4),
    ReferenceNote(name: 'G3', frequency: 196.00, stringIndex: 3),
    ReferenceNote(name: 'B3', frequency: 246.94, stringIndex: 2),
    ReferenceNote(name: 'E4', frequency: 329.63, stringIndex: 1),
  ];

  /// Analiza una frecuencia detectada (en Hz) y devuelve la cuerda más cercana con desviación en cents.
  TuningResult analyzeFrequency(double frequency, {double toleranceCents = 3.5}) {
    if (frequency <= 0) {
      return const TuningResult(
        detectedFrequency: 0,
        closestNote: '--',
        targetFrequency: 0,
        centsOffset: 0,
        isInTune: false,
      );
    }

    ReferenceNote closest = standardGuitarTuning.first;
    double minDiff = double.infinity;

    for (final note in standardGuitarTuning) {
      final diff = (note.frequency - frequency).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = note;
      }
    }

    // Fórmula estándar: cents = 1200 * log2(f / f0)
    final centsOffset = 1200.0 * (math.log(frequency / closest.frequency) / math.ln2);
    final isInTune = centsOffset.abs() <= toleranceCents;

    return TuningResult(
      detectedFrequency: frequency,
      closestNote: closest.name,
      targetFrequency: closest.frequency,
      centsOffset: centsOffset,
      isInTune: isInTune,
    );
  }
}
