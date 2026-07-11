import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';

/// Ayarlar → «Sıkça Sorulan Sorular».
///
/// Uygulamanın oynatma/biçim/tampon gibi özelliklerini açıklayan rehber.
/// İçerik [_faqEntryKeys] üzerinden tamamen i18n anahtarlarıyla gelir; arama
/// hem soru hem cevap metninde (çevrili) çalışır. Maddeler D-pad ile gezilip
/// OK/dokunma ile açılıp kapanır.
class FaqView extends StatefulWidget {
  const FaqView({super.key});

  @override
  State<FaqView> createState() => _FaqViewState();
}

class _FaqViewState extends State<FaqView> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'faqSearch');
  String _query = '';

  /// Her FAQ maddesinin soru/cevap anahtar kökü. Soru: `<key>.q`, cevap:
  /// `<key>.a`. Yeni madde eklerken listeye kök eklemek ve `_tr`/`_en`'e iki
  /// anahtar yazmak yeterli (sonra translate_sync ile diğer diller).
  static const List<String> _faqEntryKeys = [
    'faq.entry.tsMode',
    'faq.entry.hlsMode',
    'faq.entry.autoTs',
    'faq.entry.buffer',
    'faq.entry.freezing',
    'faq.entry.playbackStops',
    'faq.entry.engine',
    'faq.entry.softwareDecoder',
    'faq.entry.lowEndMode',
    'faq.entry.userAgent',
    'faq.entry.cardSize',
    'faq.entry.epg',
    'faq.entry.ignoreSsl',
    'faq.entry.multiPlaylist',
    'faq.entry.backup',
    // Oynatma & içerik özellikleri
    'faq.entry.catchUp',
    'faq.entry.resumeAutoplay',
    'faq.entry.smartCutter',
    'faq.entry.subtitles',
    'faq.entry.audioTrack',
    'faq.entry.volumeBoost',
    'faq.entry.equalizer',
    'faq.entry.externalPlayer',
    'faq.entry.cast',
    'faq.entry.pipBackground',
    'faq.entry.playbackSpeed',
    'faq.entry.zoomFit',
    'faq.entry.channelNumber',
    // Keşif & ana ekran
    'faq.entry.favorites',
    'faq.entry.continueWatching',
    'faq.entry.aiRecommend',
    'faq.entry.globalSearch',
    'faq.entry.downloads',
    'faq.entry.homeLayout',
    'faq.entry.filmDiziMode',
    'faq.entry.theme',
    'faq.entry.analytics',
    // Yönetim & destek
    'faq.entry.profiles',
    'faq.entry.parental',
    'faq.entry.sleepTimer',
    'faq.entry.channelEdit',
    'faq.entry.epgSettings',
    'faq.entry.speedTest',
    'faq.entry.cloudSync',
    'faq.entry.demoPlaylist',
    'faq.entry.chatSupport',
    'faq.entry.language',
    // Yeni özellikler
    'faq.entry.showcaseMode',
    'faq.entry.latestAdded',
    'faq.entry.imageSubtitles',
    'faq.entry.minaWrapper',
    'faq.entry.onlineCount',
    'faq.entry.os27Theme',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<String> get _filteredKeys {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _faqEntryKeys;
    return _faqEntryKeys.where((k) {
      final question = '$k.q'.tr.toLowerCase();
      final answer = '$k.a'.tr.toLowerCase();
      return question.contains(q) || answer.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final keys = _filteredKeys;
    final tvDpad =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(context, 'faq.title'.tr),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: _SearchField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _query = v),
                    primary: primary,
                  ),
                ),
                Expanded(
                  child: TvSettingsDpadScope(
                    enabled: tvDpad,
                    child: keys.isEmpty
                        ? _EmptyState()
                        : ListView.separated(
                            physics: AppScrollPhysics.list(),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: keys.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final key = keys[i];
                              return _FaqTile(
                                tvDpadIndex: i,
                                question: '$key.q'.tr,
                                answer: '$key.a'.tr,
                                primary: primary,
                              );
                            },
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.primary,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: primary,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'faq.searchHint'.tr,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'faq.empty'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({
    required this.tvDpadIndex,
    required this.question,
    required this.answer,
    required this.primary,
  });

  final int tvDpadIndex;

  final String question;
  final String answer;
  final Color primary;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return tvSettingsDpadWrap(
      context,
      index: widget.tvDpadIndex,
      onActivate: _toggle,
      borderRadius: 16,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        color: widget.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _expanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(30, 10, 4, 2),
                      child: Text(
                        widget.answer,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
