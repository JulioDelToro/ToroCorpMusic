import 'package:flutter/material.dart';

/// Paleta oficial de colores para ToroCorp Music.
/// Optimizado para pantallas OLED (ahorro de batería y máximo contraste).
abstract final class AppColors {
  // Fondos OLED
  static const Color pureBlackOled = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color borderDark = Color(0xFF2A2A2A);

  // Textos y Contraste
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93); // Gris Apple
  static const Color textTertiary = Color(0xFF48484A);

  // Acentos de Músicos
  static const Color chordAmber = Color(0xFFFFD166); // Color notas musicales
  static const Color karaokeActiveWord = Color(0xFFFFFFFF); // Resplandor palabra cantada
  static const Color tunerInTuneGreen = Color(0xFF30D158); // Afinación perfecta
  static const Color tunerFlatRed = Color(0xFFFF453A); // Bemol / Desafinado
  static const Color recordRed = Color(0xFFFF3B30); // Grabando
}
