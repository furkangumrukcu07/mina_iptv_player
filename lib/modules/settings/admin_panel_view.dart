import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../ui/themed_settings_background.dart';
import 'admin_online_users_view.dart';
import 'admin_announcements_view.dart';
import 'admin_global_settings_view.dart';
import 'admin_dashboard_view.dart';
import 'admin_support_manager_view.dart';
import 'admin_user_management_view.dart';
import 'admin_orders_view.dart';
import 'admin_user_activity_logs_view.dart';
import 'admin_analytics_view.dart';
import 'admin_notification_center_view.dart';
import 'admin_banner_view.dart';
import 'admin_crash_reports_view.dart';

class AdminPanelView extends StatefulWidget {
  const AdminPanelView({super.key});

  @override
  State<AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends State<AdminPanelView> {
  bool _isLoading = false;
  int _totalCodes = 0;
  int _usedCodes = 0;
  String _statusMessage = '';
  String? _fetchedCode;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'İstatistikler yükleniyor...';
    });

    try {
      final totalQuery = await FirebaseFirestore.instance.collection('license_codes').count().get();
      final usedQuery = await FirebaseFirestore.instance.collection('license_codes').where('is_used', isEqualTo: true).count().get();
      
      setState(() {
        _totalCodes = totalQuery.count ?? 0;
        _usedCodes = usedQuery.count ?? 0;
        _statusMessage = 'Yüklendi.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Hata: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

    Future<void> _fetchUnusedCode() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Kullanılmamış bir kod aranıyor...';
      _fetchedCode = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('license_codes')
          .where('is_used', isEqualTo: false)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        final code = snapshot.docs.first.data()['code'] as String?;
        setState(() {
          _fetchedCode = code;
          _statusMessage = '🎉 Kod başarıyla getirildi!';
        });
      } else {
        setState(() {
          _statusMessage = 'Kullanılmamış kod kalmadı! Lütfen yeni kod üretin.';
          _fetchedCode = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Hata oluştu. Firebase kurallarınızı kontrol edin: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Admin Paneli',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(builder: (context) {
                            final user = FirebaseAuth.instance.currentUser;
                            final photoUrl = user?.photoURL;
                            
                            return Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                image: photoUrl != null 
                                  ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                                  : null,
                                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 3),
                              ),
                              child: photoUrl == null 
                                ? const Icon(Icons.admin_panel_settings, size: 64, color: Colors.blueAccent)
                                : null,
                            );
                          }),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatCard('Üretilen', _totalCodes.toString(), Colors.blueAccent),
                              _buildStatCard('Kullanılan', _usedCodes.toString(), Colors.redAccent),
                              _buildStatCard('Kalan', (_totalCodes - _usedCodes).toString(), Colors.greenAccent),
                            ],
                          ),
                          const SizedBox(height: 40),
                          if (_isLoading)
                            const CircularProgressIndicator()
                          else
                            GridView(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.1,
                              ),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildGridCard(
                                  title: 'Hareket Dökümleri',
                                  icon: Icons.history_rounded,
                                  color: Colors.blueGrey,
                                  onTap: () => Get.to(() => const AdminUserActivityLogsView()),
                                ),
                                _buildGridCard(
                                  title: 'Satın Alımlar',
                                  icon: Icons.shopping_cart_rounded,
                                  color: const Color(0xFFF59E0B),
                                  onTap: () => Get.to(() => const AdminOrdersView()),
                                ),
                                _buildGridCard(
                                  title: 'Kullanıcı Yönetimi',
                                  icon: Icons.manage_accounts_rounded,
                                  color: Colors.blueAccent,
                                  onTap: () => Get.to(() => const AdminUserManagementView()),
                                ),
                                _buildGridCard(
                                  title: 'Sistem Ayarları',
                                  icon: Icons.settings_applications,
                                  color: Colors.tealAccent,
                                  onTap: () => Get.to(() => const AdminGlobalSettingsView()),
                                ),
                                _buildGridCard(
                                  title: 'Hata Raporları',
                                  icon: Icons.bug_report,
                                  color: Colors.redAccent,
                                  onTap: () => Get.to(() => const AdminCrashReportsView()),
                                ),

                                _buildGridCard(
                                  title: 'Kullanılmamış Kod',
                                  icon: Icons.download_rounded,
                                  color: Colors.greenAccent,
                                  onTap: _fetchUnusedCode,
                                ),
                                _buildGridCard(
                                  title: 'Çevrimiçi Üyeler',
                                  icon: Icons.people_alt_rounded,
                                  color: Colors.purpleAccent,
                                  onTap: () => Get.to(() => const AdminOnlineUsersView()),
                                ),
                                _buildGridCard(
                                  title: 'Duyurular',
                                  icon: Icons.campaign_rounded,
                                  color: Colors.orangeAccent,
                                  onTap: () => Get.to(() => const AdminAnnouncementsView()),
                                ),
                                _buildGridCard(
                                  title: 'İstatistikler',
                                  icon: Icons.analytics_rounded,
                                  color: Colors.tealAccent,
                                  onTap: () => Get.to(() => const AdminDashboardView()),
                                ),
                                _buildGridCard(
                                  title: 'Destek Talepleri',
                                  icon: Icons.support_agent_rounded,
                                  color: Colors.indigoAccent,
                                  onTap: () => Get.to(() => const AdminSupportManagerView()),
                                ),
                                _buildGridCard(
                                  title: 'Analitik',
                                  icon: Icons.bar_chart_rounded,
                                  color: Colors.cyanAccent,
                                  onTap: () => Get.to(() => const AdminAnalyticsView()),
                                ),
                                _buildGridCard(
                                  title: 'Bildirim Merkezi',
                                  icon: Icons.notifications_rounded,
                                  color: Colors.deepPurpleAccent,
                                  onTap: () => Get.to(() => const AdminNotificationCenterView()),
                                ),
                                _buildGridCard(
                                  title: 'Banner Yönetimi',
                                  icon: Icons.view_carousel_rounded,
                                  color: Colors.pinkAccent,
                                  onTap: () => Get.to(() => const AdminBannerView()),
                                ),
                              ],
                            ),
                          if (_fetchedCode != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Kullanılabilir Kod',
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _fetchedCode!,
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, color: Colors.greenAccent),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: _fetchedCode!));
                                          Get.snackbar('Başarılı', 'Kod kopyalandı!', backgroundColor: Colors.green, colorText: Colors.white);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_statusMessage.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
