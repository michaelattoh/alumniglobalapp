import 'package:alumni_global_app/core/services/auth_session.dart';
import 'package:alumni_global_app/core/services/biometric_service.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/services/push_token_service.dart';
import 'package:alumni_global_app/core/widgets/pin_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool inAppEnabled = true;
  bool pushEnabled = true;
  bool emailEnabled = false;
  bool messagesEnabled = true;
  bool connectionsEnabled = true;
  bool eventsEnabled = true;
  bool aiPersonalizationEnabled = true;
  bool _isSchoolAdmin = false;
  bool _previewAsAlumni = false;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _notificationSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadUserRole();
    _loadBiometrics();
  }

  Future<void> _loadUserRole() async {
    final user = await HomeApiService.fetchMe();
    final preview = await AuthSession.getPreviewAsAlumni();
    if (!mounted) return;
    setState(() {
      _isSchoolAdmin = user?['role']?.toString() == 'institution_admin';
      _previewAsAlumni = preview;
    });
  }

  Future<void> _loadBiometrics() async {
    final enabled = await AuthSession.getBiometricsEnabled();
    final available = await BiometricService.isAvailable();
    final soundEnabled = await AuthSession.getNotificationSoundEnabled();
    if (!mounted) return;
    setState(() {
      _biometricsEnabled = enabled && available;
      _biometricsAvailable = available;
      _notificationSoundEnabled = soundEnabled;
    });
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await HomeApiService.fetchNotificationPreferences();
      if (!mounted) return;
      setState(() {
        inAppEnabled = data['in_app_enabled'] ?? true;
        pushEnabled = data['push_enabled'] ?? true;
        emailEnabled = data['email_enabled'] ?? false;
        messagesEnabled = data['messages_enabled'] ?? true;
        connectionsEnabled = data['connections_enabled'] ?? true;
        eventsEnabled = data['events_enabled'] ?? true;
        aiPersonalizationEnabled = data['ai_personalization_enabled'] ?? true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load settings');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await HomeApiService.updateNotificationPreferences({
      'in_app_enabled': inAppEnabled,
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'messages_enabled': messagesEnabled,
      'connections_enabled': connectionsEnabled,
      'events_enabled': eventsEnabled,
      'ai_personalization_enabled': aiPersonalizationEnabled,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _error = 'Failed to save preferences');
    }
  }

  Future<void> _togglePush(bool enabled) async {
    setState(() => pushEnabled = enabled);
    if (enabled) {
      await PushTokenService.register();
    } else {
      await PushTokenService.unregister();
    }
    await _savePreferences();
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (!_biometricsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics not available on this device'),
        ),
      );
      return;
    }
    if (enabled) {
      final ok = await BiometricService.authenticate(
        reason: 'Enable biometric sign in',
      );
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not verify biometrics on this device yet. Please check your Android biometric setup and try again.',
            ),
          ),
        );
        return;
      }
      final pin = await showPinSetupDialog(context);
      if (pin == null || pin.isEmpty) {
        return;
      }
      await AuthSession.setPin(pin);
      await AuthSession.setBiometricRole(
        _isSchoolAdmin ? 'institution_admin' : 'alumni',
      );
    } else {
      await AuthSession.clearPin();
      await AuthSession.setBiometricRole(null);
    }
    await AuthSession.setBiometricsEnabled(enabled);
    if (!mounted) return;
    setState(() => _biometricsEnabled = enabled);
  }

  Future<void> _exportMyData() async {
    setState(() => _saving = true);
    final data = await HomeApiService.exportMyData();
    if (!mounted) return;
    setState(() => _saving = false);
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.')),
      );
      return;
    }
    final text = data.toString();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export ready'),
        content: const Text(
          'Your data export has been copied to your clipboard.',
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

  Future<void> _deleteMyAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will anonymize your account data and sign you out. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    final ok = await HomeApiService.deleteMyAccount();
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed. Please try again.')),
      );
      return;
    }
    await AuthSession.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                32 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                _sectionCard(
                  title: 'Notifications',
                  subtitle:
                      'Choose what should reach you and how it should get your attention.',
                  child: Column(
                    children: [
                      _toggleTile('In-app notifications', inAppEnabled, (v) {
                        setState(() => inAppEnabled = v);
                        _savePreferences();
                      }),
                      _toggleTile(
                        'Notification sound',
                        _notificationSoundEnabled,
                        (v) async {
                          setState(() => _notificationSoundEnabled = v);
                          await AuthSession.setNotificationSoundEnabled(v);
                        },
                      ),
                      _toggleTile('Push notifications', pushEnabled, (v) {
                        _togglePush(v);
                      }),
                      _toggleTile('Email notifications', emailEnabled, (v) {
                        setState(() => emailEnabled = v);
                        _savePreferences();
                      }),
                      _toggleTile('Messages', messagesEnabled, (v) {
                        setState(() => messagesEnabled = v);
                        _savePreferences();
                      }),
                      _toggleTile('Connections', connectionsEnabled, (v) {
                        setState(() => connectionsEnabled = v);
                        _savePreferences();
                      }),
                      _toggleTile('Events', eventsEnabled, (v) {
                        setState(() => eventsEnabled = v);
                        _savePreferences();
                      }),
                      _toggleTile(
                        'AI personalization',
                        aiPersonalizationEnabled,
                        (v) {
                          setState(() => aiPersonalizationEnabled = v);
                          _savePreferences();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Security',
                  subtitle:
                      'Keep sign-in smoother for you and tougher for anyone else.',
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: SwitchListTile(
                      title: const Text('Biometric login'),
                      subtitle: Text(
                        _biometricsAvailable
                            ? 'Use Face ID / Touch ID to sign in faster.'
                            : 'Biometrics not available on this device.',
                      ),
                      value: _biometricsEnabled,
                      onChanged: (v) => _toggleBiometrics(v),
                    ),
                  ),
                ),
                if (_isSchoolAdmin) ...[
                  const SizedBox(height: 20),
                  _sectionCard(
                    title: 'School admin tools',
                    subtitle:
                        'Manage your school presence, communication, and school-facing settings.',
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _previewAsAlumni,
                          onChanged: (v) async {
                            await AuthSession.setPreviewAsAlumni(v);
                            if (!mounted) return;
                            setState(() => _previewAsAlumni = v);
                          },
                          title: const Text('Preview as alumni'),
                          subtitle: const Text(
                            'Hide admin tools and preview the alumni view.',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        if (_previewAsAlumni)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Preview mode on. Admin tools are hidden.',
                            ),
                          ),
                        if (!_previewAsAlumni) ...[
                          _navTile(
                            icon: Icons.apartment_rounded,
                            title: 'School profile',
                            subtitle:
                                'Update your banner, logo, contacts, and school story.',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/institution-profile-setup'),
                          ),
                          const SizedBox(height: 12),
                          _navTile(
                            icon: Icons.campaign_rounded,
                            title: 'Create ad',
                            onTap: () =>
                                Navigator.of(context).pushNamed('/create-ad'),
                          ),
                          const SizedBox(height: 12),
                          _navTile(
                            icon: Icons.event_available_rounded,
                            title: 'Create event',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/create-event'),
                          ),
                          const SizedBox(height: 12),
                          _navTile(
                            icon: Icons.campaign_outlined,
                            title: 'Create announcement',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/create-announcement'),
                          ),
                          const SizedBox(height: 12),
                          _navTile(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Payment settings',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/payment-settings'),
                          ),
                          const SizedBox(height: 12),
                          _navTile(
                            icon: Icons.alternate_email_rounded,
                            title: 'Email settings',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/email-settings'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Your activity',
                  subtitle:
                      'Quick shortcuts to the things you have saved, hidden, scheduled, or muted.',
                  child: Column(
                    children: [
                      _navTile(
                        icon: Icons.schedule_rounded,
                        title: 'Scheduled posts',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/scheduled-posts'),
                      ),
                      const SizedBox(height: 12),
                      _navTile(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Saved posts',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/saved-posts'),
                      ),
                      const SizedBox(height: 12),
                      _navTile(
                        icon: Icons.visibility_off_outlined,
                        title: 'Hidden posts',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/hidden-posts'),
                      ),
                      const SizedBox(height: 12),
                      _navTile(
                        icon: Icons.volume_off_outlined,
                        title: 'Muted users',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/muted-users'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Privacy & data',
                  subtitle:
                      'Control exports, support access, account safety, and payment visibility.',
                  child: Column(
                    children: [
                      _navTile(
                        icon: Icons.download_rounded,
                        title: 'Export my data',
                        subtitle:
                            'Get a copy of your profile, posts, and activity.',
                        onTap: _saving ? null : _exportMyData,
                      ),
                      const SizedBox(height: 12),
                      _navTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Support tickets',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/support'),
                      ),
                      const SizedBox(height: 12),
                      _navTile(
                        icon: Icons.receipt_long_rounded,
                        title: 'Payment history',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/payments'),
                      ),
                      const SizedBox(height: 12),
                      _navTile(
                        icon: Icons.delete_forever_rounded,
                        iconColor: Colors.redAccent,
                        title: 'Delete my account',
                        subtitle: 'This action is permanent.',
                        onTap: _saving ? null : _deleteMyAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_saving) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }

  Widget _toggleTile(String title, bool value, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor ?? const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
