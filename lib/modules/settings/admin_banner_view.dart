import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../ui/themed_settings_background.dart';

class AdminBannerView extends StatefulWidget {
  const AdminBannerView({super.key});

  @override
  State<AdminBannerView> createState() => _AdminBannerViewState();
}

class _AdminBannerViewState extends State<AdminBannerView> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  String _selectedColor = '#1E3A5F';
  DateTime? _expiresAt;
  bool _createLoading = false;

  static const _presetColors = [
    _BannerColor('#1E3A5F', 'Mavi', Color(0xFF1E3A5F)),
    _BannerColor('#2D1B69', 'Mor', Color(0xFF2D1B69)),
    _BannerColor('#1A3A2A', 'Yeşil', Color(0xFF1A3A2A)),
    _BannerColor('#3A1A1A', 'Kırmızı', Color(0xFF3A1A1A)),
    _BannerColor('#3A2A1A', 'Turuncu', Color(0xFF3A2A1A)),
  ];

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _createBanner() async {
    if (_titleCtrl.text.trim().isEmpty) {
      Get.snackbar('Uyarı', 'Banner başlığı zorunludur.',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    setState(() => _createLoading = true);
    try {
      final payload = <String, dynamic>{
        'action': 'create',
        'title': _titleCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim(),
        'bgColor': _selectedColor,
      };
      if (_expiresAt != null) {
        payload['expiresAtMs'] = _expiresAt!.millisecondsSinceEpoch;
      }
      await _functions.httpsCallable('adminManageBanner').call(payload);
      _titleCtrl.clear();
      _subtitleCtrl.clear();
      setState(() {
        _selectedColor = '#1E3A5F';
        _expiresAt = null;
      });
      Get.snackbar('Başarılı', 'Banner oluşturuldu!',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Hata', 'Banner oluşturulamadı: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _createLoading = false);
    }
  }

  Future<void> _toggleBanner(String bannerId) async {
    try {
      await _functions.httpsCallable('adminManageBanner').call({
        'action': 'toggle',
        'bannerId': bannerId,
      });
    } catch (e) {
      Get.snackbar('Hata', 'Toggle başarısız: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> _deleteBanner(String bannerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Banner Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bu banner\'ı silmek istediğinize emin misiniz?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Get.back(result: true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _functions.httpsCallable('adminManageBanner').call({
        'action': 'delete',
        'bannerId': bannerId,
      });
      Get.snackbar('Başarılı', 'Banner silindi.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Hata', 'Silinemedi: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> _pickExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
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
    if (date != null) setState(() => _expiresAt = date);
  }

  Color _hexToColor(String hex) {
    try {
      return Color(
          int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A5F);
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
          'Banner Yönetimi',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ThemedSettingsBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Create Section
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(Icons.add_box_rounded, 'Yeni Banner Oluştur',
                        const Color(0xFF6366F1)),
                    const SizedBox(height: 20),
                    _darkTextField(
                      controller: _titleCtrl,
                      label: 'Banner Başlığı *',
                      hint: 'Zorunlu alan',
                      icon: Icons.title_rounded,
                    ),
                    const SizedBox(height: 14),
                    _darkTextField(
                      controller: _subtitleCtrl,
                      label: 'Alt Başlık (opsiyonel)',
                      hint: 'Kısa açıklama...',
                      icon: Icons.subtitles_rounded,
                    ),
                    const SizedBox(height: 20),
                    const Text('Arka Plan Rengi',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: _presetColors.map((c) {
                        final isSelected = _selectedColor == c.hex;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = c.hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 10),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: c.color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white24,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: c.color.withOpacity(0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2)
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _presetColors.map((c) {
                        return SizedBox(
                          width: 56,
                          child: Text(c.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickExpiry,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _expiresAt != null
                                ? const Color(0xFF10B981)
                                : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_rounded,
                                color: _expiresAt != null
                                    ? const Color(0xFF10B981)
                                    : Colors.white38,
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _expiresAt != null
                                    ? 'Bitiş: ${DateFormat('dd.MM.yyyy').format(_expiresAt!)}'
                                    : 'Bitiş tarihi (opsiyonel)',
                                style: TextStyle(
                                    color: _expiresAt != null
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 14),
                              ),
                            ),
                            if (_expiresAt != null)
                              GestureDetector(
                                onTap: () => setState(() => _expiresAt = null),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white38, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _hexToColor(_selectedColor),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _hexToColor(_selectedColor)
                              .withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.preview_rounded,
                                  color: Colors.white38, size: 14),
                              const SizedBox(width: 6),
                              const Text('Önizleme',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _titleCtrl.text.isEmpty
                                ? 'Banner Başlığı'
                                : _titleCtrl.text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          if (_subtitleCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(_subtitleCtrl.text,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _gradientButton(
                        label: 'Banner Oluştur',
                        icon: Icons.add_rounded,
                        loading: _createLoading,
                        onTap: _createBanner,
                        gradient: const LinearGradient(colors: [
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Existing banners
              _sectionHeader(
                  Icons.view_carousel_rounded, 'Mevcut Bannerlar', const Color(0xFFF59E0B)),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('app_banners')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                          color: Color(0xFF6366F1)),
                    ));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Center(
                        child: Text('Henüz banner yok.',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14)),
                      ),
                    );
                  }
                  return Column(
                    children: docs
                        .map((doc) => _buildBannerCard(
                            doc.id, doc.data() as Map<String, dynamic>))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCard(String bannerId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Başlıksız';
    final subtitle = data['subtitle'] as String? ?? '';
    final isActive = data['isActive'] as bool? ?? true;
    final bgColorHex = data['bgColor'] as String? ?? '#1E3A5F';
    final borderColor = _hexToColor(bgColorHex);

    String createdStr = '';
    final createdAt = data['createdAt'];
    if (createdAt != null) {
      try {
        DateTime dt;
        if (createdAt is Timestamp) {
          dt = createdAt.toDate();
        } else {
          dt = DateTime.fromMillisecondsSinceEpoch(
              (createdAt as num).toInt());
        }
        createdStr = DateFormat('dd.MM.yyyy').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: borderColor.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.25),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(subtitle,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Aktif' : 'Pasif',
                    style: TextStyle(
                        color: isActive ? Colors.greenAccent : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                if (createdStr.isNotEmpty)
                  Text(createdStr,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aktif',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: isActive,
                      activeColor: Colors.green,
                      onChanged: (_) => _toggleBanner(bannerId),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteBanner(bannerId),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 22),
                      tooltip: 'Sil',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
      onChanged: (_) => setState(() {}),
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
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
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
                  ),
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

class _BannerColor {
  final String hex;
  final String name;
  final Color color;
  const _BannerColor(this.hex, this.name, this.color);
}
