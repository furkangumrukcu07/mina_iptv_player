import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AdminUserActivityLogsView extends StatefulWidget {
  const AdminUserActivityLogsView({super.key});

  @override
  State<AdminUserActivityLogsView> createState() => _AdminUserActivityLogsViewState();
}

class _AdminUserActivityLogsViewState extends State<AdminUserActivityLogsView> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialLogs();
  }

  Future<void> _fetchInitialLogs() async {
    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastLoginAt', descending: true)
          .limit(50)
          .get();

      setState(() {
        _searchResults = snap.docs;
      });
    } catch (e) {
      Get.snackbar('Hata', 'Loglar yüklenemedi. Yetkiniz yok veya internet sorunu: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white, duration: const Duration(seconds: 4));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchLogs() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _fetchInitialLogs();
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      // UID ile arayalım:
      final uidSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, isEqualTo: query)
          .get();

      setState(() {
        _searchResults = uidSnap.docs;
      });
    } catch (e) {
      Get.snackbar('Hata', 'Arama sırasında hata oluştu: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white, duration: const Duration(seconds: 4));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Kullanıcı Hareket Dökümleri', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı UID girin...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    ),
                    onSubmitted: (_) => _searchLogs(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _searchLogs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ara', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? const Center(
                          child: Text(
                            'Kayıt bulunamadı.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final doc = _searchResults[index];
                            final data = doc.data() as Map<String, dynamic>? ?? {};
                            
                            final ts = data['lastLoginAt'] as Timestamp?;
                            final dateStr = ts != null
                                ? DateFormat('dd MMM yyyy, HH:mm').format(ts.toDate())
                                : 'Bilinmiyor';
                            
                            final os = data['lastDeviceOS'] ?? 'Bilinmiyor';
                            final name = data['lastDeviceName'] ?? 'Bilinmiyor';

                            return Card(
                              color: const Color(0xFF1E293B),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                                  child: const Icon(Icons.history, color: Colors.blueAccent),
                                ),
                                title: Text(doc.id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text('Cihaz: $name ($os)', style: const TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 4),
                                    Text('Son Giriş: $dateStr', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
