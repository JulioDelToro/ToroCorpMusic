import 'package:flutter/foundation.dart';

/// Servicio de gestión del filtro de belleza en tiempo real (GPU / Shaders)
/// Con soporte para intensidad ampliada y suavizado facial de estudio.
class BeautyShaderService extends ChangeNotifier {
  double _intensity = 0.60; // 60% por defecto (suavizado visible y natural)

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
    if (_intensity < 0.35) return 'Suave';
    if (_intensity < 0.70) return 'Estudio (Recomendado)';
    return 'Glamour Total';
  }
}
