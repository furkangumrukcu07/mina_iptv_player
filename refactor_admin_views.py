import os

files = [
    'lib/modules/settings/admin_announcements_view.dart',
    'lib/modules/settings/admin_support_manager_view.dart'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Find the Scaffold
    if 'return Scaffold(' in content and 'body: ThemedSettingsBackground(' in content:
        # We need to extract the part inside ThemedSettingsBackground
        # This is a bit tricky with regex, so we'll do simple string replacements if possible.
        content = content.replace('body: ThemedSettingsBackground(', 'body: ')
        # We also need to remove the matching parenthesis at the end.
        # But instead of regex parsing, it's easier to just wrap the whole Scaffold.
        pass

