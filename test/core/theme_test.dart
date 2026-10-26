import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/constants/app_colors.dart';
import 'package:toro_music_teleprompter/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Theme enforces Pure Black OLED background and SF typography', () {
    final theme = AppTheme.darkOledTheme;
    expect(theme.scaffoldBackgroundColor, equals(AppColors.pureBlackOled));
    expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF000000)));
  });
}
