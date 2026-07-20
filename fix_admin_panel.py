import re

with open('lib/modules/settings/admin_panel_view.dart', 'r') as f:
    content = f.read()

# Replace the broken start of the build method
broken_start = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
                Padding(
                  padding: const EdgeInsets.symmetric("""

fixed_start = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: Column(
            children: [
                Padding(
                  padding: const EdgeInsets.symmetric("""

content = content.replace(broken_start, fixed_start)

# Add the closing brackets for the newly added widgets at the end of the build method
# Let's find the end of the build method.
end_pattern = """                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }"""
# Wait, the end brackets are currently missing.
# Let's just do a regex replace to fix the end of build method.
