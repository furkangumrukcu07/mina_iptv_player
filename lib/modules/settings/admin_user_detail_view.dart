import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../ui/themed_settings_background.dart';
import 'admin_glass_widgets.dart';

class AdminUserDetailView extends StatefulWidget {
  final String uid;
  final String email;

  const AdminUserDetailView({
    super.key,
    required this.uid,
    required this.email,
  });

  @override
  State<AdminUserDetailView> createState() => _AdminUserDetailViewState();
}

class _AdminUserDetailViewState extends State<AdminUserDetailView> {
  bool _loading = false;
  Map<String, dynamic>? _userData;
  String? _error;

  // Notification fields
  final _notifTitleCtrl = TextEditingController();
  final _notifBodyCtrl = TextEditingController();
  bool _notifLoading = false;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _functions
          .httpsCallable('adminGetUserDetail')
          .call<Map<String, dynamic>>({'targetUid': widget.uid});
      setState(
          () => _userData = Map<String, dynamic>.from(result.data as Map));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grantPremium() async {
    int selectedDays = 30;
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Premium Ver',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Süre Seçin',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButton<int>(
                  value: selectedDays,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 0, child: Text('Sınırsız (0 gün)')),
                    DropdownMenuItem(value: 7, child: Text('7 Gün')),
                    DropdownMenuItem(value: 30, child: Text('30 Gün')),
                    DropdownMenuItem(value: 90, child: Text('90 Gün')),
                    DropdownMenuItem(value: 365, child: Text('365 Gün')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedDays = v);
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  labelStyle: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFF59E0B), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('İptal',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Onayla',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Get.back(result: true),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      noteCtrl.dispose();
      return;
    }

