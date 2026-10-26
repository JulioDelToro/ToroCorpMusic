/// Representa una nota de referencia para la afinación estándar de guitarra.
class ReferenceNote {
  final String name;
  final double frequency;
  final int stringIndex; // 1 a 6

  const ReferenceNote({
    required this.name,
    required this.frequency,
    required this.stringIndex,
  });
}

/// Resultado del análisis de afinación de una frecuencia detectada.
class TuningResult {
  final double detectedFrequency;
  final String closestNote;
  final double targetFrequency;
  final double centsOffset;
  final bool isInTune;

  const TuningResult({
    required this.detectedFrequency,
    required this.closestNote,
    required this.targetFrequency,
    required this.centsOffset,
    required this.isInTune,
  });

  @override
  String toString() {
    return 'TuningResult(closestNote: $closestNote, detected: ${detectedFrequency.toStringAsFixed(1)}Hz, cents: ${centsOffset.toStringAsFixed(1)}, inTune: $isInTune)';
  }
}
