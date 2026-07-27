import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';

/// Bulut geri yüklemesi sonrası çoklu liste doğrulama özeti.
@immutable
class CloudPlaylistRestoreReport {
  const CloudPlaylistRestoreReport({
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.failedSlots,
    required this.skippedValidation,
  });

  final int totalCount;
  final int successCount;
  final int failedCount;
  final List<int> failedSlots;

  /// Doğrulama atlandı veya devre dışı bırakıldı.
  final bool skippedValidation;

  bool get hasPartialFailure =>
      !skippedValidation && failedCount > 0 && successCount > 0;

  bool get allPlaylistsFailed =>
      !skippedValidation && totalCount > 1 && successCount == 0;

  bool get shouldWarn =>
      !skippedValidation && totalCount > 1 && failedCount > 0;
}

/// Google bulut geri yüklemesinden sonra birden fazla M3U/Xtream listesinin
/// doğrulanmasını yöneten sınıf.
/// 
/// [Kritik Güncelleme]: Geri yükleme sırasında ağ üzerinden tek tek listeleri indirmek
/// ve doğrulamak çok uzun sürmekte (timeout), kararsız sunucularda hata vermekte ve 
/// kullanıcının buluttan gelen geçerli IPTV bilgilerinin yanlışlıkla silinmesine (wiping) 
/// yol açmaktadır. Bu nedenle ağ doğrulaması devredışı bırakılmış, tüm kaynaklar 
/// güvenle yerel depolamada korunmuştur.
class CloudPlaylistRestoreValidator {
  CloudPlaylistRestoreValidator._();

  static Future<CloudPlaylistRestoreReport> validateAndPruneFailedSlots({
    PlaylistRepository? repo,
  }) async {
    if (!Get.isRegistered<PlaylistRepository>()) {
      return const CloudPlaylistRestoreReport(
        totalCount: 0,
        successCount: 0,
        failedCount: 0,
        failedSlots: [],
        skippedValidation: true,
      );
    }

    final r = repo ?? Get.find<PlaylistRepository>();
    List<({int slot, PlaylistSource source})> sources;
    try {
      sources = await r.readAllSources();
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudPlaylistRestoreValidator] readAllSources: $e');
      return const CloudPlaylistRestoreReport(
        totalCount: 0,
        successCount: 0,
        failedCount: 0,
        failedSlots: [],
        skippedValidation: true,
      );
    }

    // Tüm listelerin silinmeden korunması ve hızlı yükleme için ağ doğrulamasını atlıyoruz.
    if (kDebugMode) debugPrint(
      '[CloudPlaylistRestoreValidator] Skipping network validation check to preserve '
      'all ${sources.length} restored playlist slots and prevent network timeouts.',
    );

    // [Önemli]: Eğer birincil (1.) slot boş ise ve diğer slotlarda (2, 3, 4 vb.) aktif listeler varsa,
    // aktif slot ayarını ilk dolu olan slota yönlendirerek uygulamanın kuruluma geri dönmesini engelliyoruz.
    if (sources.isNotEmpty) {
      try {
        final okSlots = sources.map((e) => e.slot).toList()..sort();
        final prefs = await SharedPreferences.getInstance();
        final active = prefs.getInt('mina_active_playlist_slot') ?? 1;
        if (!okSlots.contains(active)) {
          final target = okSlots.first;
          await prefs.setInt('mina_active_playlist_slot', target);
          if (kDebugMode) debugPrint(
            '[CloudPlaylistRestoreValidator] Active slot $active was empty. Reconciled to first available slot $target.',
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[CloudPlaylistRestoreValidator] active slot reconcile error: $e');
      }
    }

    return CloudPlaylistRestoreReport(
      totalCount: sources.length,
      successCount: sources.length,
      failedCount: 0,
      failedSlots: const [],
      skippedValidation: true,
    );
  }
}
