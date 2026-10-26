import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de gestión de suscripciones Pro y derechos de usuario (Entitlements).
/// Soporta modo offline mediante caché local con SharedPreferences.
class SubscriptionService extends ChangeNotifier {
  static const String _proCacheKey = 'toro_music_is_pro_user';

  bool _isPro = false;
  bool _isInitialized = false;

  bool get isPro => _isPro;
  bool get isInitialized => _isInitialized;

  SubscriptionService() {
    _loadCachedEntitlement();
  }

  Future<void> _loadCachedEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPro = prefs.getBool(_proCacheKey) ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando suscripción en caché: $e');
      _isInitialized = true;
    }
  }

  /// Verifica si el usuario puede exportar en 4K (por suscripción Pro o anuncio recompensado)
  bool canExport4K({required bool isPro, required bool hasWatchedReward}) {
    return isPro || hasWatchedReward;
  }

  /// Verifica si se debe omitir la marca de agua (por suscripción Pro o anuncio recompensado)
  bool shouldRemoveWatermark({required bool isPro, required bool hasWatchedReward}) {
    return isPro || hasWatchedReward;
  }

  /// Actualiza el estado Pro y lo persiste localmente
  Future<void> setProStatus(bool isPro) async {
    _isPro = isPro;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_proCacheKey, isPro);
    } catch (e) {
      debugPrint('Error guardando estado Pro en caché: $e');
    }
  }

  /// Simula o procesa la restauración de compras desde la App Store / Google Play
  Future<bool> restorePurchases() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _isPro;
  }
}
