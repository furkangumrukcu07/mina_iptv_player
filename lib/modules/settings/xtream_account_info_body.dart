import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../ui/glass_overlays.dart';

/// Ayarlar > Xtream Hesabı dialog gövdesi.
///
/// Xtream sunucusunun döndürdüğü tüm `user_info` + `server_info` alanlarını
/// görsel olarak gruplandırıp gösterir: üstte hesap özeti (kullanıcı + durum
/// rozeti), ardından öne çıkan istatistik çipleri (kalan gün, bağlantı, deneme)
/// ve son olarak ikonlu detay kartları (abonelik + sunucu). Şifre varsayılan
/// olarak maskelidir, göz ikonu ile açılır.
class XtreamAccountInfoBody extends StatefulWidget {
  const XtreamAccountInfoBody({
    super.key,
    required this.source,
    required this.user,
    required this.server,
  });

  final XtreamSource source;
  final UserInfo? user;
  final XtreamServerInfo? server;

  @override
  State<XtreamAccountInfoBody> createState() => _XtreamAccountInfoBodyState();
}

class _XtreamAccountInfoBodyState extends State<XtreamAccountInfoBody> {
  static const _ok = Color(0xFF6EE7B7);
  static const _warn = Color(0xFFFCD34D);
  static const _bad = Color(0xFFFCA5A5);

  bool _passwordVisible = false;

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  String _fmtDateTime(DateTime d) {
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '${_fmtDate(local)} $hh:$mi';
  }

  /// Kalan gün — bitmiş veya bilinmiyorsa null.
  String? _remainingDaysLabel(DateTime? exp) {
    if (exp == null) return null;
    final now = DateTime.now();
    final diff = exp.difference(now);
    if (diff.isNegative) {
      return 'xtream.info.expiredAgo'
          .trParams({'n': '${(-diff.inDays).clamp(0, 99999)}'});
    }
    return 'xtream.info.remainingDays'.trParams({'n': '${diff.inDays}'});
  }

