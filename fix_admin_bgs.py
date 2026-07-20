import re
import os

files = [
    'lib/modules/settings/admin_announcements_view.dart',
    'lib/modules/settings/admin_dashboard_view.dart',
    'lib/modules/settings/admin_support_manager_view.dart',
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Add import if missing
    if 'themed_settings_background.dart' not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../ui/themed_settings_background.dart';")

    # Change background of scaffold
    # Look for Scaffold(...) and body:
    # Usually it's Scaffold(\n backgroundColor: Colors.black, or Color(...)
    content = re.sub(r'Scaffold\(\s*backgroundColor:\s*const Color\(0xFF0F172A\),', 'Scaffold(\n      backgroundColor: Colors.transparent,', content)
    content = re.sub(r'Scaffold\(\s*backgroundColor:\s*Color\(0xFF0F172A\),', 'Scaffold(\n      backgroundColor: Colors.transparent,', content)
    content = re.sub(r'Scaffold\(\s*backgroundColor:\s*Colors.black,', 'Scaffold(\n      backgroundColor: Colors.transparent,', content)
    content = re.sub(r'Scaffold\(\s*backgroundColor:\s*[^,]+,', 'Scaffold(\n      backgroundColor: Colors.transparent,', content)

    # If it has a body: Stack( or body: Column(, wrap it.
    if 'body: Stack(' in content:
        content = content.replace('body: Stack(', 'body: ThemedSettingsBackground(child: Stack(')
        # Find the matching closing bracket for Stack. Too hard with regex, let's just do it manually if possible.
    elif 'body: Column(' in content:
        content = content.replace('body: Column(', 'body: ThemedSettingsBackground(child: Column(')

    # I'll just write it back and I'll use sed or manual replacement for the closing brackets.
    # Actually, wrapping body manually in python is tricky without proper parsing.
    with open(file, 'w') as f:
        f.write(content)
