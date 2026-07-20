import re

files = [
    'lib/modules/settings/admin_announcements_view.dart',
    'lib/modules/settings/admin_support_manager_view.dart'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # The file ends with:
    #     );
    #   }
    # }
    # We need to add one more parenthesis to close ThemedSettingsBackground.
    
    if "return ThemedSettingsBackground" in content:
        # Check if it was already fixed to avoid double fixing
        # Count the number of 'return ThemedSettingsBackground(' and see if parenthesis match
        # Let's just do a naive replace at the end of the file
        content = content.replace("    );\n  }\n}", "      ),\n    );\n  }\n}")
        
    with open(file, 'w') as f:
        f.write(content)

