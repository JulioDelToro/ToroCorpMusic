import 'dart:math' as math;
import 'dart:typed_data';
import '../models/tuning_note.dart';

/// Detector y analizador de frecuencias para afinador de guitarra (6 y 12 cuerdas).
/// 100% código propio, algorítmico y comercialmente licenciable.
class PitchDetector {
  /// Afinación estándar para guitarra de 6 cuerdas (de más aguda a más grave)
  static const List<ReferenceNote> standard6StringTuning = [
    ReferenceNote(name: 'E4', frequency: 329.63, stringIndex: 1, label: '1ª Cuerda (Mi)'),
    ReferenceNote(name: 'B3', frequency: 246.94, stringIndex: 2, label: '2ª Cuerda (Si)'),
    ReferenceNote(name: 'G3', frequency: 196.00, stringIndex: 3, label: '3ª Cuerda (Sol)'),
    ReferenceNote(name: 'D3', frequency: 146.83, stringIndex: 4, label: '4ª Cuerda (Re)'),
    ReferenceNote(name: 'A2', frequency: 110.00, stringIndex: 5, label: '5ª Cuerda (La)'),
    ReferenceNote(name: 'E2', frequency: 82.41, stringIndex: 6, label: '6ª Cuerda (Mi grave)'),
  ];

  /// Compatibilidad
  static const List<ReferenceNote> standardGuitarTuning = standard6StringTuning;

  /// Afinación estándar para guitarra de 12 cuerdas / Docerola (pares ordenados de 1 a 12)
  static const List<ReferenceNote> standard12StringTuning = [
    ReferenceNote(name: 'E4', frequency: 329.63, stringIndex: 1, label: '1ª Unísono (Mi)'),
    ReferenceNote(name: 'E4', frequency: 329.63, stringIndex: 2, label: '2ª Unísono (Mi)'),
    ReferenceNote(name: 'B3', frequency: 246.94, stringIndex: 3, label: '3ª Unísono (Si)'),
    ReferenceNote(name: 'B3', frequency: 246.94, stringIndex: 4, label: '4ª Unísono (Si)'),
    ReferenceNote(name: 'G3', frequency: 196.00, stringIndex: 5, label: '5ª Fundamental (Sol)'),
    ReferenceNote(name: 'G4', frequency: 392.00, stringIndex: 6, label: '6ª Octava (Sol alto)'),
    ReferenceNote(name: 'D3', frequency: 146.83, stringIndex: 7, label: '7ª Fundamental (Re)'),
    ReferenceNote(name: 'D4', frequency: 293.66, stringIndex: 8, label: '8ª Octava (Re alto)'),
    ReferenceNote(name: 'A2', frequency: 110.00, stringIndex: 9, label: '9ª Fundamental (La)'),
    ReferenceNote(name: 'A3', frequency: 220.00, stringIndex: 10, label: '10ª Octava (La alto)'),
    ReferenceNote(name: 'E2', frequency: 82.41, stringIndex: 11, label: '11ª Fundamental (Mi)'),
    ReferenceNote(name: 'E3', frequency: 164.81, stringIndex: 12, label: '12ª Octava (Mi alto)'),
  ];

  /// Analiza una frecuencia detectada (en Hz) para el tipo de guitarra seleccionado.
  /// Permite fijar una cuerda específica (afinar cuerda por cuerda) o auto-detección.
  TuningResult analyzeFrequency(
    double frequency, {
    GuitarType guitarType = GuitarType.sixString,
    int? lockedStringIndex,
    double toleranceCents = 3.5,
  }) {
    final tuningNotes = guitarType == GuitarType.sixString
        ? standard6StringTuning
        : standard12StringTuning;

    if (frequency <= 0) {
      if (lockedStringIndex != null) {
        final lockedNote = tuningNotes.firstWhere(
          (n) => n.stringIndex == lockedStringIndex,
          orElse: () => tuningNotes.first,
        );
        return TuningResult(
          detectedFrequency: 0,
          closestNote: lockedNote.name,
          targetFrequency: lockedNote.frequency,
          centsOffset: 0,
          isInTune: false,
          targetStringIndex: lockedStringIndex,
        );
      }

      return const TuningResult(
        detectedFrequency: 0,
        closestNote: '--',
        targetFrequency: 0,
        centsOffset: 0,
        isInTune: false,
      );
    }

    ReferenceNote target;

    if (lockedStringIndex != null) {
      // Afinar cuerda por cuerda: compara específicamente contra la cuerda seleccionada
      target = tuningNotes.firstWhere(
        (n) => n.stringIndex == lockedStringIndex,
        orElse: () => tuningNotes.first,
      );
    } else {
      // Auto-detección: busca la cuerda más cercana en Hz
      ReferenceNote closest = tuningNotes.first;
      double minDiff = double.infinity;

      for (final note in tuningNotes) {
        final diff = (note.frequency - frequency).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = note;
        }
      }
      target = closest;
    }

