import re

with open('lib/modules/settings/admin_panel_view.dart', 'r') as f:
    content = f.read()

# First, extract the old build method from Git or just rewrite it from scratch.
# We know what the build method looks like exactly from my previous commands.

new_build = """  @override
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.admin_panel_settings, size: 64, color: Colors.blueAccent),
                          ),
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
                          else ...[
                            _buildActionCard(
                              title: 'Yeni Kod Üret (1000 Adet)',
                              icon: Icons.add_box_rounded,
                              color: Colors.blueAccent,
                              onTap: _generateCodes,
                            ),
                            const SizedBox(height: 16),
                            _buildActionCard(
                              title: 'Kullanılmamış Kod Getir',
                              icon: Icons.download_rounded,
                              color: Colors.greenAccent,
                              onTap: _fetchUnusedCode,
                            ),
                            const SizedBox(height: 16),
                            _buildActionCard(
                              title: 'Çevrimiçi Kullanıcıları Gör',
                              icon: Icons.people_alt_rounded,
                              color: Colors.purpleAccent,
                              onTap: () => Get.to(() => const AdminOnlineUsersView()),
                            ),
                            const SizedBox(height: 16),
                            _buildActionCard(
                              title: 'Duyuru Yönetimi',
                              icon: Icons.campaign_rounded,
                              color: Colors.orangeAccent,
                              onTap: () => Get.to(() => const AdminAnnouncementsView()),
                            ),
                            const SizedBox(height: 16),
                            _buildActionCard(
                              title: 'Detaylı Analiz (Dashboard)',
                              icon: Icons.analytics_rounded,
                              color: Colors.tealAccent,
                              onTap: () => Get.to(() => const AdminDashboardView()),
                            ),
                            const SizedBox(height: 16),
                            _buildActionCard(
                              title: 'Destek Talepleri',
                              icon: Icons.support_agent_rounded,
                              color: Colors.indigoAccent,
                              onTap: () => Get.to(() => const AdminSupportManagerView()),
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
  }"""

# regex replace everything from @override Widget build to Widget _buildStatCard
start_str = "  @override\n  Widget build(BuildContext context) {"
end_str = "  Widget _buildStatCard(String label, String value, Color color) {"

start_idx = content.find(start_str)
end_idx = content.find(end_str)

new_content = content[:start_idx] + new_build + "\n\n" + content[end_idx:]

with open('lib/modules/settings/admin_panel_view.dart', 'w') as f:
    f.write(new_content)
