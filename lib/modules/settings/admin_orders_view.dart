import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  bool _loading = true;
  List<dynamic> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('adminGetLatestOrders')
          .call<Map<String, dynamic>>({'limitCount': 100});

      if (mounted) {
        setState(() {
          _orders = result.data['orders'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Bilinmiyor';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()} yıl önce';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()} ay önce';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} gün önce';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} saat önce';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} dakika önce';
      } else {
        return 'az önce';
      }
    } catch (_) {
      return 'Bilinmiyor';
    }
  }

  Widget _buildStatusIcon(String source) {
    if (source == 'play') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_rounded,
            color: Colors.green, size: 20),
      );
    } else if (source == 'admin_grant') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
      );
    } else if (source == 'code') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.qr_code_rounded, color: Colors.blue, size: 20),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.info_rounded, color: Colors.grey, size: 20),
      );
    }
  }

  String _getTitle(Map<String, dynamic> order) {
    final source = order['source'] as String?;
    final productId = order['productId'] as String?;
    if (source == 'play') {
      if (productId != null && productId.contains('plus')) {
        return 'Premium Plus';
      }
      return 'Premium';
    } else if (source == 'admin_grant') {
      return 'Admin Tarafından Verildi';
    } else if (source == 'code') {
      return 'Lisans Kodu (Hediye)';
    }
    return 'Bilinmeyen Satın Alım';
  }

  String _getSubtitle(Map<String, dynamic> order) {
    final source = order['source'] as String?;
    if (source == 'play') {
      return order['playOrderId']?.toString() ?? 'Sipariş ID Bulunamadı';
    } else if (source == 'admin_grant') {
      return order['adminNote']?.toString().isNotEmpty == true
          ? order['adminNote'].toString()
          : 'Yönetici Hediyesi';
    } else if (source == 'code') {
      return order['adminNote']?.toString() ?? 'Kod Kullanıldı';
    }
    return order['uid']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Satın Alımlar (Siparişler)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Hata: $_error', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B)),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Text('Henüz hiç satın alım veya aktif premium lisansı yok.',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.white.withValues(alpha: 0.05),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final order = Map<String, dynamic>.from(_orders[index] as Map);
        final title = _getTitle(order);
        final subtitle = _getSubtitle(order);
        final timeStr = _formatTime(order['purchaseDate'] as String?);
        final source = order['source'] as String? ?? '';
        final email = order['email'] as String? ?? 'Bilinmeyen Kullanıcı';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                          color: Colors.blueAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusIcon(source),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
