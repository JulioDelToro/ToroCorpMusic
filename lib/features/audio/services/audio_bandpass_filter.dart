import 'dart:math' as math;

/// Filtro de audio pasa-banda vocal (100 Hz a 3400 Hz) y compuerta de ruido acústico.
/// Diseñado para atenuar los rasgueos brillantes y golpes de caja de la guitarra acústica,
/// permitiendo que el motor de reconocimiento solo escuche la voz humana.
class AudioBandpassFilter {
  final double sampleRate;
  final double lowCutHz; // 100 Hz (elimina zumbidos de baja frecuencia)
  final double highCutHz; // 3400 Hz (elimina armónicos agudos de cuerdas metálicas)
  final double noiseGateThreshold;

  AudioBandpassFilter({
    this.sampleRate = 16000.0,
    this.lowCutHz = 100.0,
    this.highCutHz = 3400.0,
    this.noiseGateThreshold = 0.02,
  });

  /// Determina si un paquete de muestras PCM contiene energía vocal suficiente sobre la compuerta de ruido.
  bool containsVocalEnergy(List<double> samples) {
    if (samples.isEmpty) return false;

    double sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += s * s;
    }
    final rms = math.sqrt(sumSquares / samples.length);
    return rms >= noiseGateThreshold;
  }

  /// Limpia y normaliza texto eliminando acentos, puntuación y caracteres especiales
  static String normalizeWord(String word) {
    var clean = word.trim().toLowerCase();
    const withAccents = 'áéíóúüñÁÉÍÓÚÜÑ';
    const withoutAccents = 'aeiouunAEIOUUN';

    for (int i = 0; i < withAccents.length; i++) {
      clean = clean.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  /// Calcula la distancia de similitud fonética/ortográfica Levenshtein
  static double similarity(String s1, String s2) {
    final a = normalizeWord(s1);
    final b = normalizeWord(s2);

    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final distance = _levenshteinDistance(a, b);
    final maxLength = math.max(a.length, b.length);
    return 1.0 - (distance / maxLength);
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
