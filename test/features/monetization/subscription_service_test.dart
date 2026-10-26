import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toro_music_teleprompter/features/monetization/services/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Pro subscription removes ads and enables 4K', () {
    final service = SubscriptionService();
    expect(service.canExport4K(isPro: false, hasWatchedReward: false), isFalse);
    expect(service.canExport4K(isPro: false, hasWatchedReward: true), isTrue);
    expect(service.canExport4K(isPro: true, hasWatchedReward: false), isTrue);
  });

  test('Watermark removal logic accurately checks Pro or rewarded single-pass', () {
    final service = SubscriptionService();
    expect(service.shouldRemoveWatermark(isPro: false, hasWatchedReward: false), isFalse);
    expect(service.shouldRemoveWatermark(isPro: false, hasWatchedReward: true), isTrue);
    expect(service.shouldRemoveWatermark(isPro: true, hasWatchedReward: false), isTrue);
  });
}
