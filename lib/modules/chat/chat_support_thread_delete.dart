import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/chat_service.dart';
import '../../ui/glass_overlays.dart';

/// "Yöneticiye mesaj" (destek) konuşmasını uzun basınca silmek için ortak akış:
/// önce **Sohbeti Sil** seçeneği içeren cam alt menü, ardından onay diyaloğu.
/// Onaylanırsa thread'in tüm mesajları + meta dökümanı silinir.
///
/// [userUid] silinecek thread'in sahibi kullanıcının UID'si (normal kullanıcı
/// için kendi UID'si; admin gelen kutusunda ilgili kullanıcının UID'si).
Future<void> showSupportThreadDeleteMenu(
  BuildContext context, {
  required String userUid,
}) async {
  final chose = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DeleteThreadSheet(),
  );
  if (chose != true || !context.mounted) return;
  await _confirmAndDelete(context, userUid: userUid);
}

Future<void> _confirmAndDelete(
  BuildContext context, {
  required String userUid,
}) async {
  final remote =
      Get.find<AppSettingsService>().layoutMode.value.usesRemoteNavigationStyle;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dCtx) => GlassAlertDialog(
      tvOsdStyle: remote,
      title: Text('chat.support.deleteTitle'.tr),
      content: Text('chat.support.deleteBody'.tr),
      actions: [
        GlassDialogActionButton(
          label: 'common.cancel'.tr,
          onDarkSurface: remote,
          onPressed: () => Navigator.of(dCtx).pop(false),
        ),
        GlassDialogActionButton(
          label: 'chat.support.deleteThread'.tr,
          primary: true,
          onDarkSurface: remote,
          onPressed: () => Navigator.of(dCtx).pop(true),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final done = await Get.find<ChatService>().deleteSupportThread(userUid);
  GlassSnackbar.show(
    'chat.title'.tr,
    done ? 'chat.support.deleted'.tr : 'chat.support.deleteFailed'.tr,
  );
}

/// Uzun basışta açılan tek seçenekli (Sohbeti Sil) cam alt menü.
class _DeleteThreadSheet extends StatelessWidget {
  const _DeleteThreadSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: _DeleteRow(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteRow extends StatelessWidget {
  const _DeleteRow();

  @override
  Widget build(BuildContext context) {
    const destructive = Color(0xFFFF6B6B);
    return Row(
      children: [
        const Icon(Icons.delete_outline_rounded, color: destructive, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'chat.support.deleteThread'.tr,
            style: const TextStyle(
              color: destructive,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
