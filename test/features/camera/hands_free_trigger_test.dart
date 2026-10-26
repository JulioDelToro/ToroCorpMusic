import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/camera/services/hands_free_trigger_service.dart';

void main() {
  test('HandsFreeTrigger triggers 3-2-1 countdown on voice command "grabar"', () {
    bool triggered = false;
    final service = HandsFreeTriggerService(onCountdownStart: () => triggered = true);

    service.handleVoiceKeyword("grabar");
    expect(triggered, isTrue);
  });

  test('HandsFreeTrigger triggers countdown on palm detection confirmation', () {
    bool triggered = false;
    final service = HandsFreeTriggerService(onCountdownStart: () => triggered = true);

    service.handlePalmDetected(confidence: 0.85);
    expect(triggered, isTrue);
  });
}
