import re

files = [
    'lib/modules/settings/admin_announcements_view.dart',
    'lib/modules/settings/admin_support_manager_view.dart',
    'lib/modules/settings/admin_panel_view.dart'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # If it has `return Scaffold(` and later `body: ThemedSettingsBackground(child: `
    if 'return Scaffold(' in content and 'body: ThemedSettingsBackground(' in content:
        # We want to change it to `return ThemedSettingsBackground(child: Scaffold(`
        # and remove the `ThemedSettingsBackground` from body
        content = content.replace('return Scaffold(', 'return ThemedSettingsBackground(\n      child: Scaffold(')
        content = content.replace('body: ThemedSettingsBackground(', 'body: ')
        # Because we removed `ThemedSettingsBackground(child: `, we removed one level of nesting.
        # But wait, `ThemedSettingsBackground(` has a closing `)` at the very end.
        # It's at the end of the Scaffold.
        # Actually, let's just replace the exact known structures.
        
with open('lib/modules/settings/admin_announcements_view.dart', 'r') as f:
    content = f.read()
if 'return Scaffold(' in content and 'body: ThemedSettingsBackground(' in content:
    content = content.replace('return Scaffold(', 'return ThemedSettingsBackground(\n      child: Scaffold(')
    content = content.replace('body: ThemedSettingsBackground(', 'body: SizedBox(') # replace with SizedBox so parenthesis matches!
with open('lib/modules/settings/admin_announcements_view.dart', 'w') as f:
    f.write(content)

with open('lib/modules/settings/admin_support_manager_view.dart', 'r') as f:
    content = f.read()
if 'return Scaffold(' in content and 'body: ThemedSettingsBackground(' in content:
    content = content.replace('return Scaffold(', 'return ThemedSettingsBackground(\n      child: Scaffold(')
    content = content.replace('body: ThemedSettingsBackground(', 'body: SizedBox(') 
with open('lib/modules/settings/admin_support_manager_view.dart', 'w') as f:
    f.write(content)

# AdminPanelView was already modified to return ThemedSettingsBackground(child: Scaffold(
# Let's check it.
with open('lib/modules/settings/admin_panel_view.dart', 'r') as f:
    content = f.read()
    
# Let's make the "kullanılmamış kod getir" ui better and fix its logic.
# The user said "öylece kalıyor kod vermiyor"
# Let's replace the _fetchUnusedCode function
new_fetch = """  Future<void> _fetchUnusedCode() async {
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
          .get();

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
      setState(() {
        _statusMessage = 'Hata oluştu. Firebase kurallarınızı kontrol edin: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }"""

# Replace the old _fetchUnusedCode
old_fetch_pattern = re.compile(r'Future<void> _fetchUnusedCode\(\) async \{.*?\n  \}', re.DOTALL)
content = old_fetch_pattern.sub(new_fetch, content)

# Now let's improve the UI where _fetchedCode is displayed
old_ui_pattern = re.compile(r'if \(_fetchedCode != null\) \.\.\.\[.*?\]', re.DOTALL)
new_ui = """if (_fetchedCode != null) ...[
                              Container(
                                width: double.infinity,
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
                              const SizedBox(height: 16),
                            ]"""
content = old_ui_pattern.sub(new_ui, content)

# Make sure Clipboard is imported
if 'import \'package:flutter/services.dart\';' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")

with open('lib/modules/settings/admin_panel_view.dart', 'w') as f:
    f.write(content)
