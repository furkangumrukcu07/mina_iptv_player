import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../ui/tv_dpad_focus.dart';

/// Film / dizi detay üst çubuğu — mobil dokunmatik + TV/tablet D-pad.
class FilmDiziDetailTopBar extends StatefulWidget {
  const FilmDiziDetailTopBar({
    super.key,
    required this.onBack,
    this.onFavorite,
    this.isFavorite = false,
    this.autofocusBack = true,
  });

  final VoidCallback onBack;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  /// İlk açılışta kumanda odağını geri düğmesine ver. Yatay film/dizi detayında
  /// odak İzle/Bölüm 1'e gittiği için `false` geçilir.
  final bool autofocusBack;

  @override
  State<FilmDiziDetailTopBar> createState() => _FilmDiziDetailTopBarState();
}

class _FilmDiziDetailTopBarState extends State<FilmDiziDetailTopBar> {
  final FocusNode _backFocus = FocusNode(debugLabel: 'filmDiziBack');
  final FocusNode _favFocus = FocusNode(debugLabel: 'filmDiziFav');

  /// İlk açılışta bir kez geri düğmesine odak verilir. Sonraki rebuild'lerde
  /// (favori durumu değişince üstteki Obx tetikler) odak ZORLANMAZ; aksi halde
  /// içerikteki oynat/indir/poster odağı geri düğmesine çalınıyordu.
  bool _didInitialFocus = false;

  @override
  void dispose() {
    _backFocus.dispose();
    _favFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );

    if (!remote) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: widget.onBack,
            ),
            const Spacer(),
            if (widget.onFavorite != null)
              IconButton(
                icon: Icon(
                  widget.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: widget.isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                ),
                onPressed: widget.onFavorite,
              ),
          ],
        ),
      );
    }

    if (!_didInitialFocus && widget.autofocusBack) {
      _didInitialFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_backFocus.hasFocus && !_favFocus.hasFocus) {
          _backFocus.requestFocus();
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Row(
          children: [
            TvIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: widget.onBack,
              focusNode: _backFocus,
              autofocus: widget.autofocusBack,
            ),
            const Spacer(),
            if (widget.onFavorite != null)
              TvIconButton(
                icon: widget.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                onPressed: widget.onFavorite!,
                focusNode: _favFocus,
                arrowLeft: _backFocus,
                iconColor: widget.isFavorite
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}
