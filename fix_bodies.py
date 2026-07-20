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

    # Find where `body:` starts.
    body_idx = content.find('body: ')
    if body_idx != -1 and 'ThemedSettingsBackground(' not in content[body_idx:body_idx+50]:
        # Replace `body: ` with `body: ThemedSettingsBackground(child: `
        # And we must close ThemedSettingsBackground before Scaffold closes.
        # The Scaffold closes at the next `    );` that aligns with `    return Scaffold(`.
        # Actually it's easier to find `    );` at the end of the build method.
        
        # Let's find `    return Scaffold(`
        scaffold_idx = content.find('return Scaffold(')
        
        # Find the matching closing bracket for Scaffold
        count = 0
        end_idx = -1
        for i in range(scaffold_idx + 15, len(content)):
            if content[i] == '(': count += 1
            elif content[i] == ')':
                count -= 1
                if count == 0:
                    end_idx = i
                    break
        
        if end_idx != -1:
            # We found the end of Scaffold.
            # Insert `)` right before `end_idx`
            new_content = content[:body_idx] + 'body: ThemedSettingsBackground(child: ' + content[body_idx + 6:end_idx] + ')' + content[end_idx:]
            with open(file, 'w') as f:
                f.write(new_content)

