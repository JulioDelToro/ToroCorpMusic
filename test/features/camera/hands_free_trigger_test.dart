import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/camera/services/hands_free_trigger_service.dart';

void main() {
  test('HandsFreeTrigger triggers 5-second countdown on voice command "grabar"', () {
    bool triggered = false;
    final service = HandsFreeTriggerService(onCountdownStart: () => triggered = true);

    expect(service.countdownDuration.inSeconds, equals(5));
    service.handleVoiceKeyword("grabar");
    expect(triggered, isTrue);
    expect(service.isCountingDown, isTrue);
    expect(service.countdownSeconds, equals(5));
  });

  test('HandsFreeTrigger triggers 5-second countdown on palm detection confirmation', () {
    bool triggered = false;
    final service = HandsFreeTriggerService(onCountdownStart: () => triggered = true);

    service.handlePalmDetected(confidence: 0.85);
    expect(triggered, isTrue);
    expect(service.isCountingDown, isTrue);
    expect(service.countdownSeconds, equals(5));
  });
}
