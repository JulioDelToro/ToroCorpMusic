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

  /// Convierte una palabra a su representación fonética en español cantado.
  /// Colapsa vocales alargadas por el canto ("muuuusica" -> "musica") y unifica grafías equivalentes (b/v, s/z, ll/y, etc.)
  static String toSpanishPhonetic(String word) {
    var s = normalizeWord(word);
    if (s.isEmpty) return '';

    // 1. Dígrafos y sonidos especiales antes de colapsar
    s = s.replaceAll('ch', 'C');
    s = s.replaceAll('ll', 'y');
    s = s.replaceAll('rr', 'r');
    s = s.replaceAll('qu', 'k');

    // 2. Colapsar repeticiones consecutivas de letras (vocales o consonantes sostenidas al cantar: "muuuusica" -> "musica")
    s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);

    // 3. Unificar fonemas equivalentes en español hispanoamericano
    s = s.replaceAll('v', 'b');
    s = s.replaceAll('z', 's');
    s = s.replaceAllMapped(RegExp(r'c([ei])'), (m) => 's${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'c([aou])'), (m) => 'k${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'g([ei])'), (m) => 'j${m.group(1)}');
    s = s.replaceAll('h', '');
    s = s.replaceAll('C', 'ch');

    return s;
  }

  /// Calcula la distancia de similitud fonética/ortográfica Levenshtein
  static double similarity(String s1, String s2) {
    final a = normalizeWord(s1);
    final b = normalizeWord(s2);

    if (a == b && a.isNotEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final distance = _levenshteinDistance(a, b);
    final maxLength = math.max(a.length, b.length);
    final rawSim = 1.0 - (distance / maxLength);

    // Comparación fonética complementaria (para canto y transcripción NDK)
    final p1 = toSpanishPhonetic(s1);
    final p2 = toSpanishPhonetic(s2);
    if (p1 == p2 && p1.isNotEmpty) return 1.0;

    final pDist = _levenshteinDistance(p1, p2);
    final pMaxLen = math.max(p1.length, p2.length);
    final pSim = pMaxLen > 0 ? (1.0 - (pDist / pMaxLen)) : 0.0;

    return math.max(rawSim, pSim);
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
