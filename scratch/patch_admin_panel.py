import re

with open('lib/modules/settings/admin_panel_view.dart', 'r') as f:
    content = f.read()

with open('scratch/admin_panel_build.dart', 'r') as f:
    new_build = f.read()

# Replace everything from @override Widget build to the end of the file
pattern = re.compile(r'@override\s+Widget build\(BuildContext context\) \{.*', re.DOTALL)
new_content = pattern.sub(new_build, content)

with open('lib/modules/settings/admin_panel_view.dart', 'w') as f:
    f.write(new_content)

print("Patched admin_panel_view.dart successfully!")
