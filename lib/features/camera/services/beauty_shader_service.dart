import 'package:flutter/foundation.dart';

/// Servicio de gestión del filtro de belleza en tiempo real (GPU / Shaders)
class BeautyShaderService extends ChangeNotifier {
  double _intensity = 0.35; // 35% por defecto (suavizado natural)

  double get intensity => _intensity;

  /// Establece la intensidad del filtro entre 0.0 (0%) y 1.0 (100%)
  void setIntensity(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_intensity != clamped) {
      _intensity = clamped;
      notifyListeners();
    }
  }

  /// Retorna la etiqueta legible del nivel de belleza
  String get intensityLabel {
    if (_intensity <= 0.01) return 'Desactivado';
    if (_intensity < 0.40) return 'Natural';
    if (_intensity < 0.75) return 'Medio';
    return 'Glamour';
  }
}
