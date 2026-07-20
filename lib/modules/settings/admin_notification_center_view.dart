import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';
import '../../ui/themed_settings_background.dart';

class AdminNotificationCenterView extends StatefulWidget {
  const AdminNotificationCenterView({super.key});

  @override
  State<AdminNotificationCenterView> createState() =>
      _AdminNotificationCenterViewState();
}

class _AdminNotificationCenterViewState
    extends State<AdminNotificationCenterView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Quick Send
  final _quickTitleCtrl = TextEditingController();
  final _quickBodyCtrl = TextEditingController();
  String _quickSegment = 'all';
  bool _quickLoading = false;

  // Schedule
  final _schTitleCtrl = TextEditingController();
  final _schBodyCtrl = TextEditingController();
  String _schSegment = 'all';
  DateTime? _scheduledAt;
  bool _schLoading = false;

  static const _segments = [
    _Segment('all', 'Tümü', Color(0xFF6366F1)),
    _Segment('premium', 'Premium', Color(0xFFF59E0B)),
    _Segment('trial', 'Trial', Color(0xFF10B981)),
    _Segment('tv', 'TV', Color(0xFF3B82F6)),
    _Segment('mobile', 'Mobil', Color(0xFFEC4899)),
  ];

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickTitleCtrl.dispose();
    _quickBodyCtrl.dispose();
    _schTitleCtrl.dispose();
    _schBodyCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, Map<String, String>>> _translateNotification(String title, String body) async {
    final translator = GoogleTranslator();
    final supportedLangs = ['tr', 'en', 'de', 'es', 'fr', 'ar', 'nl', 'ru', 'it', 'pt'];
    final Map<String, Map<String, String>> translations = {};

    for (final lang in supportedLangs) {
      if (lang == 'tr') {
        translations[lang] = {'title': title, 'body': body};
        continue;
      }
      try {
        final tTitle = await translator.translate(title, from: 'tr', to: lang);
        final tBody = await translator.translate(body, from: 'tr', to: lang);
        translations[lang] = {'title': tTitle.text, 'body': tBody.text};
      } catch (e) {
        debugPrint('Çeviri hatası ($lang): $e');
        translations[lang] = {'title': title, 'body': body};
      }
    }
    return translations;
  }

  Future<void> _sendQuick() async {
    if (_quickTitleCtrl.text.trim().isEmpty ||
        _quickBodyCtrl.text.trim().isEmpty) {
      Get.snackbar('Uyarı', 'Başlık ve içerik zorunludur.',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    setState(() => _quickLoading = true);
    try {
      final title = _quickTitleCtrl.text.trim();
      final body = _quickBodyCtrl.text.trim();
      final translations = await _translateNotification(title, body);

      await _functions
          .httpsCallable('adminSendSegmentedNotification')
          .call({
        'segment': _quickSegment,
        'title': title,
        'body': body,
        'translations': translations,
      });
      _quickTitleCtrl.clear();
      _quickBodyCtrl.clear();
      Get.snackbar('Başarılı', 'Bildirim diller arası çevrilip gönderildi!',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Hata', 'Gönderilemedi: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _quickLoading = false);
    }
  }

  Future<void> _scheduleNotification() async {
    if (_schTitleCtrl.text.trim().isEmpty ||
        _schBodyCtrl.text.trim().isEmpty ||
        _scheduledAt == null) {
      Get.snackbar('Uyarı', 'Tüm alanları doldurun ve tarih seçin.',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    setState(() => _schLoading = true);
    try {
      final title = _schTitleCtrl.text.trim();
      final body = _schBodyCtrl.text.trim();
      final translations = await _translateNotification(title, body);

      await _functions.httpsCallable('adminScheduleNotification').call({
        'title': title,
        'body': body,
        'segment': _schSegment,
        'scheduledAtMs': _scheduledAt!.millisecondsSinceEpoch,
        'translations': translations,
      });
      _schTitleCtrl.clear();
      _schBodyCtrl.clear();
      setState(() => _scheduledAt = null);
      Get.snackbar('Başarılı', 'Bildirim diller arası çevrilip zamanlandı!',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Hata', 'Zamanlanamadı: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _schLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Bildirim Merkezi',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Hızlı Gönder', icon: Icon(Icons.send_rounded, size: 18)),
            Tab(text: 'Zamanla', icon: Icon(Icons.schedule_rounded, size: 18)),
            Tab(text: 'Geçmiş', icon: Icon(Icons.history_rounded, size: 18)),
          ],
        ),
      ),
      body: ThemedSettingsBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildQuickSendTab(),
            _buildScheduleTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.flash_on_rounded, 'Hızlı Bildirim Gönder',
                    const Color(0xFF6366F1)),
                const SizedBox(height: 20),
                _darkTextField(
                  controller: _quickTitleCtrl,
                  label: 'Bildirim Başlığı',
                  hint: 'Örn: Yeni özellik yayında!',
                  icon: Icons.title_rounded,
                ),
                const SizedBox(height: 14),
                _darkTextField(
                  controller: _quickBodyCtrl,
                  label: 'Bildirim İçeriği',
                  hint: 'Kullanıcılara gösterilecek mesaj...',
                  icon: Icons.message_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                const Text('Hedef Segment',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 10),
                _buildSegmentChips(
                  selected: _quickSegment,
                  onSelected: (s) => setState(() => _quickSegment = s),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _gradientButton(
                    label: 'Bildirimi Gönder',
                    icon: Icons.send_rounded,
                    loading: _quickLoading,
                    onTap: _sendQuick,
                    gradient: const LinearGradient(colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.schedule_rounded, 'Zamanlanmış Bildirim',
                    const Color(0xFF10B981)),
                const SizedBox(height: 20),
                _darkTextField(
                  controller: _schTitleCtrl,
                  label: 'Bildirim Başlığı',
                  hint: 'Başlık girin...',
                  icon: Icons.title_rounded,
                ),
                const SizedBox(height: 14),
                _darkTextField(
                  controller: _schBodyCtrl,
                  label: 'Bildirim İçeriği',
                  hint: 'Mesaj içeriği...',
                  icon: Icons.message_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                const Text('Hedef Segment',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 10),
                _buildSegmentChips(
                  selected: _schSegment,
                  onSelected: (s) => setState(() => _schSegment = s),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _scheduledAt != null
                            ? const Color(0xFF10B981)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: _scheduledAt != null
                              ? const Color(0xFF10B981)
                              : Colors.white38,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _scheduledAt != null
                                ? DateFormat('dd.MM.yyyy HH:mm')
                                    .format(_scheduledAt!)
                                : 'Tarih ve saat seçin',
                            style: TextStyle(
                              color: _scheduledAt != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _gradientButton(
                    label: 'Bildirimi Zamanla',
                    icon: Icons.alarm_add_rounded,
                    loading: _schLoading,
                    onTap: _scheduleNotification,
                    gradient: const LinearGradient(colors: [
                      Color(0xFF10B981),
                      Color(0xFF059669),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notification_history')
          .orderBy('sentAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Hata: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_rounded,
                    size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text('Bildirim geçmişi boş',
                    style: TextStyle(color: Colors.white38, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildHistoryCard(data);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Başlıksız';
    final type = data['type'] as String? ?? 'unknown';
    final segment = data['segment'] as String? ?? 'all';
    final sentAt = data['sentAt'];
    String sentStr = 'Bilinmiyor';
    if (sentAt != null) {
      try {
        DateTime dt;
        if (sentAt is Timestamp) {
          dt = sentAt.toDate();
        } else if (sentAt is int) {
          dt = DateTime.fromMillisecondsSinceEpoch(sentAt);
        } else {
          dt = DateTime.parse(sentAt.toString());
        }
        sentStr = DateFormat('dd.MM.yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    switch (type) {
      case 'segmented':
        typeColor = const Color(0xFF6366F1);
        typeIcon = Icons.group_rounded;
        typeLabel = 'Segmentli';
        break;
      case 'scheduled':
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.schedule_rounded;
        typeLabel = 'Zamanlanmış';
        break;
      case 'user':
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.person_rounded;
        typeLabel = 'Kişisel';
        break;
      default:
        typeColor = Colors.white38;
        typeIcon = Icons.notifications_rounded;
        typeLabel = type;
    }

    final seg = _segments.firstWhere(
      (s) => s.key == segment,
      orElse: () => const _Segment('all', 'Tümü', Color(0xFF6366F1)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 13, color: typeColor),
                    const SizedBox(width: 5),
                    Text(typeLabel,
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: seg.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(seg.label,
                    style: TextStyle(
                        color: seg.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(sentStr,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          if (data['body'] != null && (data['body'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(data['body'] as String,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentChips(
      {required String selected, required ValueChanged<String> onSelected}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _segments.map((seg) {
        final isSelected = selected == seg.key;
        return GestureDetector(
          onTap: () => onSelected(seg.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? seg.color.withOpacity(0.25)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected ? seg.color : Colors.white12, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: seg.color),
                  const SizedBox(width: 5),
                ],
                Text(seg.label,
                    style: TextStyle(
                        color: isSelected ? seg.color : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: const Color(0xFF0F172A).withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback onTap,
    required LinearGradient gradient,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: loading ? null : gradient,
          color: loading ? Colors.white12 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white70),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Segment {
  final String key;
  final String label;
  final Color color;
  const _Segment(this.key, this.label, this.color);
}
