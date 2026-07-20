with open('lib/modules/settings/admin_announcements_view.dart', 'r') as f:
    content = f.read()

content = content.replace("      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n      ),\n    );\n  }\n}", "      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n    );\n  }\n}")

with open('lib/modules/settings/admin_announcements_view.dart', 'w') as f:
    f.write(content)

with open('lib/modules/settings/admin_support_manager_view.dart', 'r') as f:
    content = f.read()

content = content.replace("        );\n      },\n      ),\n    );\n  }\n}", "        );\n      },\n    );\n  }\n}")

with open('lib/modules/settings/admin_support_manager_view.dart', 'w') as f:
    f.write(content)
