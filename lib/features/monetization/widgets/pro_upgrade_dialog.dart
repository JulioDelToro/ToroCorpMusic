import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../services/ad_manager.dart';
import '../services/subscription_service.dart';

/// Diálogo modal para promocionar la Suscripción Pro y ofrecer desbloqueo gratuito vía anuncio
class ProUpgradeDialog extends StatelessWidget {
  final SubscriptionService subscriptionService;
  final AdManager adManager;
  final VoidCallback? onSinglePassUnlocked;

  const ProUpgradeDialog({
    super.key,
    required this.subscriptionService,
    required this.adManager,
    this.onSinglePassUnlocked,
  });

  static Future<void> show(
    BuildContext context, {
    required SubscriptionService subscriptionService,
    required AdManager adManager,
    VoidCallback? onSinglePassUnlocked,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (context) => ProUpgradeDialog(
        subscriptionService: subscriptionService,
        adManager: adManager,
        onSinglePassUnlocked: onSinglePassUnlocked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.chordAmber, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: AppColors.chordAmber, size: 40),
            const SizedBox(height: 8),
            Text(
              'ToroCorp Music PRO',
              style: AppTypography.sfProHeadline(fontSize: 22),
            ),
            const SizedBox(height: 16),

            _buildBenefitRow(Icons.check_circle, 'Sin marca de agua en tus videos'),
            _buildBenefitRow(Icons.check_circle, 'Exportación en 4K Ultra HD a 30 y 60 fps'),
            _buildBenefitRow(Icons.check_circle, '100% Cero anuncios en toda la app'),
            _buildBenefitRow(Icons.check_circle, 'Soporte para pedal Bluetooth y filtros prémium'),

            const SizedBox(height: 20),

            // Botón Suscripción Pro
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await subscriptionService.setProStatus(true);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Bienvenido a ToroCorp Music PRO!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chordAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Activar Pro (\$1.99 / mes)',
                  style: AppTypography.sfProHeadline(fontSize: 15, color: Colors.black),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Opción Anuncio Recompensado (Gratis)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  adManager.showRewardedAdFor4K(
                    onUserEarnedReward: () {
                      onSinglePassUnlocked?.call();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('¡4K y Sin Marca desbloqueados para esta exportación!')),
                        );
                      }
                    },
                    onFailed: () {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No se pudo cargar el anuncio. Intenta más tarde.')),
                        );
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_outline, color: AppColors.textWhite, size: 18),
                label: Text(
                  'Desbloquear gratis con 1 anuncio',
                  style: AppTypography.sfProCaption(color: AppColors.textWhite),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderDark),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Restaurar y Cerrar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () async {
                    await subscriptionService.restorePurchases();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Restaurar compras', style: AppTypography.sfProCaption()),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cerrar', style: AppTypography.sfProCaption()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.chordAmber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.sfProCaption(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }
}