    // Fórmula estándar: cents = 1200 * log2(f / f0)
    final centsOffset = 1200.0 * (math.log(frequency / target.frequency) / math.ln2);
    final isInTune = centsOffset.abs() <= toleranceCents;

    return TuningResult(
      detectedFrequency: frequency,
      closestNote: target.name,
      targetFrequency: target.frequency,
      centsOffset: centsOffset.clamp(-50.0, 50.0),
      isInTune: isInTune,
      targetStringIndex: target.stringIndex,
    );
  }

  /// Detecta la frecuencia fundamental en Hz de un búfer de audio PCM 16-bit
  /// utilizando autocorrelación normalizada con interpolación parabólica.
  static double detectPitchFromPcm16(
    Uint8List pcmBytes, {
    int sampleRate = 22050,
    double minFrequency = 70.0,
    double maxFrequency = 450.0,
    double silenceRmsThreshold = 0.012,
  }) {
    final sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount < 256) return 0.0;

    final byteData = ByteData.sublistView(pcmBytes);
    final samples = Float64List(sampleCount);

    double sumSquares = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final s = byteData.getInt16(i * 2, Endian.little) / 32768.0;
      samples[i] = s;
      sumSquares += s * s;
    }

    final rms = math.sqrt(sumSquares / sampleCount);
    if (rms < silenceRmsThreshold) {
      return 0.0;
    }

    final minLag = (sampleRate / maxFrequency).floor();
    final maxLag = (sampleRate / minFrequency).ceil().clamp(minLag + 1, sampleCount ~/ 2);

    double bestCorrelation = -1.0;
    int bestLag = -1;

    for (int lag = minLag; lag <= maxLag; lag++) {
      double sum = 0.0;
      double sumSquareA = 0.0;
      double sumSquareB = 0.0;

      final n = sampleCount - lag;
      for (int i = 0; i < n; i++) {
        final a = samples[i];
        final b = samples[i + lag];
        sum += a * b;
        sumSquareA += a * a;
        sumSquareB += b * b;
      }

      final norm = math.sqrt(sumSquareA * sumSquareB);
      if (norm > 0) {
        final correlation = sum / norm;
        if (correlation > bestCorrelation) {
          bestCorrelation = correlation;
          bestLag = lag;
        }
      }
    }

    if (bestCorrelation >= 0.50 && bestLag > minLag && bestLag < maxLag) {
      // Interpolación parabólica
      final y0 = _calculateCorrelationAtLag(samples, bestLag - 1, sampleCount);
      final y1 = bestCorrelation;
      final y2 = _calculateCorrelationAtLag(samples, bestLag + 1, sampleCount);

      final denom = 2.0 * (2.0 * y1 - y0 - y2);
      double delta = 0.0;
      if (denom.abs() > 1e-6) {
        delta = (y2 - y0) / denom;
      }

      final trueLag = bestLag + delta;
      if (trueLag > 0) {
        return sampleRate / trueLag;
      }
    }

    return 0.0;
  }

  static double _calculateCorrelationAtLag(Float64List samples, int lag, int sampleCount) {
    if (lag <= 0 || lag >= sampleCount) return 0.0;
    double sum = 0.0;
    double sumA = 0.0;
    double sumB = 0.0;
    final n = sampleCount - lag;
    for (int i = 0; i < n; i++) {
      final a = samples[i];
      final b = samples[i + lag];
      sum += a * b;
      sumA += a * a;
      sumB += b * b;
    }
    final norm = math.sqrt(sumA * sumB);
    return norm > 0 ? sum / norm : 0.0;
  }
}
