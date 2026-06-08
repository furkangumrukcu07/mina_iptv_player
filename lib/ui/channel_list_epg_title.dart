import 'package:flutter/material.dart';

import '../core/utils/epg_display_time.dart';

/// Kanal adı üstte; alt satırda EPG programı + başlangıç saati.
class ChannelListEpgTitleLine extends StatelessWidget {
  const ChannelListEpgTitleLine({
    super.key,
    required this.channelName,
    this.programmeTitle,
    this.programmeStart,
    required this.marqueeEnabled,
    required this.highlighted,
  });

  final String channelName;
  final String? programmeTitle;
  final DateTime? programmeStart;
  final bool marqueeEnabled;
  final bool highlighted;

  static String programmeLine(String? title, DateTime? start) {
    final t = title?.trim();
    if (t == null || t.isEmpty) return '';
    if (start == null) return t;
    return '$t ${formatEpgClock(start)}';
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = highlighted ? Colors.white : Colors.white70;
    final titleStyle = TextStyle(
      color: titleColor,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.12,
      letterSpacing: 0.15,
    );
    final progStyle = TextStyle(
      color: titleColor.withValues(alpha: 0.58),
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      height: 1.15,
    );
    final epgLine = programmeLine(programmeTitle, programmeStart);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          channelName,
          style: titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (epgLine.isNotEmpty) ...[
          const SizedBox(height: 2),
          _ProgrammeSubtitleLine(
            text: epgLine,
            style: progStyle,
            marqueeEnabled: marqueeEnabled,
          ),
        ],
      ],
    );
  }
}

/// Alt satır EPG: sığmazsa …; 2 sn sonra yavaş yatay kaydırma.
class _ProgrammeSubtitleLine extends StatelessWidget {
  const _ProgrammeSubtitleLine({
    required this.text,
    required this.style,
    required this.marqueeEnabled,
  });

  final String text;
  final TextStyle style;
  final bool marqueeEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (maxW <= 0) {
          return Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final direction = Directionality.of(context);
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: direction,
        )..layout(maxWidth: double.infinity);
        final textW = tp.width;
        final overflow = textW > maxW + 1;

        if (!overflow || !marqueeEnabled) {
          return Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return _SlowMarqueeText(
          text: text,
          style: style,
          textWidth: textW,
          viewportWidth: maxW,
        );
      },
    );
  }
}

class _SlowMarqueeText extends StatefulWidget {
  const _SlowMarqueeText({
    required this.text,
    required this.style,
    required this.textWidth,
    required this.viewportWidth,
  });

  final String text;
  final TextStyle style;
  final double textWidth;
  final double viewportWidth;

  @override
  State<_SlowMarqueeText> createState() => _SlowMarqueeTextState();
}

class _SlowMarqueeTextState extends State<_SlowMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _travel;

  @override
  void initState() {
    super.initState();
    _travel = (widget.textWidth - widget.viewportWidth).clamp(0.0, 2000.0);
    final ms = (_travel / 16 * 1000).round().clamp(12000, 90000);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final offset = -_controller.value * _travel;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
            ),
          );
        },
      ),
    );
  }
}
