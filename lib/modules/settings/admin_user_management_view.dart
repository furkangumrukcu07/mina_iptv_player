import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'admin_user_detail_view.dart';
import 'admin_glass_widgets.dart';

class AdminUserManagementView extends StatefulWidget {
  const AdminUserManagementView({super.key});

  @override
  State<AdminUserManagementView> createState() => _AdminUserManagementViewState();
}

class _AdminUserManagementViewState extends State<AdminUserManagementView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _displayedUsers = [];
  bool _isLoading = false;
  String _filterType = 'all'; // all, premium, free, banned, anonymous

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
  }

  Future<void> _fetchAllUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('adminListAllUsers');
      final result = await callable.call({'limitCount': 1000});
      final data = result.data as Map<String, dynamic>;
      final users = (data['users'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _allUsers = users;
        _applyFilter();
      });
    } catch (e) {
      Get.snackbar('Hata', 'Kullanıcılar yüklenemedi: $e',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> filtered = _allUsers;

    // Tip filtresi
    if (_filterType == 'all') {
      // Show everything
    } else if (_filterType == 'registered') {
      filtered = filtered.where((u) => u['isAnonymous'] != true).toList();
    } else if (_filterType == 'premium') {
      filtered = filtered.where((u) => u['isPremium'] == true && u['isBanned'] != true).toList();
    } else if (_filterType == 'free') {
      filtered = filtered.where((u) => u['isPremium'] != true && u['isBanned'] != true).toList();
    } else if (_filterType == 'banned') {
      filtered = filtered.where((u) => u['isBanned'] == true).toList();
    } else if (_filterType == 'anonymous') {
      filtered = filtered.where((u) => u['isAnonymous'] == true).toList();
    } else if (_filterType == 'recent_premium') {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      filtered = filtered.where((u) {
        if (u['isPremium'] != true) return false;
        final pd = u['purchaseDate'];
        if (pd == null) return false;
        try {
          final date = DateTime.parse(pd.toString());
          return date.isAfter(sevenDaysAgo);
        } catch (_) {
          return false;
        }
      }).toList();
      // Tarihe göre yeniden eskiye sırala
      filtered.sort((a, b) {
         final dateA = DateTime.tryParse(a['purchaseDate']?.toString() ?? '');
         final dateB = DateTime.tryParse(b['purchaseDate']?.toString() ?? '');
         if (dateA == null && dateB == null) return 0;
         if (dateA == null) return 1;
         if (dateB == null) return -1;
         return dateB.compareTo(dateA);
      });
    }

    // Arama filtresi
    if (query.isNotEmpty) {
      filtered = filtered.where((u) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final uid = (u['uid'] ?? '').toString().toLowerCase();
        final name = (u['displayName'] ?? '').toString().toLowerCase();
        final deviceName = (u['lastDeviceName'] ?? '').toString().toLowerCase();
        final deviceOS = (u['lastDeviceOS'] ?? '').toString().toLowerCase();
        return email.contains(query) || 
               uid.contains(query) || 
               name.contains(query) || 
               deviceName.contains(query) || 
               deviceOS.contains(query);
      }).toList();
    }

    _displayedUsers = filtered;
  }

  Future<void> _manageUser(String uid, String action, {bool isAnonymous = false}) async {
    try {
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('adminManageUser');
      await callable.call({'targetUid': uid, 'action': action});
      Get.back();

      Get.snackbar('Başarılı', 'İşlem tamamlandı ($action)',
          backgroundColor: Colors.green, colorText: Colors.white);

      _fetchAllUsers();
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
              const Text('Kullanıcı Yönetimi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${_allUsers.length} Toplam Kullanıcı', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _fetchAllUsers,
              tooltip: 'Yenile',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
        children: [
          // Arama
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AdminGlassCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email, UID, Ad veya Cihaz Modeli ara...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _applyFilter());
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() => _applyFilter()),
              ),
            ),
          ),
          // Filtreler
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'Tümü', Colors.blueAccent),
                  const SizedBox(width: 8),
                  _filterChip('registered', 'Kayıtlılar', Colors.purpleAccent),
                  const SizedBox(width: 8),
                  _filterChip('premium', 'Premium', Colors.green),
                  const SizedBox(width: 8),
                  _filterChip('recent_premium', 'Yeni Premiumlar', Colors.teal),
                  const SizedBox(width: 8),
                  _filterChip('free', 'Ücretsiz', Colors.grey),
                  const SizedBox(width: 8),
                  _filterChip('anonymous', 'Anonim (Trial)', Colors.orange),
                  const SizedBox(width: 8),
                  _filterChip('banned', 'Banlı', Colors.redAccent),
                ],
              ),
            ),
          ),
          // İstatistik bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _statBadge('${_allUsers.where((u) => u['isPremium'] == true).length}', 'Premium', Colors.greenAccent),
                const SizedBox(width: 8),
                _statBadge('${_allUsers.where((u) => u['isAnonymous'] == true).length}', 'Anonim', Colors.orange),
                const SizedBox(width: 8),
                _statBadge('${_allUsers.where((u) => u['isBanned'] == true).length}', 'Banlı', Colors.redAccent),
              ],
            ),
          ),
          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _displayedUsers.isEmpty
                    ? const Center(
                        child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _displayedUsers.length,
                        itemBuilder: (context, index) => _buildUserCard(_displayedUsers[index]),
                      ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _filterChip(String type, String label, Color color) {
    final selected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _filterType = type;
        _applyFilter();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.25) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white12),
        ),
        child: Text(label, style: TextStyle(color: selected ? color : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _statBadge(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final uid = user['uid'] as String? ?? '';
    final email = user['email'] as String? ?? 'Anonim Kullanıcı';
    final displayName = user['displayName'] as String? ?? '';
    final isPremium = user['isPremium'] == true;
    final isBanned = user['isBanned'] == true;
    final isAnonymous = user['isAnonymous'] == true;
    final lastDeviceName = user['lastDeviceName'] as String? ?? 'Bilinmiyor';
    final lastDeviceOS = user['lastDeviceOS'] as String? ?? '';
    final premiumSource = user['premiumSource'] as String? ?? '';

    String lastLoginStr = 'Bilinmiyor';
    final lastLoginMs = user['lastLoginAt'];
    if (lastLoginMs != null) {
      try {
        final dt = DateTime.fromMillisecondsSinceEpoch((lastLoginMs as num).toInt());
        lastLoginStr = DateFormat('dd.MM.yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    String purchaseDateStr = '';
    final purchaseDate = user['purchaseDate'] as String?;
    if (purchaseDate != null && purchaseDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(purchaseDate);
        purchaseDateStr = DateFormat('dd.MM.yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    Color statusColor = Colors.grey;
    String statusLabel = 'Ücretsiz';
    if (isBanned) {
      statusColor = Colors.redAccent;
      statusLabel = 'Banlı';
    } else if (isPremium) {
      statusColor = Colors.green;
      statusLabel = 'Premium';
    } else if (isAnonymous) {
      statusColor = Colors.orange;
      statusLabel = 'Anonim';
    }

    return AdminGlassCard(
      disableBlur: true,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      onTap: () => Get.to(() => AdminUserDetailView(uid: uid, email: email)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Text(
                    isAnonymous ? '?' : (displayName.isNotEmpty ? displayName[0].toUpperCase() : email[0].toUpperCase()),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isNotEmpty ? displayName : email,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (displayName.isNotEmpty)
                        Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  _infoRow(Icons.fingerprint, 'UID:', uid, selectable: true),
                  const SizedBox(height: 4),
                  _infoRow(Icons.access_time, 'Son Giriş:', lastLoginStr),
                  const SizedBox(height: 4),

                  _infoRow(Icons.smartphone, 'Cihaz:', '$lastDeviceName${lastDeviceOS.isNotEmpty ? ' ($lastDeviceOS)' : ''}'),
                  if (isPremium && purchaseDateStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.star, 'Premium Tarihi:', purchaseDateStr),
                  ],
                  if (isPremium && premiumSource.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.source, 'Kaynak:', premiumSource),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.withOpacity(0.9),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.devices, size: 16),
                  label: const Text('Cihazları Sıfırla', style: TextStyle(fontSize: 13)),
                  onPressed: () => _manageUser(uid, 'reset_devices'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBanned ? Colors.green : Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(isBanned ? Icons.check_circle : Icons.block, size: 16),
                  label: Text(isBanned ? 'Ban Kaldır' : 'Banla', style: const TextStyle(fontSize: 13)),
                  onPressed: () => _manageUser(uid, isBanned ? 'unban' : 'ban'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool selectable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.blueAccent),
        const SizedBox(width: 6),
        Text('$label ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Expanded(
          child: selectable
              ? SelectableText(value, style: const TextStyle(color: Colors.white70, fontSize: 12))
              : Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