  Color? _remainingColor(DateTime? exp) {
    final d = exp?.difference(DateTime.now());
    if (d == null) return null;
    if (d.isNegative) return _bad;
    if (d.inDays <= 7) return _warn;
    return _ok;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final server = widget.server;
    final primary = Theme.of(context).colorScheme.primary;

    final username = (user?.username.isNotEmpty ?? false)
        ? user!.username
        : widget.source.username;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroHeader(
            username: username,
            statusText: user == null
                ? 'xtream.info.unknown'.tr
                : (user.status.isEmpty
                    ? 'xtream.info.unknown'.tr
                    : user.status.toUpperCase()),
            statusColor: _statusColor(user?.status ?? ''),
            subtitle: user?.expiryDate == null
                ? 'settings.xtream.unlimited'.tr
                : _remainingDaysLabel(user!.expiryDate),
            subtitleColor: _remainingColor(user?.expiryDate),
            primary: primary,
          ),
          if (user != null) ...[
            const SizedBox(height: 12),
            _StatStrip(
              chips: [
                if (_remainingDaysLabel(user.expiryDate) != null)
                  _StatChipData(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'xtream.info.remaining'.tr,
                    value: _remainingDaysLabel(user.expiryDate)!,
                    color: _remainingColor(user.expiryDate),
                  )
                else
                  _StatChipData(
                    icon: Icons.all_inclusive_rounded,
                    label: 'settings.xtream.expiry'.tr,
                    value: 'settings.xtream.unlimited'.tr,
                    color: _ok,
                  ),
                _StatChipData(
                  icon: Icons.devices_rounded,
                  label: 'settings.xtream.connections'.tr,
                  value: '${user.activeConnections}/${user.maxConnections}',
                ),
                _StatChipData(
                  icon: user.isTrial
                      ? Icons.science_rounded
                      : Icons.workspace_premium_rounded,
                  label: 'settings.xtream.trial'.tr,
                  value: user.isTrial ? 'common.yes'.tr : 'common.no'.tr,
                  color: user.isTrial ? _warn : _ok,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _GroupCard(
            icon: Icons.workspace_premium_rounded,
            title: 'xtream.info.section.subscription'.tr,
            primary: primary,
            children: user != null
                ? [
                    _DetailRow(
                      icon: Icons.person_rounded,
                      label: 'settings.xtream.user'.tr,
                      value: username,
                      copyable: true,
                    ),
                    _PasswordRow(
                      label: 'xtream.info.password'.tr,
                      value: (user.password != null &&
                              user.password!.isNotEmpty)
                          ? user.password!
                          : widget.source.password,
                      visible: _passwordVisible,
                      onToggle: () => setState(
                        () => _passwordVisible = !_passwordVisible,
                      ),
                    ),
                    _DetailRow(
                      icon: Icons.verified_user_rounded,
                      label: 'xtream.info.authState'.tr,
                      value: user.auth == 1
                          ? 'xtream.info.authOk'.tr
                          : (user.auth == 0
                              ? 'xtream.info.authFail'.tr
                              : 'xtream.info.unknown'.tr),
                      valueColor: user.auth == 1
                          ? _ok
                          : user.auth == 0
                              ? _bad
                              : null,
                    ),
                    if (user.message != null && user.message!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.campaign_rounded,
                        label: 'xtream.info.message'.tr,
                        value: user.message!,
                      ),
                    if (user.createdAt != null)
                      _DetailRow(
                        icon: Icons.event_available_rounded,
                        label: 'xtream.info.createdAt'.tr,
                        value: _fmtDate(user.createdAt!.toLocal()),
                      ),
                    _DetailRow(
                      icon: Icons.event_busy_rounded,
                      label: 'settings.xtream.expiry'.tr,
                      value: user.expiryDate == null
                          ? 'settings.xtream.unlimited'.tr
                          : _fmtDate(user.expiryDate!.toLocal()),
                    ),
                    if (user.allowedOutputFormats.isNotEmpty)
                      _DetailRow(
                        icon: Icons.high_quality_rounded,
                        label: 'xtream.info.allowedOutputs'.tr,
                        value: user.allowedOutputFormats
                            .join(', ')
                            .toUpperCase(),
                      ),
                  ]
                : [
                    _DetailRow(
                      icon: Icons.info_outline_rounded,
                      label: 'xtream.info.userInfoMissing'.tr,
                      value: '—',
                    ),
                  ],
          ),
          const SizedBox(height: 12),
          _GroupCard(
            icon: Icons.dns_rounded,
            title: 'xtream.info.section.server'.tr,
            primary: primary,
            children: [
              _DetailRow(
                icon: Icons.link_rounded,
                label: 'xtream.info.serverBaseUrl'.tr,
                value: widget.source.baseUrl,
                copyable: true,
              ),
              if (server != null && !server.isEmpty) ...[
                if (server.url != null && server.url!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.dns_rounded,
                    label: 'xtream.info.serverHost'.tr,
                    value: server.url!,
                    copyable: true,
                  ),
                if (server.serverProtocol != null &&
                    server.serverProtocol!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.security_rounded,
                    label: 'xtream.info.serverProtocol'.tr,
                    value: server.serverProtocol!.toUpperCase(),
                  ),
                if (server.port != null && server.port!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.settings_ethernet_rounded,
                    label: 'xtream.info.serverPort'.tr,
                    value: server.port!,
                  ),
                if (server.httpsPort != null && server.httpsPort!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.lock_rounded,
                    label: 'xtream.info.serverHttpsPort'.tr,
                    value: server.httpsPort!,
                  ),
                if (server.rtmpPort != null && server.rtmpPort!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.cast_rounded,
                    label: 'xtream.info.serverRtmpPort'.tr,
                    value: server.rtmpPort!,
                  ),
                if (server.timezone != null && server.timezone!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.public_rounded,
                    label: 'xtream.info.timezone'.tr,
                    value: server.timezone!,
                  ),
                if (server.serverTimeLocalLabel != null &&
                    server.serverTimeLocalLabel!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'xtream.info.serverTime'.tr,
                    value: server.serverTimeLocalLabel!,
                  )
                else if (server.serverTimeUtc != null)
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'xtream.info.serverTime'.tr,
                    value: _fmtDateTime(server.serverTimeUtc!),
                  ),
                if (server.process != null)
                  _DetailRow(
                    icon: Icons.bolt_rounded,
                    label: 'xtream.info.serverProcess'.tr,
                    value: server.process!
                        ? 'common.active'.tr
                        : 'common.inactive'.tr,
                    valueColor: server.process! ? _ok : _bad,
                  ),
                if (server.revision != null && server.revision!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.tag_rounded,
                    label: 'xtream.info.serverRevision'.tr,
                    value: server.revision!,
                  ),
              ] else
                _DetailRow(
                  icon: Icons.info_outline_rounded,
                  label: 'xtream.info.serverInfoMissing'.tr,
                  value: '—',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color? _statusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'active') return _ok;
    if (s.contains('expir') || s.contains('disabled') || s.contains('banned')) {
      return _bad;
    }
    return null;
  }
}

/// Üst hesap özeti: avatar + kullanıcı adı + durum rozeti + kalan süre.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.username,
    required this.statusText,
    required this.statusColor,
    required this.subtitle,
    required this.subtitleColor,
    required this.primary,
  });

  final String username;
  final String statusText;
  final Color? statusColor;
  final String? subtitle;
  final Color? subtitleColor;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final initial =
        username.trim().isNotEmpty ? username.trim()[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.28),
            primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary.withValues(alpha: 0.85),
                  primary.withValues(alpha: 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatusPill(text: statusText, color: statusColor),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subtitleColor ??
                                Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: c,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChipData {
  const _StatChipData({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
}

/// Öne çıkan metrikler — eşit genişlikte yan yana çipler.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.chips});

  final List<_StatChipData> chips;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _StatChip(data: chips[i])),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.data});

  final _StatChipData data;

  @override
  Widget build(BuildContext context) {
    final c = data.color ?? Colors.white.withValues(alpha: 0.92);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 18, color: c),
          const SizedBox(height: 6),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlıklı (ikon + metin) cam kart — içine detay satırları gelir.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.icon,
    required this.title,
    required this.primary,
    required this.children,
  });

  final IconData icon;
  final String title;
  final Color primary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.20),
                    border: Border.all(color: primary.withValues(alpha: 0.45)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool copyable;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: value));
    GlassSnackbar.show(
      'common.copied'.tr,
      value.length > 64 ? '${value.substring(0, 64)}…' : value,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: valueColor ?? Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: Colors.white70,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'common.copy'.tr,
              onPressed: () => _copy(context),
            ),
        ],
      ),
    );
  }
}

class _PasswordRow extends StatelessWidget {
  const _PasswordRow({
    required this.label,
    required this.value,
    required this.visible,
    required this.onToggle,
  });

  final String label;
  final String value;
  final bool visible;
  final VoidCallback onToggle;

  String get _masked => '•' * value.length.clamp(6, 14);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.lock_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  visible ? value : _masked,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.95),
                    fontFamily: visible ? 'monospace' : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              visible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 16,
              color: Colors.white70,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: visible ? 'common.hide'.tr : 'common.show'.tr,
            onPressed: onToggle,
          ),
          IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: Colors.white70,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'common.copy'.tr,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              GlassSnackbar.show(
                'common.copied'.tr,
                '•' * value.length,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
          ),
        ],
      ),
    );
  }
}
