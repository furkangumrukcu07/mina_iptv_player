import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../ui/themed_settings_background.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  bool _isLoading = true;

  // Stats data
  int _totalCodes = 0;
  int _usedCodes = 0;
  int _totalUsers = 0;
  int _premiumUsers = 0;
  
  // Weekly chart data
  List<Map<String, dynamic>> _weeklyStats = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Fetch license codes using AggregateQuery for performance
      final totalCodesQuery = await db.collection('license_codes').count().get();
      final usedCodesQuery = await db.collection('license_codes').where('is_used', isEqualTo: true).count().get();
      
      _totalCodes = totalCodesQuery.count ?? 0;
      _usedCodes = usedCodesQuery.count ?? 0;

      // 2. Fetch User & Premium counts (using AggregateQuery)
      final totalQuery = await db.collection('user_licenses').count().get();
      final premiumQuery = await db.collection('user_licenses').where('isPremium', isEqualTo: true).count().get();
      
      _totalUsers = totalQuery.count ?? 0;
      _premiumUsers = premiumQuery.count ?? 0;

      // 3. Fetch last 7 days of admin_stats
      final statsQuery = await db
          .collection('admin_stats')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(7)
          .get();
          
      // Populate last 7 days, even if some are missing in DB
      final now = DateTime.now();
      _weeklyStats = [];
      
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(d);
        final label = DateFormat('E', 'tr_TR').format(d); // e.g. Pzt, Sal, Çar

        
        final doc = statsQuery.docs.firstWhereOrNull((doc) => doc.id == dateStr);
        final data = doc?.data();
        
        _weeklyStats.add({
          'date': dateStr,
          'label': label,
          'opens': (data?['opens'] as num?)?.toInt() ?? 0,
          'new_users': (data?['new_users'] as num?)?.toInt() ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AdminDashboard] error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemedSettingsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Gelişmiş İstatistikler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
        : RefreshIndicator(
            onRefresh: _fetchStats,
            color: Colors.cyanAccent,
            backgroundColor: const Color(0xFF1E293B),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900), // Responsive max width
                  child: Column(
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      _buildWeeklyLineChart(),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            // Geniş ekran: Yanyana iki grafik
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildPremiumConversionChart()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildLicenseUsageChart()),
                              ],
                            );
                          } else {
                            // Mobil ekran: Alt alta
                            return Column(
                              children: [
                                _buildPremiumConversionChart(),
                                const SizedBox(height: 16),
                                _buildLicenseUsageChart(),
                              ],
                            );
                          }
                        }
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_weeklyStats.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('Veri bulunamadı veya yüklenemedi. (İnternet veya yetki sorunu olabilir)', style: TextStyle(color: Colors.white70))),
      );
    }
    
    final todayOpens = _weeklyStats.last['opens'] as int;
    final todayNewUsers = _weeklyStats.last['new_users'] as int;

    return Row(
      children: [
        Expanded(child: _StatCard(title: 'Günlük Açılış', value: '$todayOpens', icon: Icons.rocket_launch, color: Colors.blueAccent)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(title: 'Yeni (Bugün)', value: '$todayNewUsers', icon: Icons.person_add, color: Colors.greenAccent)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(title: 'Toplam Kullanıcı', value: '$_totalUsers', icon: Icons.people, color: Colors.purpleAccent)),
      ],
    );
  }

  Widget _buildWeeklyLineChart() {
    return _GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Son 7 Günün Etkileşimi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Row(
            children: [
               _LegendDot(color: Colors.cyanAccent, label: 'Günlük Açılış'),
               SizedBox(width: 16),
               _LegendDot(color: Colors.pinkAccent, label: 'Yeni Kullanıcı'),
            ],
          ),
          const SizedBox(height: 24),
          if (_weeklyStats.isEmpty)
             const SizedBox(
               height: 250,
               child: Center(child: Text('Grafik verisi yok', style: TextStyle(color: Colors.white70))),
             )
          else
            SizedBox(
            height: 250,
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.blueGrey.withValues(alpha: 0.8),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.1), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, _) => Text('${val.toInt()}', style: const TextStyle(color: Colors.white54, fontSize: 12)))),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= _weeklyStats.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_weeklyStats[idx]['label'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        );
                      }
                    )
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(_weeklyStats.length, (i) => FlSpot(i.toDouble(), (_weeklyStats[i]['opens'] as int).toDouble())),
                    isCurved: true,
                    color: Colors.cyanAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.cyanAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(_weeklyStats.length, (i) => FlSpot(i.toDouble(), (_weeklyStats[i]['new_users'] as int).toDouble())),
                    isCurved: true,
                    color: Colors.pinkAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumConversionChart() {
    final freeUsers = _totalUsers - _premiumUsers;
    
    return _GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kullanıcı Dönüşümü', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: _totalUsers == 0 
            ? const Center(child: Text('Veri yok.', style: TextStyle(color: Colors.white54)))
            : PieChart(
              swapAnimationDuration: Duration.zero,
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: Colors.orangeAccent,
                    value: _premiumUsers.toDouble(),
                    title: '$_premiumUsers',
                    radius: 45,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.grey.shade400,
                    value: freeUsers.toDouble(),
                    title: '$freeUsers',
                    radius: 35,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.orangeAccent, label: 'Premium'),
              SizedBox(width: 16),
              _LegendDot(color: Colors.grey, label: 'Ücretsiz'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLicenseUsageChart() {
    final unusedCodes = _totalCodes - _usedCodes;
    
    return _GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lisans Kodları', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: _totalCodes == 0 
            ? const Center(child: Text('Lisans verisi yok.', style: TextStyle(color: Colors.white54)))
            : PieChart(
              swapAnimationDuration: Duration.zero,
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: Colors.greenAccent,
                    value: unusedCodes.toDouble(),
                    title: '$unusedCodes',
                    radius: 40,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  PieChartSectionData(
                    color: Colors.redAccent,
                    value: _usedCodes.toDouble(),
                    title: '$_usedCodes',
                    radius: 45,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.greenAccent, label: 'Boşta'),
              SizedBox(width: 16),
              _LegendDot(color: Colors.redAccent, label: 'Kullanılmış'),
            ],
          )
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassContainer({required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
