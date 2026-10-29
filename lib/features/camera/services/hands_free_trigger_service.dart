import 'dart:async';
import 'package:flutter/foundation.dart';

/// Servicio de disparadores manos libres (gesto con la palma de la mano y comandos de voz).
/// Permite al guitarrista iniciar la grabación sin soltar el instrumento.
class HandsFreeTriggerService {
  final VoidCallback onCountdownStart;
  final VoidCallback? onCountdownComplete;
  final Duration countdownDuration;

  bool _isArmed = true;
  bool _isCountingDown = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  HandsFreeTriggerService({
    required this.onCountdownStart,
    this.onCountdownComplete,
    this.countdownDuration = const Duration(seconds: 5),
  });

  bool get isArmed => _isArmed;
  bool get isCountingDown => _isCountingDown;
  int get countdownSeconds => _countdownSeconds;

  void setArmed(bool armed) {
    _isArmed = armed;
  }

  /// Procesa palabras clave de voz para iniciar grabación
  void handleVoiceKeyword(String rawWord) {
    if (!_isArmed || _isCountingDown) return;

    final clean = rawWord.trim().toLowerCase();
    const triggerWords = ['grabar', 'graba', 'iniciar', 'comenzar', 'record', 'start'];

    if (triggerWords.contains(clean)) {
      _startCountdown();
    }
  }

  void triggerFromVoiceCommand(String command) {
    handleVoiceKeyword(command);
  }

  /// Procesa eventos de detección de la palma de la mano abierta
  void handlePalmDetected({required double confidence}) {
    if (!_isArmed || _isCountingDown) return;

    // Umbral de certeza del 70%
    if (confidence >= 0.70) {
      _startCountdown();
    }
  }

  void triggerFromPalmGesture() {
    handlePalmDetected(confidence: 0.95);
  }

  void _startCountdown() {
    _isCountingDown = true;
    _countdownSeconds = 5;
    onCountdownStart();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      onCountdownStart();
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _isCountingDown = false;
        onCountdownComplete?.call();
      }
    });
  }

  void cancelCountdown() {
    _countdownTimer?.cancel();
    _isCountingDown = false;
    _countdownSeconds = 5;
  }

  void dispose() {
    _countdownTimer?.cancel();
  }
}
