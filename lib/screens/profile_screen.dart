import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/monthly_report_service.dart';
import 'route_history_screen.dart';
import 'saved_routes_screen.dart';
import 'settings_screen.dart';
import 'monthly_report_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  static const String _verificationCooldownKey =
      'email_verification_cooldown_until';

  final _displayNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _authService = AuthService();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  bool _isGeneratingReport = false;
  DateTime? _lastEmailVerificationSent;
  DateTime? _verificationCooldownUntil;
  String? _photoUrlOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadVerificationCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.refreshUserData();
      _loadUserData();
    }
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _phoneNumberController.text = user.phoneNumber ?? '';
      _photoUrlOverride = user.photoUrl;
    }
  }

  Future<void> _loadVerificationCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownMillis = prefs.getInt(_verificationCooldownKey);
    if (cooldownMillis == null) return;

    final cooldownUntil = DateTime.fromMillisecondsSinceEpoch(cooldownMillis);
    if (cooldownUntil.isAfter(DateTime.now())) {
      if (mounted) {
        setState(() {
          _verificationCooldownUntil = cooldownUntil;
        });
      }
    } else {
      await prefs.remove(_verificationCooldownKey);
    }
  }

  Future<void> _setVerificationCooldown(Duration duration) async {
    final cooldownUntil = DateTime.now().add(duration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _verificationCooldownKey,
      cooldownUntil.millisecondsSinceEpoch,
    );
    if (mounted) {
      setState(() {
        _verificationCooldownUntil = cooldownUntil;
      });
    }
  }

  Future<void> _clearVerificationCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verificationCooldownKey);
    if (mounted) {
      setState(() {
        _verificationCooldownUntil = null;
      });
    }
  }

  Future<void> _saveProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      await authProvider.updateProfile(
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isEmpty
            ? null
            : _phoneNumberController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final file = File(image.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile')
          .child('${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final photoUrl = await storageRef.getDownloadURL();
      await authProvider.updateProfile(photoUrl: photoUrl);

      if (mounted) {
        setState(() {
          _photoUrlOverride = photoUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final errorText = e.toString();
      final message = errorText.contains('permission-denied')
          ? 'Upload blocked by Firebase Storage rules.'
          : errorText.contains('object-not-found')
              ? 'Upload failed because the file reference was not available.'
              : 'Photo upload failed: $errorText';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _refreshEmailVerificationStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.refreshUserData();
      final user = authProvider.currentUser;
      if (!mounted || user == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.isEmailVerified
                ? 'Email verified successfully.'
                : 'Email is still not verified. Check your inbox and spam folder.',
          ),
          backgroundColor: user.isEmailVerified ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing verification status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmailVerification() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final cooldownUntil = _verificationCooldownUntil;
    if (cooldownUntil != null && cooldownUntil.isAfter(DateTime.now())) {
      final remaining = cooldownUntil.difference(DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification is temporarily rate-limited. Try again in ${remaining.inMinutes.clamp(1, 59)} minutes.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_lastEmailVerificationSent != null) {
      final timeSinceLastRequest =
          DateTime.now().difference(_lastEmailVerificationSent!);
      if (timeSinceLastRequest.inSeconds < 60) {
        final remainingTime = 60 - timeSinceLastRequest.inSeconds;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please wait $remainingTime seconds before requesting another verification email.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    try {
      await _authService.sendEmailVerification();
      _lastEmailVerificationSent = DateTime.now();
      await _clearVerificationCooldown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification email sent to ${user.email}. Please check your inbox and spam folder.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      final errorText = e.toString();
      if (errorText.contains('too-many-requests')) {
        await _setVerificationCooldown(const Duration(minutes: 30));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verification failed: $errorText'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _generateMonthlyReport() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() => _isGeneratingReport = true);

    try {
      // Generate report for current month
      final currentPeriod = DateTime(DateTime.now().year, DateTime.now().month);
      
      final report = await MonthlyReportService.generateMonthlyReport(
        userId: user.id,
        userName: user.displayName ?? 'SafeRoute User',
        period: currentPeriod,
      );

      // Navigate to report screen to display it
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MonthlyReportScreen(report: report),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReport = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_isEditing) {
                          _saveProfile();
                        } else {
                          setState(() => _isEditing = true);
                        }
                      },
              ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isEditing = false;
                            _loadUserData();
                          });
                        },
                ),
            ],
          ),
          body: user == null
              ? const Center(child: Text('No user data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundImage:
                                          (_photoUrlOverride ?? user.photoUrl) !=
                                                      null &&
                                                  (_photoUrlOverride ?? user.photoUrl)!
                                                      .startsWith('https://') &&
                                                  ((_photoUrlOverride ?? user.photoUrl)!
                                                          .contains(
                                                              'firebasestorage.googleapis.com') ||
                                                      (_photoUrlOverride ?? user.photoUrl)!
                                                          .contains(
                                                              'storage.googleapis.com'))
                                              ? NetworkImage(
                                                  _photoUrlOverride ??
                                                      user.photoUrl!,
                                                )
                                              : null,
                                      child: (_photoUrlOverride ?? user.photoUrl) ==
                                                  null ||
                                              !(_photoUrlOverride ?? user.photoUrl)!
                                                  .startsWith('https://') ||
                                              (!(_photoUrlOverride ?? user.photoUrl)!
                                                      .contains(
                                                          'firebasestorage.googleapis.com') &&
                                                  !(_photoUrlOverride ?? user.photoUrl)!
                                                      .contains(
                                                          'storage.googleapis.com'))
                                          ? const Icon(Icons.person, size: 60)
                                          : null,
                                    ),
                                    if (_isEditing)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.blue[700],
                                          child: _isUploadingPhoto
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(Colors.white),
                                                  ),
                                                )
                                              : IconButton(
                                                  icon: const Icon(
                                                    Icons.camera_alt,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                  onPressed: _uploadPhoto,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                user.displayName ?? 'SafeRoute User',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: user.isEmailVerified
                                    ? null
                                    : _sendEmailVerification,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: user.isEmailVerified
                                        ? Colors.green[100]
                                        : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: !user.isEmailVerified
                                        ? Border.all(color: Colors.orange[300]!)
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user.isEmailVerified
                                            ? Icons.verified
                                            : Icons.email,
                                        size: 14,
                                        color: user.isEmailVerified
                                            ? Colors.green[800]
                                            : Colors.orange[800],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.isEmailVerified
                                            ? 'Email Verified'
                                            : 'Tap to Verify Email',
                                        style: TextStyle(
                                          color: user.isEmailVerified
                                              ? Colors.green[800]
                                              : Colors.orange[800],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!user.isEmailVerified)
                                OutlinedButton.icon(
                                  onPressed: _refreshEmailVerificationStatus,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Refresh Status'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _displayNameController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Display Name',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneNumberController,
                                enabled: _isEditing,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Statistics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      'Member Since',
                                      '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                                      Icons.calendar_today,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatCard(
                                      'Last Login',
                                      _formatLastLogin(user.lastLoginAt),
                                      Icons.access_time,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.favorite_border),
                              title: const Text('Saved Routes'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const SavedRoutesScreen(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.history),
                              title: const Text('Route History'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const RouteHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: _isGeneratingReport
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.assessment),
                              title: const Text('Monthly Safety Report'),
                              subtitle: const Text('Generate PDF report'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: _isGeneratingReport
                                  ? null
                                  : _generateMonthlyReport,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.settings),
                              title: const Text('Settings'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const SettingsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatLastLogin(DateTime lastLogin) {
    final now = DateTime.now();
    final difference = now.difference(lastLogin);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}