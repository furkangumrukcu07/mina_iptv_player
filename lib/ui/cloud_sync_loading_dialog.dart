import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'glass_overlays.dart';

/// Google ile oturum açıldıktan sonra bulut ayarları yüklenirken gösterilen,
/// kapatılamaz cam popup. İşlem bitince [dismissCloudSyncLoadingDialog] ile
/// kapatılır (veya navigasyon route'u değiştiğinde otomatik kalkar).
class CloudSyncLoadingDialog extends StatelessWidget {
  const CloudSyncLoadingDialog({super.key, this.message});

  /// Gösterilecek metin; null ise `cloud.prompt.loading` çevirisi kullanılır.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: GlassPopupPanel(
            gradientBlendTowardBlack: 0.25,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message ?? 'cloud.prompt.loading'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yükleniyor popup'ını açar (kapatılamaz). Zaten açıksa tekrar açmaz.
void showCloudSyncLoadingDialog({String? message}) {
  if (Get.isDialogOpen ?? false) return;
  Get.dialog<void>(
    CloudSyncLoadingDialog(message: message),
    barrierDismissible: false,
    useSafeArea: false,
  );
}

/// Açıksa yükleniyor popup'ını kapatır.
void dismissCloudSyncLoadingDialog() {
  if (Get.isDialogOpen ?? false) Get.back<void>();
}
