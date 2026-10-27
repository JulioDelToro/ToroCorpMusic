import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/audio/services/sherpa_onnx_vocal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'create') return null;
        if (methodCall.method == 'hasPermission') return true;
        if (methodCall.method == 'dispose') return null;
        if (methodCall.method == 'stop') return null;
        if (methodCall.method == 'start') return null;
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  group('SherpaOnnxVocalService Tests', () {
    test('Estado inicial no inicializado y no escuchando', () {
      final service = SherpaOnnxVocalService();
      expect(service.isInitialized, isFalse);
      expect(service.isListening, isFalse);
      expect(service.lastRecognizedText, isEmpty);
    });

    test('Callbacks de palabra y frase se invocan adecuadamente', () {
      String? detectedUtterance;
      String? detectedWord;

      final service = SherpaOnnxVocalService(
        onUtterance: (u) => detectedUtterance = u,
        onWord: (w) => detectedWord = w,
      );

      service.onUtterance?.call('De música ligera');
      service.onWord?.call('ligera');

      expect(detectedUtterance, equals('De música ligera'));
      expect(detectedWord, equals('ligera'));
    });

    test('Reset limpia el último texto reconocido', () {
      final service = SherpaOnnxVocalService();
      service.reset();
      expect(service.lastRecognizedText, isEmpty);
    });
  });
}
