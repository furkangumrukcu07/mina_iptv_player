import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/haptics/adaptive_haptics_service.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../ui/tv_dpad_focus.dart';

/// Film & Dizi «tümünü gör» — sağ kenar A–Z hızlı kaydırma (çerçevesiz).
class FilmDiziAzIndexBar extends StatefulWidget {
  const FilmDiziAzIndexBar({
    super.key,
    required this.scrollController,
    required this.firstIndexByLetter,
    required this.crossAxisCount,
    required this.rowExtent,
  });

  final ScrollController scrollController;
  final Map<String, int> firstIndexByLetter;
  final int crossAxisCount;
  final double rowExtent;

  static const String letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#';

  @override
  State<FilmDiziAzIndexBar> createState() => _FilmDiziAzIndexBarState();
}

class _FilmDiziAzIndexBarState extends State<FilmDiziAzIndexBar> {
  String? _activeLetter;
  double? _dragY;
  int _tvLetterIdx = 0;

  void _clearActive() {
    setState(() {
      _activeLetter = null;
      _dragY = null;
    });
  }

  void _jumpToLetter(String letter) {
    final index = widget.firstIndexByLetter[letter];
    if (index == null) return;
    if (!widget.scrollController.hasClients) return;
    final row = index ~/ widget.crossAxisCount;
    final target = row * widget.rowExtent;
    final max = widget.scrollController.position.maxScrollExtent;
    widget.scrollController.jumpTo(target.clamp(0.0, max));
    if (Get.isRegistered<AdaptiveHapticsService>()) {
      Get.find<AdaptiveHapticsService>().selection();
    }
  }

  void _handleDrag(double localY, double height) {
    if (height <= 0) return;
    final letters = FilmDiziAzIndexBar.letters;
    final idx =
        (localY / height * letters.length).floor().clamp(0, letters.length - 1);
    final letter = letters[idx];
    final changed = _activeLetter != letter;
    setState(() {
      _activeLetter = letter;
      _dragY = localY;
    });
    if (changed) _jumpToLetter(letter);
  }

  void _tvMoveLetter(int delta) {
    final letters = FilmDiziAzIndexBar.letters;
    var idx = _tvLetterIdx;
    for (var step = 0; step < letters.length; step++) {
      idx = (idx + delta).clamp(0, letters.length - 1);
      final letter = letters[idx];
      if (widget.firstIndexByLetter.containsKey(letter)) {
        setState(() {
          _tvLetterIdx = idx;
          _activeLetter = letter;
        });
        _jumpToLetter(letter);
        return;
      }
      if (idx == 0 && delta < 0) break;
      if (idx == letters.length - 1 && delta > 0) break;
    }
  }

  Widget _letterColumn(double height, {required bool tvHighlight}) {
    final letters = FilmDiziAzIndexBar.letters;
    return SizedBox(
      width: tvHighlight ? 26 : 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < letters.length; i++)
            Text(
              letters[i],
              style: TextStyle(
                fontSize: 9,
                fontWeight: (tvHighlight && _tvLetterIdx == i) ||
                        _activeLetter == letters[i]
                    ? FontWeight.w800
                    : FontWeight.w600,
                height: 1,
                color: widget.firstIndexByLetter.containsKey(letters[i])
                    ? Colors.white.withValues(
                        alpha: (tvHighlight && _tvLetterIdx == i) ||
                                _activeLetter == letters[i]
                            ? 0.95
                            : 0.55,
                      )
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final letters = FilmDiziAzIndexBar.letters;
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final bubbleTop = _dragY != null
            ? (_dragY! - 22).clamp(4.0, height - 48.0)
            : null;

        final indexChild = remote
            ? TvDpadFocus(
                borderRadius: 6,
                scaleOnFocus: 1.0,
                onKeyEvent: (event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                    return KeyEventResult.ignored;
                  }
                  if (event is KeyRepeatEvent) {
                    return KeyEventResult.handled;
                  }
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.arrowUp) {
                    _tvMoveLetter(-1);
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.arrowDown) {
                    _tvMoveLetter(1);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                onActivate: () {
                  final letter = letters[_tvLetterIdx];
                  if (widget.firstIndexByLetter.containsKey(letter)) {
                    _jumpToLetter(letter);
                  }
                },
                child: _letterColumn(height, tvHighlight: true),
              )
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (d) =>
                    _handleDrag(d.localPosition.dy, height),
                onVerticalDragUpdate: (d) =>
                    _handleDrag(d.localPosition.dy, height),
                onTapDown: (d) => _handleDrag(d.localPosition.dy, height),
                onTapUp: (_) => _clearActive(),
                onVerticalDragEnd: (_) => _clearActive(),
                onVerticalDragCancel: () => _clearActive(),
                child: _letterColumn(height, tvHighlight: false),
              );

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            if (_activeLetter != null && bubbleTop != null)
              Positioned(
                right: 26,
                top: bubbleTop,
                child: _AzLetterBubble(letter: _activeLetter!),
              ),
            indexChild,
          ],
        );
      },
    );
  }
}

class _AzLetterBubble extends StatelessWidget {
  const _AzLetterBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.94),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Text(
          letter,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Başlık için A–Z indeks harfi (Türkçe harfler Latin karşılığına eşlenir).
String filmDiziAzIndexLetter(String sortKey) {
  final k = sortKey.trim();
  if (k.isEmpty) return '#';
  var c = k[0].toUpperCase();
  const trMap = {
    'Ç': 'C',
    'Ğ': 'G',
    'İ': 'I',
    'Ö': 'O',
    'Ş': 'S',
    'Ü': 'U',
  };
  c = trMap[c] ?? c;
  final code = c.codeUnitAt(0);
  if (code >= 0x41 && code <= 0x5A) return c;
  return '#';
}

Map<String, int> filmDiziBuildFirstIndexByLetter(List<String> sortKeys) {
  final map = <String, int>{};
  for (var i = 0; i < sortKeys.length; i++) {
    final letter = filmDiziAzIndexLetter(sortKeys[i]);
    map.putIfAbsent(letter, () => i);
  }
  return map;
}
