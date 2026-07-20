import re

with open('lib/core/services/chat_service.dart', 'r') as f:
    content = f.read()

target = """  void _listenToAnnouncements() {
    _announcementSub?.cancel();
    if (!gFirebaseReady) return;
    _announcementSub = FirebaseFirestore.instance
        .collection('admin_announcements')
        .where('scheduledFor', isLessThanOrEqualTo: Timestamp.now())
        .orderBy('scheduledFor', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final data = doc.data();"""

replacement = """  void _listenToAnnouncements() {
    _announcementSub?.cancel();
    if (!gFirebaseReady) return;
    _announcementSub = FirebaseFirestore.instance
        .collection('admin_announcements')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      
      final now = DateTime.now();
      QueryDocumentSnapshot<Map<String, dynamic>>? validDoc;
      
      for (final doc in snap.docs) {
        final data = doc.data();
        final sf = data['scheduledFor'] as Timestamp?;
        if (sf != null) {
          final scheduledDate = sf.toDate();
          if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
            validDoc = doc;
            break;
          }
        }
      }
      
      if (validDoc == null) return;
      
      final doc = validDoc;
      final data = doc.data();"""

content = content.replace(target, replacement)

# Now fix the close behavior in ChatService.
# "otomatik kapanmasın kullanıcı kapatsın."
# Let's find where the dialog is shown.
target2 = """            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Kapatma butonu
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Get.back(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Colors.amberAccent,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            if (url != null && url.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Get.back(); // Önce kapat
                                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                },
                                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                                label: const Text(
                                  'Detaylı Bilgi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });
  }"""
  
# The user wants "otomatik kapanmasın kullanıcı kapatsın".
# Wait, why did it auto-close?
# `Get.dialog` takes `barrierDismissible: true` by default. There is no auto-close timeout here!
# Let's see if there is something else that auto-closes it.
# Wait, `while (Get.currentRoute == '/' || Get.currentRoute.isEmpty)` handles the splash screen wait.
# But splash screen might still be navigating?
# In `ChatService.dart`:
# `Future.delayed(const Duration(milliseconds: 500));` 
# Then `Get.dialog` is called.
# Wait, `Get.dialog` doesn't auto-close unless something calls `Get.back()`!
# Is it possible that `_listenToAnnouncements()` is being triggered again when a field updates (like `createdAt`), and it calls `Get.back()` inside:
# `if (Get.isDialogOpen ?? false) { Get.back(); }`
# Yes! `if (Get.isDialogOpen ?? false) { Get.back(); }` is called BEFORE showing the new dialog. But the ID shouldn't change!
# Wait, if ID is the same, `lastShown != id` is FALSE, so it returns early.
# So why does it auto close?
# Let's check splash controller. When splash finishes, it calls `Get.offAll(() => const HomeLayout())`.
# `Get.offAll` clears the entire route stack! It clears the dialog too!
# YES! The splash screen navigation `Get.offAll` destroys the dialog!
# So to fix it, we should wait until the route is `HomeLayout`, or `AppRoutes.home`!