    try {
      Get.dialog(
          const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
          barrierDismissible: false);
      await _functions.httpsCallable('adminGrantPremium').call({
        'targetUid': widget.uid,
        'durationDays': selectedDays,
        'note': noteCtrl.text.trim(),
      });
      Get.back();
      Get.snackbar('Başarılı', 'Premium verildi!',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _loadUser();
    } catch (e) {
      Get.back();
      Get.snackbar('Hata', 'Premium verilemedi: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _revokePremium() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Premium İptal',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Bu kullanıcının Premium üyeliğini iptal etmek istediğinize emin misiniz?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Vazgeç',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('İptal Et',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      Get.dialog(
          const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
          barrierDismissible: false);
      await _functions.httpsCallable('adminRevokePremium').call({
        'targetUid': widget.uid,
      });
      Get.back();
      Get.snackbar('Başarılı', 'Premium iptal edildi.',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _loadUser();
    } catch (e) {
      Get.back();
      Get.snackbar('Hata', 'İptal başarısız: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> _sendNotification() async {
    if (_notifTitleCtrl.text.trim().isEmpty ||
        _notifBodyCtrl.text.trim().isEmpty) {
      Get.snackbar('Uyarı', 'Başlık ve içerik zorunludur.',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    setState(() => _notifLoading = true);
    try {
      await _functions.httpsCallable('adminSendUserNotification').call({
        'targetUid': widget.uid,
        'title': _notifTitleCtrl.text.trim(),
        'body': _notifBodyCtrl.text.trim(),
      });
      _notifTitleCtrl.clear();
      _notifBodyCtrl.clear();
      Get.snackbar('Başarılı', 'Bildirim gönderildi!',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Hata', 'Gönderilemedi: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _notifLoading = false);
    }
  }

  Future<void> _manageUser(String action) async {
    try {
      Get.dialog(
          const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
          barrierDismissible: false);
      await _functions.httpsCallable('adminManageUser').call({
        'targetUid': widget.uid,
        'action': action,
      });
      Get.back();
      Get.snackbar('Başarılı', 'İşlem tamamlandı: $action',
          backgroundColor: Colors.green, colorText: Colors.white);
      await _loadUser();
    } catch (e) {
      Get.back();
      Get.snackbar('Hata', 'İşlem başarısız: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kullanıcı Detayı',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(widget.email,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadUser,
              tooltip: 'Yenile',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _loading && _userData == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : _error != null && _userData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 56),
                        const SizedBox(height: 16),
                        const Text('Kullanıcı yüklenemedi',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12))),
                          onPressed: _loadUser,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                          label: const Text('Tekrar Dene',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final data = _userData ?? {};
    final isPremium = data['isPremium'] == true;
    final isBanned = data['isBanned'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header
          _buildUserHeader(data, isPremium, isBanned),
          const SizedBox(height: 20),

          // Section 1: User Info
          _buildInfoSection(data),
          const SizedBox(height: 16),

          // Section 2: Premium Status
          _buildPremiumStatusSection(data, isPremium),
          const SizedBox(height: 16),

          // Section 3: Premium Management
          _buildPremiumManagementSection(isPremium),
          const SizedBox(height: 16),

          // Section 4: Personal Notification
          _buildNotificationSection(),
          const SizedBox(height: 16),

          // Section 5: Other actions
          _buildOtherActionsSection(isBanned),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildUserHeader(
      Map<String, dynamic> data, bool isPremium, bool isBanned) {
    final displayName = data['displayName'] as String? ?? '';
    final email = data['email'] as String? ?? widget.email;
    final isAnon = data['isAnonymous'] == true;

    Color statusColor = Colors.grey;
    String statusLabel = 'Ücretsiz';
    if (isBanned) {
      statusColor = Colors.redAccent;
      statusLabel = 'Banlı';
    } else if (isPremium) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Premium';
    } else if (isAnon) {
      statusColor = Colors.orange;
      statusLabel = 'Anonim';
    }

    return AdminGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: statusColor.withOpacity(0.2),
            child: Text(
              isAnon
                  ? '?'
                  : (displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : email[0].toUpperCase()),
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 26),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : email,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
                if (displayName.isNotEmpty)
                  Text(email,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> data) {
    final lastLoginMs = data['lastLoginAt'];
    String lastLoginStr = 'Bilinmiyor';
    if (lastLoginMs != null) {
      try {
        final dt = DateTime.fromMillisecondsSinceEpoch(
            (lastLoginMs as num).toInt());
        lastLoginStr = DateFormat('dd.MM.yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    return _sectionCard(
      icon: Icons.person_rounded,
      title: 'Kullanıcı Bilgileri',
      color: const Color(0xFF3B82F6),
      child: Column(
        children: [
          _infoRow(Icons.fingerprint_rounded, 'UID',
              data['uid'] as String? ?? widget.uid,
              selectable: true),
          _divider(),
          _infoRow(Icons.email_rounded, 'E-posta',
              data['email'] as String? ?? widget.email),
          _divider(),
          _infoRow(Icons.badge_rounded, 'Ad Soyad',
              data['displayName'] as String? ?? '-'),
          _divider(),
          _infoRow(Icons.access_time_rounded, 'Son Giriş', lastLoginStr),
          _divider(),
          _infoRow(Icons.smartphone_rounded, 'Son Cihaz',
              data['lastDeviceName'] as String? ?? 'Bilinmiyor'),
          _divider(),
          _infoRow(Icons.devices_other_rounded, 'Cihaz Limiti',
              '${data['maxDevices'] ?? 3} Cihaz'),
        ],
      ),
    );
  }

  Widget _buildPremiumStatusSection(
      Map<String, dynamic> data, bool isPremium) {
    final premiumSource = data['premiumSource'] as String? ?? '-';
    final purchaseDate = data['purchaseDate'] as String?;
    final premiumExpiry = data['premiumExpiry'] as String?;

    String purchaseStr = '-';
    if (purchaseDate != null && purchaseDate.isNotEmpty) {
      try {
        purchaseStr = DateFormat('dd.MM.yyyy')
            .format(DateTime.parse(purchaseDate));
      } catch (_) {}
    }

    String expiryStr = 'Sınırsız';
    if (premiumExpiry != null && premiumExpiry.isNotEmpty) {
      try {
        expiryStr = DateFormat('dd.MM.yyyy HH:mm')
            .format(DateTime.parse(premiumExpiry));
      } catch (_) {}
    }

    return _sectionCard(
      icon: Icons.workspace_premium_rounded,
      title: 'Premium Durumu',
      color: const Color(0xFFF59E0B),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Durum',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFFF59E0B).withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isPremium
                          ? const Color(0xFFF59E0B).withOpacity(0.5)
                          : Colors.grey.withOpacity(0.3)),
                ),
                child: Text(
                  isPremium ? '✦ Premium' : 'Ücretsiz',
                  style: TextStyle(
                      color: isPremium
                          ? const Color(0xFFF59E0B)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          if (isPremium) ...[
            _divider(),
            _infoRow(Icons.source_rounded, 'Kaynak', premiumSource),
            _divider(),
            _infoRow(Icons.calendar_today_rounded, 'Satın Alma',
                purchaseStr),
            _divider(),
            _infoRow(
                Icons.timer_rounded, 'Bitiş Tarihi', expiryStr),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumManagementSection(bool isPremium) {
    return _sectionCard(
      icon: Icons.admin_panel_settings_rounded,
      title: 'Premium Yönetimi',
      color: const Color(0xFF10B981),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _actionButton(
            label: 'Premium Ver',
            icon: Icons.star_rounded,
            color: const Color(0xFFF59E0B),
            onTap: _grantPremium,
          ),
          if (isPremium)
            _actionButton(
              label: 'Premium İptal',
              icon: Icons.star_border_rounded,
              color: Colors.redAccent,
              onTap: _revokePremium,
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return _sectionCard(
      icon: Icons.notifications_active_rounded,
      title: 'Kişisel Bildirim',
      color: const Color(0xFF6366F1),
      child: Column(
        children: [
          _darkTextField(
            controller: _notifTitleCtrl,
            label: 'Bildirim Başlığı',
            hint: 'Başlık girin...',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 12),
          _darkTextField(
            controller: _notifBodyCtrl,
            label: 'Bildirim İçeriği',
            hint: 'Mesaj içeriği...',
            icon: Icons.message_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _gradientButton(
              label: 'Bildirim Gönder',
              icon: Icons.send_rounded,
              loading: _notifLoading,
              onTap: _sendNotification,
              gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherActionsSection(bool isBanned) {
    final data = _userData ?? {};

    return _sectionCard(
      icon: Icons.settings_rounded,
      title: 'Diğer İşlemler',
      color: Colors.white54,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _actionButton(
            label: 'Cihazları Sıfırla',
            icon: Icons.devices_rounded,
            color: Colors.orangeAccent,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Cihazları Sıfırla',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      'Bu kullanıcının tüm kayıtlı cihazları silinecek. Onaylıyor musunuz?',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('İptal',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Get.back(result: true),
                      child: const Text('Sıfırla'),
                    ),
                  ],
                ),
              );
              if (ok == true) _manageUser('reset_devices');
            },
          ),
          _actionButton(
            label: 'Cihaz Limiti Düzenle',
            icon: Icons.format_list_numbered_rounded,
            color: Colors.blueAccent,
            onTap: () async {
              int currentLimit = data['maxDevices'] as int? ?? 3;
              final ctrl = TextEditingController(text: currentLimit.toString());
              final newLimitStr = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Cihaz Limitini Düzenle',
                      style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Yeni Limit (Örn: 3, 5, 10)',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blueAccent)),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('İptal',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Get.back(result: ctrl.text),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              );
              
              if (newLimitStr != null && newLimitStr.isNotEmpty) {
                final limit = int.tryParse(newLimitStr.trim());
                if (limit != null && limit >= 0) {
                  try {
                    Get.dialog(
                        const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                        barrierDismissible: false);
                    await _functions.httpsCallable('adminManageUser').call({
                      'targetUid': widget.uid,
                      'action': 'set_device_limit',
                      'limit': limit,
                    });
                    Get.back();
                    Get.snackbar('Başarılı', 'Cihaz limiti güncellendi!',
                        backgroundColor: Colors.green, colorText: Colors.white);
                    await _loadUser();
                  } catch (e) {
                    Get.back();
                    Get.snackbar('Hata', 'Limit güncellenemedi: $e',
                        backgroundColor: Colors.redAccent, colorText: Colors.white);
                  }
                } else {
                  Get.snackbar('Hata', 'Geçerli bir sayı girin.',
                      backgroundColor: Colors.redAccent, colorText: Colors.white);
                }
              }
            },
          ),
          _actionButton(
            label: isBanned ? 'Ban Kaldır' : 'Banla',
            icon: isBanned ? Icons.check_circle_rounded : Icons.block_rounded,
            color: isBanned ? Colors.green : Colors.redAccent,
            onTap: () async {
              final action = isBanned ? 'unban' : 'ban';
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(isBanned ? 'Ban Kaldır' : 'Kullanıcıyı Banla',
                      style: const TextStyle(color: Colors.white)),
                  content: Text(
                    isBanned
                        ? 'Bu kullanıcının banını kaldırmak istiyor musunuz?'
                        : 'Bu kullanıcıyı banlamak istiyor musunuz?',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('İptal',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isBanned ? Colors.green : Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Get.back(result: true),
                      child: Text(isBanned ? 'Ban Kaldır' : 'Banla'),
                    ),
                  ],
                ),
              );
              if (ok == true) _manageUser(action);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return AdminGlassCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.white38),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12))
                : Text(value,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(color: Colors.white10, height: 1);

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
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
          borderSide: const BorderSide(
              color: Color(0xFF6366F1), width: 1.5),
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
        padding: const EdgeInsets.symmetric(vertical: 15),
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
                      strokeWidth: 2.5, color: Colors.white70))
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
