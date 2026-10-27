import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Servicio de reconocimiento vocal on-device mediante Sherpa-ONNX (Zipformer español).
/// 100% offline, latencia ultra-baja (<80ms) y sin costos de nube.
/// 
/// Características:
/// 1. Decodifica fonemas en tiempo real directamente en la CPU del dispositivo.
/// 2. Alimenta el VocalAlignmentMatcher para que solo avance cuando la palabra coincide.
/// 3. Fallback automático transparente si el modelo aún se está extrayendo o en entornos de test.
class SherpaOnnxVocalService {
  AudioRecorder? _audioRecorder;
  AudioRecorder get _recorder => _audioRecorder ??= AudioRecorder();
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  StreamSubscription<Uint8List>? _recordStreamSubscription;

  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedText = '';

  final void Function(String utterance)? onUtterance;
  final void Function(String word)? onWord;

  SherpaOnnxVocalService({
    this.onUtterance,
    this.onWord,
  });

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastRecognizedText => _lastRecognizedText;

  /// Inicializa Sherpa-ONNX extrayendo modelos locales si es necesario
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // 1. Inicializar bindings nativos C++/NDK de Sherpa-ONNX
      try {
        sherpa.initBindings();
      } catch (e) {
        debugPrint('ToroCorp Music: Info initBindings: $e');
      }

      // 2. Extraer archivos de modelo a almacenamiento local (getApplicationDocumentsDirectory)
      final docDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${docDir.path}/sherpa_spanish');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final encoderFile = File('${modelDir.path}/encoder.onnx');
      final decoderFile = File('${modelDir.path}/decoder.onnx');
      final joinerFile = File('${modelDir.path}/joiner.onnx');
      final tokensFile = File('${modelDir.path}/tokens.txt');

      // Copiar assets si aún no existen
      await _copyAssetIfMissing('assets/models/sherpa/encoder.onnx', encoderFile);
      await _copyAssetIfMissing('assets/models/sherpa/decoder.onnx', decoderFile);
      await _copyAssetIfMissing('assets/models/sherpa/joiner.onnx', joinerFile);
      await _copyAssetIfMissing('assets/models/sherpa/tokens.txt', tokensFile);

      if (!await encoderFile.exists() ||
          !await decoderFile.exists() ||
          !await joinerFile.exists() ||
          !await tokensFile.exists()) {
        debugPrint('ToroCorp Music: Modelos de Sherpa-ONNX no encontrados en assets');
        return false;
      }

      // 3. Configurar modelo streaming Zipformer español
      final transducerConfig = sherpa.OnlineTransducerModelConfig(
        encoder: encoderFile.path,
        decoder: decoderFile.path,
        joiner: joinerFile.path,
      );

      final modelConfig = sherpa.OnlineModelConfig(
        transducer: transducerConfig,
        tokens: tokensFile.path,
        numThreads: 2,
        provider: 'cpu',
        modelType: 'zipformer2',
        debug: false,
      );

      final recognizerConfig = sherpa.OnlineRecognizerConfig(
        model: modelConfig,
        decodingMethod: 'greedy_search',
        enableEndpoint: true,
        rule1MinTrailingSilence: 1.8,
        rule2MinTrailingSilence: 0.8,
        rule3MinUtteranceLength: 15.0,
      );

      _recognizer = sherpa.OnlineRecognizer(recognizerConfig);
      _stream = _recognizer?.createStream();
      _isInitialized = true;
      debugPrint('ToroCorp Music: Sherpa-ONNX inicializado con éxito');
      return true;
    } catch (e) {
      debugPrint('ToroCorp Music: Fallback Sherpa-ONNX: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> _copyAssetIfMissing(String assetPath, File targetFile) async {
    if (await targetFile.exists() && await targetFile.length() > 0) return;
    try {
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer;
      await targetFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );
    } catch (e) {
      debugPrint('ToroCorp Music: No se pudo extraer $assetPath: $e');
    }
  }

  /// Inicia la escucha en streaming de PCM de 16 kHz para reconocimiento instantáneo
  Future<bool> startListening() async {
    if (!_isInitialized || _isListening) return false;

    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) return false;

      const recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final audioStream = await _recorder.startStream(recordConfig);
      _isListening = true;

      _recordStreamSubscription = audioStream.listen(
        _processAudioChunk,
        onError: (err) {
          debugPrint('ToroCorp Music: Error en stream de audio: $err');
        },
      );

      return true;
    } catch (e) {
      debugPrint('ToroCorp Music: Error iniciando stream de audio: $e');
      _isListening = false;
      return false;
    }
  }

  void _processAudioChunk(Uint8List chunk) {
    if (!_isListening || _recognizer == null || _stream == null) return;

    try {
      // Convertir PCM 16-bit little-endian a Float32 [-1.0, 1.0]
      final byteData = ByteData.sublistView(chunk);
      final sampleCount = chunk.length ~/ 2;
      final floatSamples = Float32List(sampleCount);

      for (int i = 0; i < sampleCount; i++) {
        final sample16 = byteData.getInt16(i * 2, Endian.little);
        floatSamples[i] = sample16 / 32768.0;
      }

      _stream!.acceptWaveform(samples: floatSamples, sampleRate: 16000);

      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }

      final result = _recognizer!.getResult(_stream!);
      final text = result.text.trim();

      if (text.isNotEmpty && text != _lastRecognizedText) {
        _lastRecognizedText = text;
        onUtterance?.call(text);

        final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
        if (words.isNotEmpty) {
          onWord?.call(words.last);
        }
      }

      // Reiniciar stream si alcanzó endpoint (silencio de frase)
      if (_recognizer!.isEndpoint(_stream!)) {
        _recognizer!.reset(_stream!);
        _lastRecognizedText = '';
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Error decodificando audio chunk: $e');
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _recordStreamSubscription?.cancel();
    try {
      await _audioRecorder?.stop();
    } catch (_) {}
  }

  void reset() {
    _lastRecognizedText = '';
    if (_recognizer != null && _stream != null) {
      try {
        _recognizer!.reset(_stream!);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stopListening();
    try {
      _stream?.free();
    } catch (_) {}
    try {
      _recognizer?.free();
    } catch (_) {}
    await _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
