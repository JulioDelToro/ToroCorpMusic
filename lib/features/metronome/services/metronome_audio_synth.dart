import 'dart:math' as math;
import 'dart:typed_data';

/// Procedural PCM WAV audio synthesizer for ToroCorp Music Metronome.
///
/// Generates 100% royalty-free, mathematically synthesized 16-bit PCM WAV audio
/// buffers in pure Dart. Zero external audio asset dependencies, zero copyright
/// infringement risk, 100% commercial-safe (MIT / Apache 2.0 compatible).
class MetronomeAudioSynth {
  /// Standard downbeat frequency (A6 = 1760 Hz) - crisp, bright piercing woodblock click.
  static const double downbeatFrequency = 1760.0;

  /// Standard regular beat frequency (A5 = 880 Hz) - warm, woody acoustic tick.
  static const double regularBeatFrequency = 880.0;

  /// CD Quality audio sampling frequency.
  static const int defaultSampleRate = 44100;

  /// Downbeat audio duration in seconds (~20-25ms).
  static const double downbeatDurationSec = 0.025;

  /// Regular beat audio duration in seconds (~20ms).
  static const double regularDurationSec = 0.020;

  /// Downbeat exponential decay half-life in seconds (~6ms).
  static const double downbeatDecayHalfLifeSec = 0.006;

  /// Regular beat exponential decay half-life in seconds (~5ms).
  static const double regularDecayHalfLifeSec = 0.005;

  late final Uint8List _downbeatWavBytes;
  late final Uint8List _regularWavBytes;

  /// Constructs the synthesizer and pre-renders click waveforms into memory buffers.
  MetronomeAudioSynth({
    int sampleRate = defaultSampleRate,
  }) {
    _downbeatWavBytes = generateClickWav(
      frequencyHz: downbeatFrequency,
      durationSec: downbeatDurationSec,
      decayHalfLifeSec: downbeatDecayHalfLifeSec,
      sampleRate: sampleRate,
      peakAmplitude: 0.90,
    );

    _regularWavBytes = generateClickWav(
      frequencyHz: regularBeatFrequency,
      durationSec: regularDurationSec,
      decayHalfLifeSec: regularDecayHalfLifeSec,
      sampleRate: sampleRate,
      peakAmplitude: 0.75,
    );
  }

  /// Pre-rendered 16-bit PCM WAV byte buffer for the downbeat click (1760 Hz).
  Uint8List get downbeatWavBytes => _downbeatWavBytes;

  /// Pre-rendered 16-bit PCM WAV byte buffer for regular beat clicks (880 Hz).
  Uint8List get regularWavBytes => _regularWavBytes;

  /// Returns synthesized bytes corresponding to beat type.
  Uint8List getBeatSound({required bool isDownbeat}) {
    return isDownbeat ? _downbeatWavBytes : _regularWavBytes;
  }

  /// Synthesizes a mono 16-bit linear PCM RIFF WAV audio buffer with an
  /// exponential decay envelope and acoustic second harmonic.
  static Uint8List generateClickWav({
    required double frequencyHz,
    required double durationSec,
    required double decayHalfLifeSec,
    int sampleRate = defaultSampleRate,
    double peakAmplitude = 0.85,
  }) {
    final numSamples = (sampleRate * durationSec).toInt();
    final byteDataLength = numSamples * 2; // 16-bit = 2 bytes per sample
    final totalLength = 44 + byteDataLength; // 44-byte standard RIFF header
    final buffer = Uint8List(totalLength);
    final bdata = ByteData.sublistView(buffer);

    // 1. RIFF Header Descriptor
    bdata.setUint8(0, 0x52); // 'R'
    bdata.setUint8(1, 0x49); // 'I'
    bdata.setUint8(2, 0x46); // 'F'
    bdata.setUint8(3, 0x46); // 'F'
    bdata.setUint32(4, 36 + byteDataLength, Endian.little); // Chunk size
    bdata.setUint8(8, 0x57);  // 'W'
    bdata.setUint8(9, 0x41);  // 'A'
    bdata.setUint8(10, 0x56); // 'V'
    bdata.setUint8(11, 0x45); // 'E'

    // 2. "fmt " Sub-chunk (PCM format description)
    bdata.setUint8(12, 0x66); // 'f'
    bdata.setUint8(13, 0x6D); // 'm'
    bdata.setUint8(14, 0x74); // 't'
    bdata.setUint8(15, 0x20); // ' '
    bdata.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for Linear PCM)
    bdata.setUint16(20, 1, Endian.little);  // AudioFormat (1 = Linear PCM)
    bdata.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    bdata.setUint32(24, sampleRate, Endian.little); // SampleRate
    bdata.setUint32(28, sampleRate * 2, Endian.little); // ByteRate (sampleRate * numChannels * 2)
    bdata.setUint16(32, 2, Endian.little);  // BlockAlign (numChannels * 2)
    bdata.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

    // 3. "data" Sub-chunk header
    bdata.setUint8(36, 0x64); // 'd'
    bdata.setUint8(37, 0x61); // 'a'
    bdata.setUint8(38, 0x74); // 't'
    bdata.setUint8(39, 0x61); // 'a'
    bdata.setUint32(40, byteDataLength, Endian.little);

    // 4. Mathematical waveform generation with exponential envelope decay
    final decayConstant = math.ln2 / decayHalfLifeSec;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final decay = math.exp(-t * decayConstant);

      // Fundamental tone + subtle 2nd harmonic for organic clave/woodblock resonance
      final fundamental = math.sin(2.0 * math.pi * frequencyHz * t);
      final harmonic = 0.25 * math.sin(4.0 * math.pi * frequencyHz * t);
      final rawWave = fundamental + harmonic;

      // 16-bit signed integer range: -32768 to 32767
      final sampleVal = (rawWave * decay * peakAmplitude * 32767.0)
          .clamp(-32768.0, 32767.0)
          .toInt();

      bdata.setInt16(44 + (i * 2), sampleVal, Endian.little);
    }

    return buffer;
  }

  /// Verifies whether the provided bytes conform to a valid standard RIFF WAV format.
  static bool isValidPcmWav(Uint8List bytes) {
    if (bytes.length < 44) return false;
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    final fmt = String.fromCharCodes(bytes.sublist(12, 16));
    final data = String.fromCharCodes(bytes.sublist(36, 40));
    return riff == 'RIFF' && wave == 'WAVE' && fmt == 'fmt ' && data == 'data';
  }
}
