import 'package:flutter/foundation.dart';

/// Administrador de publicidad inteligente (Smart Ads).
/// Implementa anuncios intersticiales al guardar/exportar y anuncios recompensados (Rewarded)
/// para desbloquear 4K o eliminar la marca de agua sin costo.
class AdManager {
  bool _isAdLoading = false;

  bool get isAdLoading => _isAdLoading;

  /// Muestra un anuncio intersticial cuando el usuario presiona "Guardar en Galería".
  /// No interrumpe la interpretación musical del guitarrista.
  Future<void> showSaveInterstitial({
    required bool isProUser,
    required VoidCallback onDismissed,
  }) async {
    if (isProUser) {
      // Los usuarios Pro no ven ningún anuncio
      onDismissed();
      return;
    }

    _isAdLoading = true;
    try {
      // Simulación de carga y despliegue de anuncio intersticial
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('AdManager: Intersticial mostrado al exportar');
    } catch (e) {
      debugPrint('Error mostrando intersticial: $e');
    } finally {
      _isAdLoading = false;
      onDismissed();
    }
  }

  /// Muestra un anuncio recompensado (Rewarded Video) para desbloquear 4K o exportar sin marca de agua
  Future<void> showRewardedAdFor4K({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onFailed,
  }) async {
    _isAdLoading = true;
    try {
      // Simulación de visualización de video de 20 segundos
      await Future.delayed(const Duration(milliseconds: 600));
      debugPrint('AdManager: Recompensa 4K / Sin Marca otorgada al usuario');
      onUserEarnedReward();
    } catch (e) {
      debugPrint('Error mostrando anuncio recompensado: $e');
      onFailed();
    } finally {
      _isAdLoading = false;
    }
  }
}
