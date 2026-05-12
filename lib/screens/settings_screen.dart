import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  String _defaultTransportMode = 'jeepney';
  bool _darkMode = false;
  String _language = 'en';
  
  // Privacy settings
  bool _locationHistoryEnabled = true;
  bool _analyticsEnabled = false;
  bool _crashReportsEnabled = true;

  List<String> _emergencyContacts = const [];
  bool _isSavingPrivacy = false;
  String? _appVersion;
  String? _buildNumber;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppInfo();
  }

  Future<void> _loadSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      final profile = await UserService.getCurrentUserProfile();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = user.preferences.notificationsEnabled;
        _locationSharingEnabled = user.preferences.locationSharingEnabled;
        _defaultTransportMode = user.preferences.defaultTransportMode;
        _darkMode = user.preferences.darkMode;
        _language = user.preferences.language;

        final preferences = profile?.preferences ?? const {};
        _locationHistoryEnabled = preferences['locationHistoryEnabled'] ?? true;
        _analyticsEnabled = preferences['analyticsEnabled'] ?? false;
        _crashReportsEnabled = preferences['crashReportsEnabled'] ?? true;
        _emergencyContacts = profile?.emergencyContacts ?? const [];
      });
    }
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _saveSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    try {
      // Update theme provider first for immediate UI change
      await themeProvider.setTheme(_darkMode);
      
      // Then save to Firestore
      await authProvider.updatePreferences(
        notificationsEnabled: _notificationsEnabled,
        locationSharingEnabled: _locationSharingEnabled,
        defaultTransportMode: _defaultTransportMode,
        darkMode: _darkMode,
        language: _language,
      );
      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        await UserService.updateUserProfile(currentUser.id, {
          'preferences': {
            'locationHistoryEnabled': _locationHistoryEnabled,
            'analyticsEnabled': _analyticsEnabled,
            'crashReportsEnabled': _crashReportsEnabled,
          },
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSection(
            'Account',
            Icons.person,
            [
              _buildSwitchTile(
                'Email Notifications',
                'Receive email notifications about your trips and safety alerts',
                _notificationsEnabled,
                (value) => setState(() => _notificationsEnabled = value),
              ),
              _buildSwitchTile(
                'Location Sharing',
                'Share your location for better route recommendations and safety features',
                _locationSharingEnabled,
                (value) => setState(() => _locationSharingEnabled = value),
              ),
            ],
          ),

          // Preferences Section
          _buildSection(
            'Preferences',
            Icons.tune,
            [
              _buildDropdownTile(
                'Default Transport Mode',
                'Choose your preferred mode of transportation',
                _defaultTransportMode,
                [
                  {'value': 'p2pBus', 'label': 'P2P Bus'},
                  {'value': 'carouselBus', 'label': 'Carousel Bus'},
                  {'value': 'cityBus', 'label': 'City Bus'},
                  {'value': 'mrt', 'label': 'MRT'},
                  {'value': 'lrt', 'label': 'LRT'},
                  {'value': 'jeepney', 'label': 'Jeepney'},
                  {'value': 'modernJeepney', 'label': 'Modern Jeepney'},
                  {'value': 'uvExpress', 'label': 'UV Express'},
                ],
                (value) => setState(() => _defaultTransportMode = value),
              ),
              _buildSwitchTile(
                'Dark Mode',
                'Use dark theme for the app interface',
                _darkMode,
                (value) => setState(() => _darkMode = value),
              ),
              _buildDropdownTile(
                'Language',
                'Choose your preferred language',
                _language,
                [
                  {'value': 'en', 'label': 'English'},
                  {'value': 'tl', 'label': 'Filipino'},
                ],
                (value) => setState(() => _language = value),
              ),
            ],
          ),

          // Safety Section
          _buildSection(
            'Safety',
            Icons.security,
            [
              _buildNavigationTile(
                'Emergency Contacts',
                'Manage emergency contacts for SOS feature',
                Icons.contacts,
                () {
                  _showEmergencyContactsDialog();
                },
              ),
              _buildNavigationTile(
                'Privacy Settings',
                'Control your data privacy and sharing preferences',
                Icons.lock,
                () {
                  _showPrivacySettingsDialog();
                },
              ),
              _buildNavigationTile(
                'Data & Storage',
                'Manage your data and storage usage',
                Icons.storage,
                () {
                  _showDataManagementDialog();
                },
              ),
            ],
          ),

          // About Section
          _buildSection(
            'About',
            Icons.info,
            [
              _buildNavigationTile(
                'Help & Support',
                'Get help with using SafeRoute',
                Icons.help,
                () {
                  _showHelpDialog();
                },
              ),
              _buildNavigationTile(
                'Terms of Service',
                'Read our terms and conditions',
                Icons.description,
                () {
                  _showTermsDialog();
                },
              ),
              _buildNavigationTile(
                'Privacy Policy',
                'Read our privacy policy',
                Icons.privacy_tip,
                () {
                  _showPrivacyPolicyDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('App Version'),
                subtitle: Text(
                  _appVersion == null
                      ? 'Loading version...'
                      : 'SafeRoute v$_appVersion ($_buildNumber)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showVersionInfoDialog();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: const Icon(Icons.toggle_on),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.blue[700],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String currentValue,
    List<Map<String, String>> options,
    Function(String) onChanged,
  ) {
    return ListTile(
      leading: const Icon(Icons.arrow_drop_down),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: currentValue,
        onChanged: (String? value) {
          if (value != null) onChanged(value);
        },
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option['value'],
            child: Text(option['label']!),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavigationTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showEmergencyContactsDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Emergency Contacts'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Emergency hotline contacts are fixed. Custom contacts are stored on your account.',
                  ),
                ),
                const SizedBox(height: 12),
                ..._emergencyContacts.map(
                  (contact) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person),
                    title: Text(contact),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final user = authProvider.currentUser;
                        if (user == null) return;
                        await UserService.removeEmergencyContact(user.id, contact);
                        setState(() {
                          _emergencyContacts = List<String>.from(_emergencyContacts)..remove(contact);
                        });
                        setDialogState(() {});
                      },
                    ),
                  ),
                ),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Add contact',
                    hintText: 'Name or phone number',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) return;

                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final user = authProvider.currentUser;
                if (user == null) return;

                await UserService.addEmergencyContact(user.id, value);
                setState(() {
                  _emergencyContacts = [..._emergencyContacts, value];
                });
                controller.clear();
                setDialogState(() {});
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Privacy Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Location History'),
                  subtitle: const Text('Save your location history'),
                  value: _locationHistoryEnabled,
                  onChanged: (value) {
                    setDialogState(() {
                      _locationHistoryEnabled = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Analytics Data'),
                  subtitle: const Text('Help improve SafeRoute'),
                  value: _analyticsEnabled,
                  onChanged: (value) {
                    setDialogState(() {
                      _analyticsEnabled = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Crash Reports'),
                  subtitle: const Text('Send crash reports to help fix bugs'),
                  value: _crashReportsEnabled,
                  onChanged: (value) {
                    setDialogState(() {
                      _crashReportsEnabled = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isSavingPrivacy ? null : () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                setState(() => _isSavingPrivacy = true);
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final user = authProvider.currentUser;
                  if (user != null) {
                    await UserService.updateUserProfile(user.id, {
                      'preferences': {
                        'locationHistoryEnabled': _locationHistoryEnabled,
                        'analyticsEnabled': _analyticsEnabled,
                        'crashReportsEnabled': _crashReportsEnabled,
                      },
                    });
                  }
                  if (mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Privacy settings saved')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isSavingPrivacy = false);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDataManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data & Storage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear Cache'),
              subtitle: const Text('Free up storage space'),
              onTap: () {
                _clearAppCache();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              subtitle: const Text('Download your data'),
              onTap: () {
                _exportUserData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently delete your account'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your current SafeRoute data, including saved routes, trip history, incidents, SOS alerts, profile data, and uploaded photos.\n\nNote: For security, you may need to log in again to confirm this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              Navigator.pop(context);
              try {
                await authProvider.deleteAccount();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully')),
                  );
                }
              } catch (e) {
                final errorMsg = e.toString();
                if (mounted) {
                  // Check if it's a re-authentication required error
                  if (errorMsg.contains('requires-recent-login') || 
                      errorMsg.contains('log in again')) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Please log in again before deleting your account (security requirement)'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Failed to delete account: $errorMsg')),
                    );
                  }
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(
          child: Text(
            'SafeRoute Help\n\n'
            '• Use the map screen to set your route and view safety information.\n'
            '• Use SOS if you need to alert emergency contacts.\n'
            '• Update your profile photo and account details from the Profile screen.\n'
            '• Save preferences in Settings and tap Save to apply them.\n\n'
            'If you need more help, this section can later be connected to a support page or contact form.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'SafeRoute Terms of Service\n\n'
            '1. The app is provided as-is for transportation and safety assistance.\n'
            '2. Emergency features depend on device permissions, network access, and third-party services.\n'
            '3. Users are responsible for the accuracy of their profile and emergency contact data.\n'
            '4. Do not use the app for unlawful or abusive activity.\n'
            '5. These terms can be replaced with your official policy when available.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'SafeRoute Privacy Policy\n\n'
            '• We store account details, preferences, and emergency contacts to provide app features.\n'
            '• Location data is used for route and safety functions when you enable it.\n'
            '• Photos and profile information are stored in your Firebase account.\n'
            '• You can clear cached data or delete your account from Settings.\n'
            '• This placeholder policy can be replaced with your formal privacy text later.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        for (final entry in cacheDir.listSync()) {
          try {
            entry.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }

  Future<void> _exportUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) return;

      final profile = await UserService.getCurrentUserProfile();
      final exportData = {
        'profile': profile == null
            ? null
            : {
                'id': profile.id,
                'email': profile.email,
                'displayName': profile.displayName,
                'phoneNumber': profile.phoneNumber,
                'photoUrl': profile.photoUrl,
                'homeLocation': profile.homeLocation == null
                    ? null
                    : {
                        'lat': profile.homeLocation!.latitude,
                        'lng': profile.homeLocation!.longitude,
                      },
                'workLocation': profile.workLocation == null
                    ? null
                    : {
                        'lat': profile.workLocation!.latitude,
                        'lng': profile.workLocation!.longitude,
                      },
                'emergencyContacts': profile.emergencyContacts,
                'preferences': profile.preferences,
                'createdAt': profile.createdAt.toIso8601String(),
                'updatedAt': profile.updatedAt.toIso8601String(),
                'isVerified': profile.isVerified,
                'fcmToken': profile.fcmToken,
              },
        'exportedAt': DateTime.now().toIso8601String(),
      };

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/saferoute_export_${user.id}.json');
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(exportData));

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'SafeRoute Data Export',
        text: 'Your SafeRoute data export is attached.',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export data: $e')),
        );
      }
    }
  }

  void _showVersionInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Version'),
        content: Text(
          _appVersion == null
              ? 'Loading version information...'
              : 'SafeRoute $_appVersion ($_buildNumber)\n\nBuilt for stable app settings and profile management.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
