/// Tipo de instrumento para el afinador
enum GuitarType {
  sixString('Guitarra 6 Cuerdas', 6),
  twelveString('Guitarra 12 Cuerdas / Docerola', 12);

  final String label;
  final int stringCount;
  const GuitarType(this.label, this.stringCount);
}

/// Representa una nota de referencia para una cuerda específica de la guitarra.
class ReferenceNote {
  final String name; // Ej: 'E4', 'B3', 'G3'
  final double frequency; // Hz
  final int stringIndex; // 1 a 6 (o 1 a 12)
  final String label; // Ej: '1ª Cuerda (Mi)', 'Octava Sol'

  const ReferenceNote({
    required this.name,
    required this.frequency,
    required this.stringIndex,
    this.label = '',
  });
}

/// Resultado del análisis de afinación de una frecuencia detectada.
class TuningResult {
  final double detectedFrequency;
  final String closestNote;
  final double targetFrequency;
  final double centsOffset;
  final bool isInTune;
  final int? targetStringIndex;

  const TuningResult({
    required this.detectedFrequency,
    required this.closestNote,
    required this.targetFrequency,
    required this.centsOffset,
    required this.isInTune,
    this.targetStringIndex,
  });

  @override
  String toString() {
    return 'TuningResult(closestNote: $closestNote, detected: ${detectedFrequency.toStringAsFixed(1)}Hz, cents: ${centsOffset.toStringAsFixed(1)}, inTune: $isInTune)';
  }
}
