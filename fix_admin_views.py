import re
import os

# 1. Fix AdminDashboardView
with open('lib/modules/settings/admin_dashboard_view.dart', 'r') as f:
    content = f.read()

# Make it wrap Scaffold with ThemedSettingsBackground
content = content.replace(
    """    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ThemedSettingsBackground(child: _isLoading""",
    """    return ThemedSettingsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading"""
)

# Fix the end of body which was wrapped in ThemedSettingsBackground
content = content.replace(
    """            ),
          ),
    );
  }
}""",
    """            ),
          ),
      ),
    );
  }
}"""
)

with open('lib/modules/settings/admin_dashboard_view.dart', 'w') as f:
    f.write(content)

# 2. Fix AdminAnnouncementsView
with open('lib/modules/settings/admin_announcements_view.dart', 'r') as f:
    content = f.read()

content = content.replace(
    """    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Duyuru Yönetimi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ThemedSettingsBackground(""",
    """    return ThemedSettingsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Duyuru Yönetimi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: """
)
content = content.replace(
    """        ),
      ),
    );
  }""",
    """        ),
      ),
    );
  }"""
)
# Wait, replacing the end for Announcements might be tricky. Let's just do it with regex.
