import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/search_history_service.dart';

/// Arama diyaloglarında giriş alanının hemen altında belirip kullanıcının
/// son aramalarını tek dokunuşla geri çağırmasını sağlayan chip şeridi.
///
/// Şerit yalnızca veri varsa render edilir — boş geçmişte ekranda yer
/// kaplamaz. Cam (glass) temasıyla uyumlu, koyu yüzey üzerinde okunaklı
/// kontrast için Material `InputChip` kullanmıyoruz.
class RecentSearchesStrip extends StatelessWidget {
  const RecentSearchesStrip({
    super.key,
    required this.scope,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  });

  /// Hangi kapsamın geçmişi listelenecek.
  final SearchHistoryScope scope;

  /// Kullanıcı bir chip'e dokunduğunda çağrılır — diyalog bu metni input'a
  /// yazıp aramayı tetiklemekten sorumlu.
  final void Function(String query) onTap;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<SearchHistoryService>();
    return Obx(() {
      final items = svc.historyFor(scope).toList(growable: false);
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'search.recent.title'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => svc.clear(scope),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      'search.recent.clear'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final q in items)
                  _RecentChip(
                    label: q,
                    onTap: () => onTap(q),
                    onRemove: () => svc.remove(scope, q),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
