import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../ui/themed_settings_background.dart';

class AdminAnalyticsView extends StatefulWidget {
  const AdminAnalyticsView({super.key});

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> {
  bool _loading = false;
  Map<String, dynamic>? _analytics;
  String? _error;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _functions
          .httpsCallable('adminGetAnalytics')
          .call<Map<String, dynamic>>();
      setState(() => _analytics = Map<String, dynamic>.from(result.data as Map));
    } catch (e) {
      setState(() => _error = e.toString());
      Get.snackbar('Hata', 'Analitik yüklenemedi: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Analitik Özeti',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadAnalytics,
            icon: AnimatedRotation(
              turns: _loading ? 1 : 0,
              duration: const Duration(seconds: 1),
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
            tooltip: 'Yenile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ThemedSettingsBackground(
        child: _loading && _analytics == null
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6366F1)),
                    SizedBox(height: 16),
                    Text('Analitik yükleniyor...',
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              )
            : _error != null && _analytics == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 56),
                        const SizedBox(height: 16),
                        const Text('Veri yüklenemedi',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          onPressed: _loadAnalytics,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                          label: const Text('Tekrar Dene',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : _buildDashboard(),
      ),
    );
  }

  Widget _buildDashboard() {
    final data = _analytics ?? {};

    final totalUsers = data['totalUsers'] ?? 0;
    final premiumUsers = data['premiumUsers'] ?? 0;
    final newPremium7 = data['newPremiumLast7Days'] ?? 0;
    final newUsers30 = data['newUsersLast30Days'] ?? 0;
    final activeBanners = data['activeBanners'] ?? 0;
    final recentNotifications = (data['recentNotifications'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdatedBadge(),
            const SizedBox(height: 20),
            _sectionLabel('📊 Genel İstatistikler'),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _buildStatCard(
                  label: 'Toplam Kullanıcı',
                  value: '$totalUsers',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF3B82F6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF1E40AF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                _buildStatCard(
                  label: 'Premium Kullanıcı',
                  value: '$premiumUsers',
                  icon: Icons.star_rounded,
                  color: const Color(0xFFF59E0B),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D2B00), Color(0xFF92400E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                _buildStatCard(
                  label: 'Son 7 Gün\nYeni Premium',
                  value: '$newPremium7',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF10B981),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                _buildStatCard(
                  label: 'Son 30 Gün\nYeni Kullanıcı',
                  value: '$newUsers30',
                  icon: Icons.person_add_rounded,
                  color: const Color(0xFFA855F7),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E1065), Color(0xFF4C1D95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildStatCard(
              label: 'Aktif Banner Sayısı',
              value: '$activeBanners',
              icon: Icons.view_carousel_rounded,
              color: const Color(0xFFF97316),
              gradient: const LinearGradient(
                colors: [Color(0xFF431407), Color(0xFF7C2D12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              fullWidth: true,
            ),
            const SizedBox(height: 28),
            if (recentNotifications.isNotEmpty) ...[
              _sectionLabel('🔔 Son 5 Bildirim'),
              const SizedBox(height: 14),
              ...recentNotifications.take(5).map((n) {
                final notif = n as Map<dynamic, dynamic>;
                final title = notif['title'] as String? ?? 'Başlıksız';
                final type = notif['type'] as String? ?? '';
                final sentAt = notif['sentAt'];
                String timeStr = '';
                if (sentAt != null) {
                  try {
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                        (sentAt as num).toInt());
                    timeStr = DateFormat('dd.MM.yyyy HH:mm').format(dt);
                  } catch (_) {}
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_rounded,
                            color: Color(0xFF6366F1), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            if (type.isNotEmpty)
                              Text(type,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(timeStr,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdatedBadge() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Güncellendi: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const Spacer(),
        if (_loading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF6366F1)),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: fullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            color: color,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    Icon(Icons.trending_up_rounded,
                        color: color.withOpacity(0.5), size: 16),
                  ],
                ),
                const Spacer(),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11),
                    maxLines: 2),
              ],
            ),
    );
  }
}
