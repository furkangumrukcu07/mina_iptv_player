import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/data_usage_service.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';

/// **Veri Kullanım Detayı sayfası.**
///
/// `DataUsageService`'in tutuğu lifetime sayaçlardan yola çıkarak
/// uygulamanın **mobil veri** ve **wifi** ile ne kadar internet
/// indirdiğini/yüklediğini analiz eder.
///
/// Düzen:
///
/// ```
/// [<-]  Veri Kullanım Detayı
/// ┌──────────────────── Toplam ────────────────────┐
/// │  Genel toplam · 12.34 GB                       │
/// │  ────────────────────────────────────────       │
/// │  ▓▓▓▓▓▓▓░░░░░░░░░  Wifi % 70  Mobil % 30        │
/// └──────────────────────────────────────────────────┘
/// ┌────── Wifi ──────┐  ┌────── Mobil ──────┐
/// │ İndirilen 5.20GB │  │ İndirilen 2.10GB  │
/// │ Gönderilen 1.15GB│  │ Gönderilen 0.45GB │
/// └─────────────────┘  └────────────────────┘
/// [Sıfırla]
/// ```
class DataUsageView extends StatelessWidget {
  const DataUsageView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<DataUsageService>();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'settings.dataUsage.title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Obx(() {
              // Tema rengi — Theme.of üzerinden, GlassAppearance ekstra
              // bir tema rengi getter'ı sunmuyor; settings_view.dart da
              // aynı yaklaşımı kullanıyor (`final primary = Theme.of...`).
              final themeColor = Theme.of(context).colorScheme.primary;
              final wifi = svc.totalWifi;
              final mobile = svc.totalMobile;
              final total = wifi + mobile;
              final isAndroid = Platform.isAndroid;
              return ListView(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                children: [
                  if (!isAndroid)
                    _UnsupportedBanner(themeColor: themeColor),
                  if (isAndroid && !svc.isAvailable.value)
                    _LoadingBanner(themeColor: themeColor),
                  _TotalCard(
                    total: total,
                    wifi: wifi,
                    mobile: mobile,
                    startedAtMs: svc.startedAtMs.value,
                    themeColor: themeColor,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ChannelCard(
                          icon: Icons.wifi_rounded,
                          label: 'settings.dataUsage.wifi'.tr,
                          rx: svc.wifiRxBytes.value,
                          tx: svc.wifiTxBytes.value,
                          color: const Color(0xFF4FC3F7),
                          isActive: svc.lastConnectivity.value ==
                                  ConnectivityResult.wifi ||
                              svc.lastConnectivity.value ==
                                  ConnectivityResult.ethernet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ChannelCard(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: 'settings.dataUsage.mobile'.tr,
                          rx: svc.mobileRxBytes.value,
                          tx: svc.mobileTxBytes.value,
                          color: const Color(0xFFFF9D6E),
                          isActive: svc.lastConnectivity.value ==
                              ConnectivityResult.mobile,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoNote(themeColor: themeColor),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: tvDpadActivateWrap(
                      context,
                      onActivate: () => _confirmReset(context, svc),
                      borderRadius: 8,
                      child: TextButton.icon(
                        onPressed: () => _confirmReset(context, svc),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                        ),
                        label: Text(
                          'settings.dataUsage.reset'.tr,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, DataUsageService svc) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: Text(
          'settings.dataUsage.resetConfirm.title'.tr,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'settings.dataUsage.resetConfirm.body'.tr,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('settings.dataUsage.reset'.tr),
          ),
        ],
      ),
    );
    if (ok == true) {
      await svc.resetAll();
    }
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.wifi,
    required this.mobile,
    required this.startedAtMs,
    required this.themeColor,
  });
  final int total;
  final int wifi;
  final int mobile;
  final int startedAtMs;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    final wifiPct = total == 0 ? 0.5 : wifi / total;
    final mobilePct = total == 0 ? 0.5 : mobile / total;
    final since = startedAtMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(startedAtMs)
        : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeColor.withValues(alpha: 0.18),
            themeColor.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          width: 0.6,
          color: Colors.white.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.dataUsage.totalLabel'.tr,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatBytes(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          if (since != null) ...[
            const SizedBox(height: 4),
            Text(
              'settings.dataUsage.startedAt'.trParams({
                'date':
                    '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}',
              }),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: math.max(1, (wifiPct * 1000).toInt()),
                    child: Container(color: const Color(0xFF4FC3F7)),
                  ),
                  Expanded(
                    flex: math.max(1, (mobilePct * 1000).toInt()),
                    child: Container(color: const Color(0xFFFF9D6E)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(
                color: const Color(0xFF4FC3F7),
                label:
                    '${'settings.dataUsage.wifi'.tr}  ·  %${(wifiPct * 100).round()}',
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: const Color(0xFFFF9D6E),
                label:
                    '${'settings.dataUsage.mobile'.tr}  ·  %${(mobilePct * 100).round()}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.icon,
    required this.label,
    required this.rx,
    required this.tx,
    required this.color,
    required this.isActive,
  });
  final IconData icon;
  final String label;
  final int rx;
  final int tx;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final total = rx + tx;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          width: 0.6,
          color: isActive
              ? color.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.12),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'settings.dataUsage.active'.tr,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatBytes(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _MetricRow(
            label: 'settings.dataUsage.rx'.tr,
            value: _formatBytes(rx),
            icon: Icons.south_rounded,
          ),
          const SizedBox(height: 4),
          _MetricRow(
            label: 'settings.dataUsage.tx'.tr,
            value: _formatBytes(tx),
            icon: Icons.north_rounded,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.themeColor});
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: themeColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'settings.dataUsage.note'.tr,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedBanner extends StatelessWidget {
  const _UnsupportedBanner({required this.themeColor});
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.30),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'settings.dataUsage.unsupported'.tr,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner({required this.themeColor});
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: themeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'settings.dataUsage.preparing'.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1.23 KB / 4.56 MB / 7.89 GB / 1.23 TB.
String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  if (i == 0) return '${v.toInt()} ${units[i]}';
  final str =
      v >= 100 ? v.toStringAsFixed(0) : (v >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2));
  return '$str ${units[i]}';
}
