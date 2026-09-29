import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/config/api_config.dart';
import 'package:alumni_global_app/core/services/push_token_service.dart';
import 'chat_media_viewer.dart';
import 'story_create_screen.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';
import 'network_screen.dart';
import 'post_screen.dart';
import 'notifications_screen.dart';
import 'jobs_screen.dart';
import 'funding_screen.dart';
import 'events_screen.dart';
import 'mentorship_screen.dart';
import 'package:alumni_global_app/features/home/widgets/mention_suggestion_box.dart';
import 'package:alumni_global_app/features/home/widgets/video_preview.dart';

const double _topBarHeight = 88.0;

bool _isVideoMediaTypeValue(String? type) =>
    (type ?? '').toLowerCase().startsWith('video');

bool _isImageMediaTypeValue(String? type) {
  final normalized = (type ?? '').toLowerCase();
  return normalized.isEmpty || normalized.startsWith('image');
}

Future<void> _syncAppIconBadge(int unread) async {
  try {
    if (!await FlutterAppBadger.isAppBadgeSupported()) return;
    if (unread > 0) {
      FlutterAppBadger.updateBadgeCount(unread);
    } else {
      FlutterAppBadger.removeBadge();
    }
  } catch (_) {
    // Badge sync should never block app usage.
  }
}

bool _isAccessRestricted() => HomeApiService.isInstitutionAccessRestricted;

void _showAccessRestrictedMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(HomeApiService.accessRestrictionMessage)),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int? _pendingStoryNotificationId;
  bool _handledInitialRouteArgs = false;

  late final ScrollController _scrollController;
  late final Widget _networkPage;
  late final Widget _mentorshipPage;
  late final Widget _jobsPage;
  late final Widget _notificationsPage;
  late final Widget _fundingPage;
  bool _showTopBar = true;
  bool _previewAsAlumni = false;
  final GlobalKey<_HomeFeedPageState> _homeFeedKey =
      GlobalKey<_HomeFeedPageState>();
  Timer? _notificationPoller;
  bool _notificationPolling = false;
  bool _notificationSoundEnabled = true;
  bool _notificationBaselineReady = false;
  int _lastUnreadNotifications = 0;
  int _unreadNotificationBadge = 0;
  int _unreadMessageBadge = 0;
  int _unreadSupportBadge = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _networkPage = const NetworkScreen();
    _mentorshipPage = const MentorshipScreen();
    _jobsPage = const JobsScreen();
    _notificationsPage = NotificationsScreen(
      onUnreadCountChanged: _handleUnreadNotificationCountChanged,
      onOpenStory: _handleOpenStoryFromNotification,
    );
    _fundingPage = const FundingScreen();
    _loadPreviewFlag();
    _initNotificationSoundPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handledInitialRouteArgs) {
      _handledInitialRouteArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final rawTab = args['tab'];
        final rawStoryId = args['storyId'] ?? args['story_id'];
        final tab = rawTab is int
            ? rawTab
            : rawTab is String
            ? int.tryParse(rawTab)
            : null;
        final storyId = rawStoryId is int
            ? rawStoryId
            : rawStoryId is String
            ? int.tryParse(rawStoryId)
            : null;
        if (tab != null || storyId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              if (tab != null) _selectedIndex = tab.clamp(0, 5);
              _pendingStoryNotificationId = storyId;
            });
          });
        }
      }
    }
    _loadPreviewFlag();
  }

  Future<void> _loadPreviewFlag() async {
    final preview = await AuthSession.getPreviewAsAlumni();
    if (!mounted) return;
    setState(() => _previewAsAlumni = preview);
  }

  void _handleUnreadNotificationCountChanged(int count) {
    if (!mounted) return;
    setState(() {
      _unreadNotificationBadge = count;
      _lastUnreadNotifications = count;
    });
    unawaited(_syncAppIconBadge(count));
  }

  void _handleOpenStoryFromNotification(int storyId) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = 0;
      _pendingStoryNotificationId = storyId;
    });
  }

  void _handleScroll() {
    final direction = _scrollController.position.userScrollDirection;

    if (direction == ScrollDirection.reverse && _showTopBar) {
      setState(() => _showTopBar = false);
    } else if (direction == ScrollDirection.forward && !_showTopBar) {
      setState(() => _showTopBar = true);
    }
  }

  void _openCreatePost(BuildContext context) {
    if (_isAccessRestricted()) {
      _showAccessRestrictedMessage(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostScreen()),
    ).then((value) {
      if (value is Map) {
        final payload = Map<String, dynamic>.from(value);
        _homeFeedKey.currentState?.refreshAfterPost(
          newPost: payload['post'] is Map
              ? Map<String, dynamic>.from(payload['post'] as Map)
              : null,
          scheduledAt: payload['scheduled_at']?.toString(),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post published')));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationPoller?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pollNotifications(playSound: false));
      _homeFeedKey.currentState?.softRefresh();
    }
  }

  Future<void> _initNotificationSoundPolling() async {
    final localSoundEnabled = await AuthSession.getNotificationSoundEnabled();
    try {
      final prefs = await HomeApiService.fetchNotificationPreferences();
      _notificationSoundEnabled =
          localSoundEnabled && prefs['in_app_enabled'] != false;
    } catch (_) {
      _notificationSoundEnabled = localSoundEnabled;
    }
    await _pollNotifications(playSound: false);
    _notificationPoller = Timer.periodic(const Duration(seconds: 12), (_) {
      _pollNotifications(playSound: true);
    });
  }

  Future<void> _pollNotifications({required bool playSound}) async {
    if (!mounted || _notificationPolling) return;
    _notificationPolling = true;
    try {
      final unread = await HomeApiService.fetchUnreadNotificationsCount();
      final unreadSupport =
          await HomeApiService.fetchUnreadSupportNotificationsCount() ??
          _unreadSupportBadge;
      final unreadMessages =
          await HomeApiService.fetchUnreadMessageThreadsCount() ??
          _unreadMessageBadge;
      if (unread == null) return;
      if (_notificationSoundEnabled &&
          _notificationBaselineReady &&
          playSound &&
          (unread > _lastUnreadNotifications ||
              unreadMessages > _unreadMessageBadge)) {
        SystemSound.play(SystemSoundType.alert);
      }
      _lastUnreadNotifications = unread;
      _unreadNotificationBadge = unread;
      _unreadMessageBadge = unreadMessages;
      _unreadSupportBadge = unreadSupport;
      _notificationBaselineReady = true;
      await _syncAppIconBadge(unread);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Silence polling errors; this should never block app usage.
    } finally {
      _notificationPolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactNav = !Platform.isIOS && screenWidth < 390;
    final navFontSize = !Platform.isIOS && screenWidth < 360 ? 8.2 : 9.4;
    final pages = <Widget>[
      _HomeFeedPage(
        key: _homeFeedKey,
        controller: _scrollController,
        initialStoryId: _pendingStoryNotificationId,
        onInitialStoryOpened: () {
          if (!mounted) return;
          setState(() => _pendingStoryNotificationId = null);
        },
      ),
      _networkPage,
      _mentorshipPage,
      _jobsPage,
      _notificationsPage,
      _fundingPage,
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawerEdgeDragWidth: 0,
      drawer: const _ProfileDrawer(),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Stack(
            children: [
              // FEED
              Positioned.fill(
                top: _showTopBar ? _topBarHeight : 0,
                child: IndexedStack(index: _selectedIndex, children: pages),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                top: _showTopBar ? 0 : -_topBarHeight,
                left: 0,
                right: 0,
                height: _topBarHeight,
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (ctx) => _HomeTopBar(
                          openDrawer: () => Scaffold.of(ctx).openDrawer(),
                          previewAsAlumni: _previewAsAlumni,
                          unreadMessageCount: _unreadMessageBadge,
                          onOpenPost: () => _openCreatePost(ctx),
                          onOpenSearch: () {
                            if (_isAccessRestricted()) {
                              _showAccessRestrictedMessage(ctx);
                              return;
                            }
                            Navigator.of(ctx).pushNamed('/search');
                          },
                          onOpenMessages: () async {
                            if (_isAccessRestricted()) {
                              _showAccessRestrictedMessage(ctx);
                              return;
                            }
                            if (!mounted) return;
                            setState(() => _unreadMessageBadge = 0);
                            await Navigator.of(ctx).pushNamed('/messages');
                            await _pollNotifications(playSound: false);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: isCompactNav ? 68 : 70,
          labelTextStyle: MaterialStatePropertyAll(
            TextStyle(fontSize: navFontSize, fontWeight: FontWeight.w600),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            if (_isAccessRestricted() && index != 0) {
              _showAccessRestrictedMessage(context);
              return;
            }
            setState(() {
              _selectedIndex = index;
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 22),
              selectedIcon: Icon(Icons.home_rounded, size: 24),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined, size: 22),
              selectedIcon: Icon(Icons.group_rounded, size: 24),
              label: 'Network',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined, size: 22),
              selectedIcon: Icon(Icons.handshake_rounded, size: 24),
              label: isCompactNav ? 'Mentors' : 'Mentorship',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline_rounded, size: 22),
              selectedIcon: Icon(Icons.work_rounded, size: 24),
              label: 'Jobs',
            ),
            NavigationDestination(
              icon: _NotificationNavIcon(
                unreadCount: _unreadNotificationBadge,
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
              ),
              selectedIcon: _NotificationNavIcon(
                unreadCount: _unreadNotificationBadge,
                icon: const Icon(Icons.notifications_rounded, size: 24),
              ),
              label: isCompactNav ? 'Alerts' : 'Notifications',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined, size: 22),
              selectedIcon: Icon(Icons.storefront_rounded, size: 24),
              label: isCompactNav ? 'Funds' : 'Funding',
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== TOP BAR =====================

class _HomeTopBar extends StatelessWidget {
  final VoidCallback openDrawer;
  final bool previewAsAlumni;
  final int unreadMessageCount;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenPost;
  final VoidCallback onOpenSearch;

  const _HomeTopBar({
    required this.openDrawer,
    required this.onOpenMessages,
    required this.onOpenPost,
    required this.onOpenSearch,
    this.previewAsAlumni = false,
    this.unreadMessageCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 380;
    final actionSize = isCompact ? 34.0 : 40.0;
    final brandIconSize = isCompact ? 24.0 : 28.0;
    final subtitleOffset = isCompact ? 28.0 : 36.0;
    final subtitleText = previewAsAlumni
        ? 'Alumni preview enabled'
        : 'Your alumni circle';

    return Container(
      margin: EdgeInsets.fromLTRB(16, isCompact ? 6 : 10, 16, 10),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(
          theme.brightness == Brightness.dark ? 0.92 : 0.94,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _topActionTile(
            onTap: openDrawer,
            icon: Icons.menu_rounded,
            size: actionSize,
            background: theme.brightness == Brightness.dark
                ? scheme.surfaceContainerHighest
                : const Color(0xFFEEF2FF),
          ),
          SizedBox(width: isCompact ? 6 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: brandIconSize,
                      height: brandIconSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    SizedBox(width: isCompact ? 5 : 8),
                    Flexible(
                      child: Text(
                        'Alumni Global',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: isCompact ? 13 : null,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 0 : 2),
                Padding(
                  padding: EdgeInsets.only(left: subtitleOffset),
                  child: Text(
                    subtitleText,
                    maxLines: isCompact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: isCompact ? 10.5 : null,
                      height: isCompact ? 1.0 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isCompact ? 2 : 6),
          _topActionTile(
            onTap: onOpenPost,
            icon: Icons.add_box_outlined,
            size: actionSize,
          ),
          SizedBox(width: isCompact ? 2 : 6),
          _topActionTile(
            onTap: onOpenSearch,
            icon: Icons.search_rounded,
            size: actionSize,
          ),
          SizedBox(width: isCompact ? 2 : 6),
          InkWell(
            onTap: onOpenMessages,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: actionSize,
              height: actionSize,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Center(
                child: _NotificationNavIcon(
                  unreadCount: unreadMessageCount,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topActionTile({
    required VoidCallback onTap,
    required IconData icon,
    Color? background,
    double size = 42,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: const Color(0xFF1D4ED8), size: size * 0.52),
      ),
    );
  }
}

class _NotificationNavIcon extends StatelessWidget {
  final int unreadCount;
  final Widget icon;

  const _NotificationNavIcon({required this.unreadCount, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return icon;
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== PROFILE DRAWER =====================

class _ProfileDrawer extends StatefulWidget {
  const _ProfileDrawer();

  @override
  State<_ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<_ProfileDrawer> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  Map<String, dynamic>? _metrics;
  int _scheduledCount = 0;
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  int _unreadSupport = 0;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadAnalytics();
    _loadScheduledCount();
    _loadDrawerBadges();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMe() async {
    final user = await HomeApiService.fetchMe();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _loadAnalytics() async {
    final metrics = await HomeApiService.fetchUserAnalytics();
    if (!mounted) return;
    setState(() => _metrics = metrics);
  }

  Future<void> _loadScheduledCount() async {
    final data = await HomeApiService.fetchScheduledPosts(page: 1, perPage: 1);
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final total = (meta?['total'] as num?)?.toInt() ?? 0;
    setState(() => _scheduledCount = total);
  }

  Future<void> _loadDrawerBadges() async {
    final unreadNotifications =
        await HomeApiService.fetchUnreadNotificationsCount() ?? 0;
    final unreadMessages =
        await HomeApiService.fetchUnreadMessageThreadsCount() ?? 0;
    final unreadSupport =
        await HomeApiService.fetchUnreadSupportNotificationsCount() ?? 0;
    if (!mounted) return;
    setState(() {
      _unreadNotifications = unreadNotifications;
      _unreadMessages = unreadMessages;
      _unreadSupport = unreadSupport;
    });
  }

  void _openAnalytics(BuildContext context) {
    Navigator.of(context).pushNamed('/analytics');
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pushNamed('/profile');
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/settings');
  }

  Future<void> _logout(BuildContext context) async {
    final biometricsEnabled = await AuthSession.getBiometricsEnabled();
    if (!biometricsEnabled) {
      try {
        await Future.wait([
          PushTokenService.unregister().timeout(const Duration(seconds: 3)),
          HomeApiService.logout().timeout(const Duration(seconds: 3)),
        ]);
      } catch (_) {
        // Local sign-out should still complete if the network is slow.
      }
      await _syncAppIconBadge(0);
      await AuthSession.clearToken();
    } else {
      await AuthSession.setBiometricLoggedOut(true);
      await _syncAppIconBadge(0);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final width = media.size.width * 0.78;
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final profile = (_user?['profile'] as Map<String, dynamic>?) ?? {};
    final avatarUrl = HomeApiService.normalizeMediaUrl(
      profile['avatar_url']?.toString() ?? _user?['avatar_url']?.toString(),
    );
    final institution = (_user?['institution'] as Map<String, dynamic>?) ?? {};
    final name = (_user?['name'] ?? '').toString();
    final headline = (profile['headline'] ?? '').toString();
    final location = (profile['location']?.toString().isNotEmpty ?? false)
        ? profile['location'].toString()
        : '';
    final school = (institution['name']?.toString().isNotEmpty ?? false)
        ? institution['name'].toString()
        : '';
    final viewers = _metrics?['profile_views_7d'] ?? 0;
    final role = (_user?['role'] ?? '').toString();
    final isSchoolAdmin = role == 'institution_admin';
    final gradYear = profile['graduation_year']?.toString() ?? '';
    final institutionId = (institution['id'] as num?)?.toInt();
    final identityLabel = isSchoolAdmin ? 'School admin' : 'Alumni member';
    final identitySubtle =
        [
          if (school.isNotEmpty) school,
          if (!isSchoolAdmin && gradYear.isNotEmpty) 'Class of $gradYear',
          if (school.isEmpty && location.isNotEmpty) location,
        ].join(' • ').trim().isNotEmpty
        ? [
            if (school.isNotEmpty) school,
            if (!isSchoolAdmin && gradYear.isNotEmpty) 'Class of $gradYear',
            if (school.isEmpty && location.isNotEmpty) location,
          ].join(' • ')
        : 'Alumni Global Network';

    final displayName = name.isNotEmpty ? name : 'User';

    return SizedBox(
      width: width,
      child: Drawer(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.only(bottom: media.padding.bottom + 16),
            children: [
              InkWell(
                onTap: () => _openProfile(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFFDBEAFE),
                          backgroundImage:
                              avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? null
                              : const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF1D4ED8),
                                  size: 32,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                identityLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (headline.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  headline,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.82),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identityLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        identitySubtle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(
                      context,
                    ).pushNamed('/home', arguments: {'tab': 2});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? scheme.surfaceContainerHighest
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF1D4ED8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mentorship is live. Reconnect with classmates, alumni mentors, and your year-group circle.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? scheme.onSurface
                                  : const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
              const SizedBox(height: 12),

              // Analytics section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _openAnalytics(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${_loading ? '' : viewers} ',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: 'profile viewers',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () =>
                          Navigator.of(context).pushNamed('/scheduled-posts'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$_scheduledCount ',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: 'scheduled posts',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _openAnalytics(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View all analytics',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Quick access',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pillWidth = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _drawerPill(
                          context,
                          icon: Icons.bookmark_border_rounded,
                          label: 'Saved posts',
                          width: pillWidth,
                          compact: isCompact,
                          badge: _scheduledCount > 0 ? _scheduledCount : null,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/saved-posts'),
                        ),
                        _drawerPill(
                          context,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Messages',
                          width: pillWidth,
                          compact: isCompact,
                          badge: _unreadMessages > 0 ? _unreadMessages : null,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/messages'),
                        ),
                        _drawerPill(
                          context,
                          icon: Icons.handshake_outlined,
                          label: 'Mentorship',
                          width: pillWidth,
                          compact: isCompact,
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed('/home', arguments: {'tab': 2}),
                        ),
                        _drawerPill(
                          context,
                          icon: Icons.support_agent_rounded,
                          label: 'Support',
                          width: pillWidth,
                          compact: isCompact,
                          badge: _unreadSupport > 0 ? _unreadSupport : null,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/support'),
                        ),
                        _drawerPill(
                          context,
                          icon: Icons.receipt_long_rounded,
                          label: 'Payments',
                          width: pillWidth,
                          compact: isCompact,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/payments'),
                        ),
                        _drawerPill(
                          context,
                          icon: Icons.notifications_none_rounded,
                          label: 'Alerts',
                          width: pillWidth,
                          compact: isCompact,
                          badge: _unreadNotifications > 0
                              ? _unreadNotifications
                              : null,
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed('/home', arguments: {'tab': 4}),
                        ),
                        if (institutionId != null)
                          _drawerPill(
                            context,
                            icon: Icons.school_outlined,
                            label: isSchoolAdmin
                                ? 'School profile'
                                : 'View school',
                            width: pillWidth,
                            compact: isCompact,
                            onTap: () => Navigator.of(context).pushNamed(
                              isSchoolAdmin
                                  ? '/institution-profile-setup'
                                  : '/institution-profile',
                              arguments: isSchoolAdmin
                                  ? null
                                  : {'id': institutionId, 'name': school},
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Settings
              ListTile(
                onTap: () => _openSettings(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(Icons.settings_rounded, color: scheme.onSurface),
                title: Text(
                  'Settings',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF241316)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF991B1B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can sign out here anytime without affecting your saved preferences.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7F1D1D),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout_rounded),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          label: const Text('Log out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    int? badge,
    required VoidCallback onTap,
    double? width,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 11 : 12,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 18, color: const Color(0xFF1D4ED8)),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -10,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 12.5 : null,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== HOME FEED =====================

class _HomeFeedPage extends StatefulWidget {
  final ScrollController controller;
  final int? initialStoryId;
  final VoidCallback? onInitialStoryOpened;

  const _HomeFeedPage({
    super.key,
    required this.controller,
    this.initialStoryId,
    this.onInitialStoryOpened,
  });

  @override
  State<_HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<_HomeFeedPage> {
  List<_FeedPost> _posts = [];
  List<_Announcement> _announcements = [];
  List<_Story> _stories = [];
  int? _currentUserId;
  bool _isSchoolAdmin = false;
  int? _institutionId;
  List<Map<String, dynamic>> _verificationRequests = [];
  bool _loadingVerifications = false;
  List<_EventCard> _events = [];
  List<Map<String, dynamic>> _recommendedPosts = [];
  final Map<int, int> _recommendationIdsByPost = {};
  _Ad? _feedAd;
  _Ad? _storyAd;
  _Ad? _bannerAd;
  final Set<int> _hiddenAdIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _offline = false;
  bool _hasMore = true;
  int _page = 1;
  int? _lastAutoOpenedStoryId;

  bool _isNetworkError(Object error) {
    return error is SocketException || error is TimeoutException;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  _FeedPost _feedPostFromItem(Map<String, dynamic> item) {
    final user = _asMap(item['user']);
    final createdAt = item['created_at']?.toString();
    final media = _asMapList(item['media']);
    final counts = _asMap(item['counts']);
    final avatar = HomeApiService.normalizeMediaUrl(
      user['avatar_url']?.toString(),
    );
    return _FeedPost(
      id: _asInt(item['id']) ?? 0,
      recommendationId: _recommendationIdsByPost[_asInt(item['id']) ?? 0],
      userId: _asInt(user['id']) ?? 0,
      name: (user['name']?.toString().isNotEmpty ?? false)
          ? user['name'].toString()
          : '',
      avatarUrl: avatar,
      subtitle: '',
      timeAgo: _timeAgo(createdAt),
      text: (item['content']?.toString().isNotEmpty ?? false)
          ? item['content'].toString()
          : '',
      media: media,
      commentCount: _asInt(counts['comments']) ?? 0,
      reactionCount: _asInt(counts['reactions']) ?? 0,
      isSaved: item['is_saved'] == true,
      isLiked: item['is_liked'] == true,
      reactionType: item['user_reaction']?.toString(),
      isSystem: false,
    );
  }

  _Story _storyFromMap(Map<String, dynamic> item) {
    final user = _asMap(item['user']);
    final mediaList = _asMapList(item['media']);
    final firstMedia = mediaList.isNotEmpty ? mediaList.first : null;
    final rawUrl = firstMedia?['url']?.toString();
    final rawThumb = firstMedia?['thumbnail_url']?.toString();
    final mediaType = firstMedia?['type']?.toString();
    final userId = _asInt(user['id']);
    return _Story(
      id: _asInt(item['id']),
      userId: userId,
      userName: (user['name'] ?? '').toString(),
      isYourStory: _currentUserId != null && userId == _currentUserId,
      mediaUrl: _resolveMediaUrl(rawUrl ?? rawThumb),
      thumbnailUrl: _resolveMediaUrl(rawThumb ?? rawUrl),
      avatarUrl: HomeApiService.normalizeMediaUrl(
        user['avatar_url']?.toString(),
      ),
      mediaType: mediaType,
    );
  }

  @override
  void initState() {
    super.initState();
    _applyCachedFeed();
    _loadFeed();
    widget.controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HomeFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStoryId != oldWidget.initialStoryId) {
      _maybeOpenInitialStory();
    }
  }

  Future<void> _applyCachedFeed() async {
    final cachedFeed = HomeApiService.getCachedFeed();
    if (cachedFeed.isEmpty) return;
    final cachedStories = HomeApiService.getCachedStories();
    final cachedEvents = HomeApiService.getCachedEvents();
    final currentUserId = await AuthSession.getUserId();
    if (!mounted) return;
    final posts = _asMapList(cachedFeed['posts']);
    final announcements = _asMapList(cachedFeed['announcements']);
    setState(() {
      _currentUserId = currentUserId;
      _posts = posts.map(_feedPostFromItem).toList();
      final presentPostIds = _posts.map((p) => p.id).toSet();
      final pendingPosts = HomeApiService.getPendingPosts();
      final remainingPending = <Map<String, dynamic>>[];
      for (final pending in pendingPosts) {
        final pendingId = _asInt(pending['id']);
        if (pendingId == null || presentPostIds.contains(pendingId)) continue;
        remainingPending.add(pending);
        _posts.insert(0, _feedPostFromItem(pending));
      }
      HomeApiService.setPendingPosts(remainingPending);
      _announcements = announcements.map((item) {
        return _Announcement(
          title: (item['title'] ?? '').toString(),
          body: (item['body'] ?? '').toString(),
        );
      }).toList();
      _stories = cachedStories.map(_storyFromMap).toList();
      final pendingStories = HomeApiService.getPendingStories();
      final storyIds = _stories.map((s) => s.id).whereType<int>().toSet();
      final remainingStories = <Map<String, dynamic>>[];
      for (final pending in pendingStories) {
        final pendingId = _asInt(pending['id']);
        if (pendingId == null || storyIds.contains(pendingId)) continue;
        remainingStories.add(pending);
        _stories.insert(0, _storyFromMap(pending));
      }
      HomeApiService.setPendingStories(remainingStories);
      _recommendedPosts = const [];
      _events = cachedEvents.map((item) {
        final startsAt = item['starts_at']?.toString();
        return _EventCard(
          id: _asInt(item['id']) ?? 0,
          title: (item['title'] ?? '').toString(),
          date: _formatDate(startsAt),
          location: (item['location'] ?? item['meeting_url'] ?? '').toString(),
          raw: Map<String, dynamic>.from(item),
        );
      }).toList();
      _loading = false;
    });
    _maybeOpenInitialStory();
  }

  Future<void> softRefresh() async {
    if (_loading || _refreshing) return;
    setState(() => _refreshing = true);
    await _loadFeed();
  }

  void refreshAfterPost({Map<String, dynamic>? newPost, String? scheduledAt}) {
    if (!mounted) return;
    if (newPost != null) {
      if (scheduledAt != null) {
        final scheduled = DateTime.tryParse(scheduledAt);
        if (scheduled != null && scheduled.isAfter(DateTime.now())) {
          setState(() => _refreshing = false);
          return;
        }
      }
      final normalizedPost = _asMap(newPost);
      final createdAt = normalizedPost['created_at']?.toString();
      final user = _asMap(normalizedPost['user']);
      final media = _asMapList(normalizedPost['media']);
      final counts = _asMap(normalizedPost['counts']);
      final avatar = HomeApiService.normalizeMediaUrl(
        user['avatar_url']?.toString(),
      );
      final post = _FeedPost(
        id: _asInt(normalizedPost['id']) ?? 0,
        userId: _asInt(user['id']) ?? 0,
        name: (user['name']?.toString().isNotEmpty ?? false)
            ? user['name'].toString()
            : '',
        avatarUrl: avatar,
        subtitle: '',
        timeAgo: _timeAgo(createdAt),
        text: (normalizedPost['content']?.toString().isNotEmpty ?? false)
            ? normalizedPost['content'].toString()
            : '',
        media: media,
        commentCount: _asInt(counts['comments']) ?? 0,
        reactionCount: _asInt(counts['reactions']) ?? 0,
        isSaved: normalizedPost['is_saved'] == true,
        isLiked: normalizedPost['is_liked'] == true,
        reactionType: normalizedPost['user_reaction']?.toString(),
        isSystem: false,
      );
      setState(() {
        _posts.insert(0, post);
        _refreshing = false;
      });
      return;
    }
    setState(() => _refreshing = true);
    _loadFeed();
  }

  void _handleScroll() {
    if (_loadingMore || !_hasMore || _loading) return;
    if (widget.controller.position.pixels >=
        widget.controller.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    try {
      Future<T> safe<T>(Future<T> future, T fallback) async {
        try {
          return await future;
        } catch (_) {
          return fallback;
        }
      }

      final hiddenIdsFuture = safe(HomeApiService.fetchHiddenAds(), <int>[]);
      final feedFuture = HomeApiService.fetchFeed(page: 1, perPage: 10);
      final hiddenIds = await hiddenIdsFuture;
      final feed = await feedFuture;
      if (!mounted) return;
      final meta = _asMap(feed['posts_meta']);
      final lastPage = _asInt(meta['last_page']) ?? 1;

      setState(() {
        _hiddenAdIds
          ..clear()
          ..addAll(hiddenIds);
        _recommendedPosts = const [];
        _recommendationIdsByPost.clear();
        _posts = _asMapList(feed['posts']).map((item) {
          HomeApiService.cachePost(item);
          return _feedPostFromItem(item);
        }).toList();
        final presentPostIds = _posts.map((p) => p.id).toSet();
        final pendingPosts = HomeApiService.getPendingPosts();
        final remainingPending = <Map<String, dynamic>>[];
        for (final pending in pendingPosts) {
          final pendingId = _asInt(pending['id']);
          if (pendingId == null || presentPostIds.contains(pendingId)) continue;
          remainingPending.add(pending);
          _posts.insert(0, _feedPostFromItem(pending));
        }
        HomeApiService.setPendingPosts(remainingPending);
        _announcements = _asMapList(feed['announcements']).map((item) {
          return _Announcement(
            title: (item['title'] ?? '').toString(),
            body: (item['body'] ?? '').toString(),
          );
        }).toList();
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
        _offline = false;
        _page = 1;
        _hasMore = _page < lastPage;
      });
      _maybeOpenInitialStory();
      await _loadFeedSupplements(hiddenIds);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
        _offline = _isNetworkError(error);
      });
    }
  }

  Future<void> _loadFeedSupplements(List<int> hiddenIds) async {
    Future<T> safe<T>(Future<T> future, T fallback) async {
      try {
        return await future;
      } catch (_) {
        return fallback;
      }
    }

    final storyFuture = safe(
      HomeApiService.fetchStories(perPage: 20),
      <Map<String, dynamic>>[],
    );
    final meFuture = safe<Map<String, dynamic>?>(
      HomeApiService.fetchMe(),
      null,
    );
    final eventFuture = safe(
      HomeApiService.fetchEvents(perPage: 10),
      <Map<String, dynamic>>[],
    );
    final feedAdFuture = safe<Map<String, dynamic>?>(
      HomeApiService.fetchAd(placement: 'feed'),
      null,
    );
    final storyAdFuture = safe<Map<String, dynamic>?>(
      HomeApiService.fetchAd(placement: 'story'),
      null,
    );
    final bannerAdFuture = safe<Map<String, dynamic>?>(
      HomeApiService.fetchAd(placement: 'banner'),
      null,
    );

    final storyRows = await storyFuture;
    final me = await meFuture;
    if (!mounted) return;

    setState(() {
      _currentUserId = _asInt(me?['id']);
      _isSchoolAdmin = me?['role']?.toString() == 'institution_admin';
      _institutionId = _asInt(me?['institution_id']);

      _stories = storyRows.map(_storyFromMap).toList();
      final pendingStories = HomeApiService.getPendingStories();
      final storyIds = _stories.map((s) => s.id).whereType<int>().toSet();
      final remainingStories = <Map<String, dynamic>>[];
      for (final pending in pendingStories) {
        final pendingId = _asInt(pending['id']);
        if (pendingId == null || storyIds.contains(pendingId)) continue;
        remainingStories.add(pending);
        _stories.insert(0, _storyFromMap(pending));
      }
      HomeApiService.setPendingStories(remainingStories);
    });
    _maybeOpenInitialStory();

    final eventRows = await eventFuture;
    final feedAd = await feedAdFuture;
    final storyAd = await storyAdFuture;
    final bannerAd = await bannerAdFuture;
    if (!mounted) return;

    setState(() {
      if (storyAd != null) {
        final ad = _Ad.fromJson(storyAd);
        if (!hiddenIds.contains(ad.id)) {
          _stories.insert(
            0,
            _Story(
              id: null,
              userId: null,
              userName: 'Sponsored',
              isYourStory: false,
              mediaUrl: _resolveMediaUrl(storyAd['media_url']?.toString()),
              avatarUrl: null,
              mediaType: 'image',
              isAd: true,
              ad: ad,
            ),
          );
        }
      }

      _events = eventRows.map((item) {
        final startsAt = item['starts_at']?.toString();
        return _EventCard(
          id: _asInt(item['id']) ?? 0,
          title: (item['title'] ?? '').toString(),
          date: _formatDate(startsAt),
          location: (item['location'] ?? item['meeting_url'] ?? '').toString(),
          raw: Map<String, dynamic>.from(item),
        );
      }).toList();

      _feedAd = feedAd != null && !hiddenIds.contains(_asInt(feedAd['id']) ?? 0)
          ? _Ad.fromJson(feedAd)
          : null;
      _storyAd =
          storyAd != null && !hiddenIds.contains(_asInt(storyAd['id']) ?? 0)
          ? _Ad.fromJson(storyAd)
          : null;
      _bannerAd =
          bannerAd != null && !hiddenIds.contains(_asInt(bannerAd['id']) ?? 0)
          ? _Ad.fromJson(bannerAd)
          : null;
    });
    _maybeOpenInitialStory();

    if (_isSchoolAdmin && _institutionId != null) {
      _loadVerificationRequests();
    }
  }

  void _handleStoryCreated(Map<String, dynamic> story) {
    if (!mounted) return;
    setState(() {
      final newStory = _storyFromMap(story);
      _stories = [
        newStory,
        ..._stories.where((entry) => entry.id != newStory.id),
      ];
    });
  }

  void _handleStoryDeleted(_Story story) {
    if (!mounted) return;
    setState(() {
      if (story.id != null) {
        HomeApiService.removePendingStory(story.id!);
        _stories.removeWhere((entry) => entry.id == story.id);
      }
    });
  }

  void _openStoryFromNotification(_Story story) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _StoryViewer(stories: [story], onDeleted: _handleStoryDeleted),
    );
  }

  void _maybeOpenInitialStory() {
    final storyId = widget.initialStoryId;
    if (!mounted || storyId == null) return;
    if (_lastAutoOpenedStoryId == storyId) return;
    _Story? match;
    for (final story in _stories) {
      if (story.id == storyId) {
        match = story;
        break;
      }
    }
    if (match == null) return;
    _lastAutoOpenedStoryId = storyId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openStoryFromNotification(match!);
      widget.onInitialStoryOpened?.call();
    });
  }

  Future<void> _loadVerificationRequests() async {
    if (_institutionId == null) return;
    setState(() => _loadingVerifications = true);
    try {
      final rows = await HomeApiService.fetchVerificationRequests(
        status: 'pending',
        institutionId: _institutionId,
        page: 1,
        perPage: 5,
      );
      if (!mounted) return;
      setState(() => _verificationRequests = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _verificationRequests = []);
    } finally {
      if (!mounted) return;
      setState(() => _loadingVerifications = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    try {
      final feed = await HomeApiService.fetchFeed(page: nextPage, perPage: 10);
      if (!mounted) return;
      final meta = _asMap(feed['posts_meta']);
      final lastPage = _asInt(meta['last_page']) ?? nextPage;
      final morePosts = _asMapList(feed['posts']).map((item) {
        HomeApiService.cachePost(item);
        return _feedPostFromItem(item);
      }).toList();

      setState(() {
        _posts.addAll(morePosts);
        _loadingMore = false;
        _page = nextPage;
        _hasMore = _page < lastPage;
        _offline = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _offline = _isNetworkError(error);
      });
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _loadingCard({double height = 78}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 180,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(height: height < 70 ? 0 : 6),
          ],
        ),
      ),
    );
  }

  Widget _offlineBanner({required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFED7AA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You look offline. Showing cached content.',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  String? _resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final base = Uri.parse(ApiConfig.baseUrl);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return url;
      final host = uri.host;
      if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
        return uri
            .replace(
              scheme: base.scheme,
              host: base.host,
              port: base.hasPort ? base.port : null,
            )
            .toString();
      }
      return url;
    }
    if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
    return '${ApiConfig.baseUrl}/$url';
  }

  @override
  Widget build(BuildContext context) {
    final adFrequency = 4;
    final feedCards = <Widget>[];
    if (!_loading) {
      for (var i = 0; i < _posts.length; i++) {
        feedCards.add(
          _FeedPostCard(
            key: ValueKey('feed_post_${_posts[i].id}'),
            post: _posts[i],
            onHidden: () {
              setState(() => _posts.removeAt(i));
            },
          ),
        );
        if (_feedAd != null && (i + 1) % adFrequency == 0) {
          feedCards.add(
            _AdCard(
              ad: _feedAd!,
              compact: true,
              onHide: () => _hideAd(_feedAd!.id),
              onReport: () => _reportAd(_feedAd!),
            ),
          );
        }
      }
      if (feedCards.isEmpty) {
        feedCards.add(const _EmptyFeedCard());
      }
    }

    final headerWidgets = <Widget>[
      if (_offline) _offlineBanner(onRetry: _loadFeed),
      if (_refreshing) const _ShimmerCard(),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? const LinearGradient(
                  colors: [Color(0xFF111827), Color(0xFF172554)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community snapshots',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2563EB),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stories, updates, and event highlights from your network.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            _StoriesBar(
              stories: [
                _Story(userName: 'You', isYourStory: true),
                ..._stories,
              ],
              onRefresh: _loadFeed,
              onStoryCreated: _handleStoryCreated,
              onStoryDeleted: _handleStoryDeleted,
              onAdOptions: (ad) => _showAdOptions(ad),
            ),
          ],
        ),
      ),
      if (_isSchoolAdmin)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pending verifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_loadingVerifications)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_loadingVerifications && _verificationRequests.isEmpty)
                  const Text('No pending alumni requests right now.'),
                if (_verificationRequests.isNotEmpty)
                  Column(
                    children: _verificationRequests.map((row) {
                      final user = (row['user'] as Map<String, dynamic>?) ?? {};
                      final name = (user['name'] ?? 'Alumni').toString();
                      final email = (user['email'] ?? '').toString();
                      final userId = (user['id'] as num?)?.toInt();
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: userId == null
                                  ? null
                                  : () async {
                                      final ok =
                                          await HomeApiService.verifyProfile(
                                            userId,
                                          );
                                      if (!mounted) return;
                                      if (ok) {
                                        setState(
                                          () =>
                                              _verificationRequests.remove(row),
                                        );
                                      }
                                    },
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: userId == null
                                  ? null
                                  : () async {
                                      final ok =
                                          await HomeApiService.rejectProfile(
                                            userId,
                                          );
                                      if (!mounted) return;
                                      if (ok) {
                                        setState(
                                          () =>
                                              _verificationRequests.remove(row),
                                        );
                                      }
                                    },
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      _loading
          ? _loadingCard()
          : (_announcements.isEmpty
                ? const SizedBox.shrink()
                : _AnnouncementSection(announcements: _announcements)),
      if (_bannerAd != null)
        _AdBanner(
          ad: _bannerAd!,
          onHide: () => _hideAd(_bannerAd!.id),
          onReport: () => _reportAd(_bannerAd!),
        ),
      _loading
          ? _loadingCard()
          : (_events.isEmpty
                ? const SizedBox.shrink()
                : _EventsSection(events: _events)),
    ];
    final headerCount = headerWidgets.length;
    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.separated(
        controller: widget.controller,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.sizeOf(context).width < 380 ? 18 : 14,
          16,
          16,
        ),
        itemCount: _loading
            ? 6
            : headerCount + feedCards.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index < headerWidgets.length) {
            return headerWidgets[index];
          }
          if (_loading) {
            return _loadingCard(height: 92);
          }
          final feedIndex = index - headerCount;
          if (feedIndex >= feedCards.length) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return feedCards[feedIndex];
        },
      ),
    );
  }

  void _hideAd(int adId) {
    setState(() {
      _hiddenAdIds.add(adId);
      if (_feedAd?.id == adId) _feedAd = null;
      if (_bannerAd?.id == adId) _bannerAd = null;
      if (_storyAd?.id == adId) {
        _storyAd = null;
        _stories.removeWhere((story) => story.isAd && story.ad?.id == adId);
      }
    });
    HomeApiService.hideAd(adId);
  }

  Future<void> _reportAd(_Ad ad) async {
    final ok = await HomeApiService.createSupportTicket(
      subject: 'Report sponsored content',
      message: 'User reported ad "${ad.title}" (id ${ad.id}).',
      category: 'ads',
      priority: 'medium',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Ad reported. Thank you.' : 'Unable to report ad.'),
      ),
    );
  }

  void _showAdOptions(_Ad ad) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.report_gmailerrorred),
            title: const Text('Report ad'),
            onTap: () {
              Navigator.of(context).pop();
              _reportAd(ad);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hide ad'),
            onTap: () {
              Navigator.of(context).pop();
              _hideAd(ad.id);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------- STORIES ----------------

class _Story {
  final int? id;
  final int? userId;
  final String userName;
  final bool isYourStory;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? avatarUrl;
  final String? mediaType;
  final bool isAd;
  final _Ad? ad;

  _Story({
    this.id,
    this.userId,
    required this.userName,
    this.isYourStory = false,
    this.mediaUrl,
    this.thumbnailUrl,
    this.avatarUrl,
    this.mediaType,
    this.isAd = false,
    this.ad,
  });
}

class _StoryStripItem {
  final _Story story;
  final int count;
  final List<_Story> stories;

  const _StoryStripItem({
    required this.story,
    this.count = 1,
    this.stories = const [],
  });
}

class _Announcement {
  final String title;
  final String body;

  _Announcement({required this.title, required this.body});
}

class _EventCard {
  final int id;
  final String title;
  final String date;
  final String location;
  final Map<String, dynamic> raw;

  _EventCard({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.raw,
  });
}

class _AnnouncementSection extends StatelessWidget {
  final List<_Announcement> announcements;

  const _AnnouncementSection({required this.announcements});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HomeSectionHeader(
          eyebrow: 'From your network',
          title: 'Announcements',
          subtitle: 'Important updates worth catching before they get buried.',
        ),
        const SizedBox(height: 12),
        ...announcements.map(
          (a) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Announcement',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  a.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.body,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendedPostsSection extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final void Function(int postId, int? recommendationId) onOpen;
  final void Function(int? recommendationId) onDismiss;

  const _RecommendedPostsSection({
    required this.posts,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI recommendations',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final entry = posts[index];
              final post = (entry['post'] as Map<String, dynamic>?) ?? {};
              final user = (post['user'] as Map<String, dynamic>?) ?? {};
              final postId = (post['id'] as num?)?.toInt() ?? 0;
              final recId = (entry['recommendation_id'] as num?)?.toInt();
              final reason = (entry['reason'] ?? '').toString();
              final content = (post['content'] ?? '').toString();
              final name = (user['name'] ?? 'Member').toString();
              return GestureDetector(
                onTap: () => onOpen(postId, recId),
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.black54,
                            ),
                            onPressed: () => onDismiss(recId),
                            tooltip: 'Not interested',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          content.isEmpty ? 'View post' : content,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (reason.isNotEmpty)
                        Text(
                          'Why: $reason',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'Open post',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventsSection extends StatelessWidget {
  final List<_EventCard> events;

  const _EventsSection({required this.events});

  Future<void> _openEvent(BuildContext context, _EventCard event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: event.raw)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final cardWidth = math.min(
      math.max(
        screenWidth * (isCompact ? 0.52 : 0.58),
        isCompact ? 176.0 : 196.0,
      ),
      isCompact ? 196.0 : 224.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _HomeSectionHeader(
                eyebrow: 'Keep showing up',
                title: 'Alumni events',
                subtitle:
                    'Reunions, mixers, and moments your alumni community is showing up for next.',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/events'),
              child: const Text('View all'),
            ),
          ],
        ),
        SizedBox(
          height: isCompact ? 128 : 144,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final event = events[i];
              return InkWell(
                onTap: () => _openEvent(context, event),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: cardWidth,
                  padding: EdgeInsets.all(isCompact ? 11 : 13),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Event',
                          style: TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 8 : 10),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isCompact ? 14 : 15,
                          height: 1.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 10.5 : 11.5,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 10.5 : 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Open event',
                            style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: isCompact ? 10.5 : 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Color(0xFF1D4ED8),
                          ),
                          Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StoriesBar extends StatelessWidget {
  final List<_Story> stories;
  final VoidCallback onRefresh;
  final ValueChanged<_Ad>? onAdOptions;
  final ValueChanged<Map<String, dynamic>>? onStoryCreated;
  final ValueChanged<_Story>? onStoryDeleted;

  const _StoriesBar({
    required this.stories,
    required this.onRefresh,
    this.onAdOptions,
    this.onStoryCreated,
    this.onStoryDeleted,
  });

  List<_StoryStripItem> _storyStripItems() {
    final items = <_StoryStripItem>[];
    final grouped = <String, List<_Story>>{};

    for (final story in stories) {
      if (story.isYourStory && story.id == null) {
        items.add(_StoryStripItem(story: story, stories: [story]));
        continue;
      }
      if (story.isAd) {
        items.add(_StoryStripItem(story: story, stories: [story]));
        continue;
      }
      final key = story.userId != null
          ? 'user_${story.userId}'
          : 'story_${story.id ?? story.userName}';
      grouped.putIfAbsent(key, () => []).add(story);
    }

    for (final group in grouped.values) {
      group.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      items.add(
        _StoryStripItem(
          story: group.first,
          count: group.length,
          stories: List<_Story>.from(group),
        ),
      );
    }

    return items;
  }

  void _openStory(BuildContext context, _StoryStripItem item) {
    final story = item.story;
    if (story.isYourStory && story.id == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StoryCreateScreen()),
      ).then((value) {
        if (value is Map) {
          final payload = Map<String, dynamic>.from(value);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Story published')));
          if (onStoryCreated != null) {
            onStoryCreated!(payload);
          }
        }
      });
      return;
    }

    if (story.isAd && story.ad != null) {
      final link = story.ad!.targetUrl ?? '';
      if (link.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sponsored link not available')),
        );
      } else {
        Navigator.of(context).pushNamed(
          '/ad-webview',
          arguments: {'url': link, 'title': story.ad!.title},
        );
        HomeApiService.clickAd(story.ad!.id);
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StoryViewer(
        stories: item.stories.isEmpty ? [story] : item.stories,
        initialIndex: 0,
        onDeleted: onStoryDeleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 380;
    final stripItems = _storyStripItems();

    return SizedBox(
      height: isCompact ? 82 : 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stripItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = stripItems[index];
          final story = item.story;
          return GestureDetector(
            onTap: () => _openStory(context, item),
            onLongPress: story.isAd && story.ad != null && onAdOptions != null
                ? () => onAdOptions!(story.ad!)
                : null,
            child: Column(
              children: [
                Container(
                  width: isCompact ? 54 : 60,
                  height: isCompact ? 54 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        color: Colors.black.withOpacity(0.07),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _StoryRing(
                        active: !story.isAd,
                        isYourStory: story.isYourStory,
                        segments: story.isYourStory && story.id == null
                            ? 0
                            : math.min(math.max(item.count, 1), 8),
                      ),
                      _StoryPreviewAvatar(
                        story: story,
                        radius: isCompact ? 20 : 22,
                      ),
                      if (story.isYourStory && story.id == null)
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            width: isCompact ? 17 : 18,
                            height: isCompact ? 17 : 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                  color: const Color(
                                    0xFF1D4ED8,
                                  ).withOpacity(0.28),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: isCompact ? 10 : 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                SizedBox(
                  width: isCompact ? 64 : 72,
                  child: Text(
                    story.isYourStory && story.id == null
                        ? 'Add story'
                        : story.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isCompact ? 8.5 : 9.5,
                      fontWeight: FontWeight.w600,
                      color: story.isAd
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (item.count > 1 && !story.isAd)
                  Text(
                    '${item.count} stories',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isCompact ? 7.8 : 8.5,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (story.isAd)
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'AD',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Ad {
  final int id;
  final String title;
  final String? content;
  final String? mediaUrl;
  final String? targetUrl;
  final String placement;

  _Ad({
    required this.id,
    required this.title,
    this.content,
    this.mediaUrl,
    this.targetUrl,
    required this.placement,
  });

  factory _Ad.fromJson(Map<String, dynamic> json) {
    return _Ad(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Sponsored',
      content: json['content']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      targetUrl: json['target_url']?.toString(),
      placement: json['placement']?.toString() ?? 'feed',
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dynamic_feed_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your home feed is warming up.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Posts from your network will show here as soon as they are available.',
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _HomeSectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StoryRing extends StatelessWidget {
  final bool active;
  final bool isYourStory;
  final int segments;

  const _StoryRing({
    required this.active,
    required this.isYourStory,
    this.segments = 7,
  });

  @override
  Widget build(BuildContext context) {
    if (segments <= 0) {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD1D5DB), width: 2),
        ),
      );
    }

    return CustomPaint(
      size: const Size.square(68),
      painter: _StoryRingPainter(
        color: active
            ? (isYourStory ? const Color(0xFF4F46E5) : const Color(0xFF22C55E))
            : const Color(0xFFD1D5DB),
        mutedColor: const Color(0xFFD1D5DB),
        segments: segments,
        strokeWidth: 3.2,
      ),
    );
  }
}

class _StoryRingPainter extends CustomPainter {
  final Color color;
  final Color mutedColor;
  final int segments;
  final double strokeWidth;

  const _StoryRingPainter({
    required this.color,
    required this.mutedColor,
    required this.segments,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide / 2) - (strokeWidth / 2);
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final mutedPaint = Paint()
      ..color = mutedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const gap = 0.22;
    final sweep = ((2 * math.pi) - (segments * gap)) / segments;
    var start = -math.pi / 2;

    for (var i = 0; i < segments; i++) {
      final paint = i == segments - 1 ? mutedPaint : activePaint;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StoryRingPainter oldDelegate) {
    return color != oldDelegate.color ||
        mutedColor != oldDelegate.mutedColor ||
        segments != oldDelegate.segments ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

class _StoryPreviewAvatar extends StatelessWidget {
  final _Story story;
  final double radius;

  const _StoryPreviewAvatar({required this.story, required this.radius});

  @override
  Widget build(BuildContext context) {
    final primaryUrl = HomeApiService.normalizeMediaUrl(story.mediaUrl);
    final thumbnailUrl = HomeApiService.normalizeMediaUrl(story.thumbnailUrl);
    final fallbackUrl = HomeApiService.normalizeMediaUrl(story.avatarUrl);

    Widget placeholder() {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE5E7EB),
        ),
        child: Icon(
          story.isYourStory ? Icons.add : Icons.person_rounded,
          color: Colors.grey[700],
        ),
      );
    }

    Widget buildNetwork(String url, {String? fallback}) {
      return ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            if (fallback != null && fallback.isNotEmpty && fallback != url) {
              return buildNetwork(fallback);
            }
            return placeholder();
          },
        ),
      );
    }

    if (_isVideoMediaTypeValue(story.mediaType) &&
        primaryUrl != null &&
        primaryUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: VideoPreview.network(
            url: primaryUrl,
            fit: BoxFit.cover,
            autoplay: false,
            showPlayOverlay: false,
            fallback: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? buildNetwork(thumbnailUrl, fallback: fallbackUrl)
                : fallbackUrl != null && fallbackUrl.isNotEmpty
                ? buildNetwork(fallbackUrl)
                : placeholder(),
          ),
        ),
      );
    }

    if (primaryUrl != null && primaryUrl.isNotEmpty) {
      return buildNetwork(primaryUrl, fallback: fallbackUrl);
    }
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return buildNetwork(fallbackUrl);
    }
    return placeholder();
  }
}

class _AdCard extends StatelessWidget {
  final _Ad ad;
  final bool compact;
  final VoidCallback? onReport;
  final VoidCallback? onHide;

  const _AdCard({
    required this.ad,
    this.compact = false,
    this.onReport,
    this.onHide,
  });

  void _open(BuildContext context) {
    if (ad.targetUrl != null && ad.targetUrl!.isNotEmpty) {
      Navigator.of(context).pushNamed(
        '/ad-webview',
        arguments: {'url': ad.targetUrl, 'title': ad.title},
      );
      HomeApiService.clickAd(ad.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sponsored link not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        return GestureDetector(
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Sponsored',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'report') onReport?.call();
                              if (value == 'hide') onHide?.call();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'report',
                                child: Text('Report'),
                              ),
                              PopupMenuItem(value: 'hide', child: Text('Hide')),
                            ],
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                          ),
                        ],
                      ),
                      if (ad.mediaUrl != null && ad.mediaUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ad.mediaUrl!,
                            height: compact ? 140 : 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        ad.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (ad.content != null && ad.content!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ad.content!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Learn more',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (ad.mediaUrl != null && ad.mediaUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ad.mediaUrl!,
                            width: compact ? 70 : 90,
                            height: compact ? 70 : 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Sponsored',
                                    style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'report') onReport?.call();
                                    if (value == 'hide') onHide?.call();
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text('Report'),
                                    ),
                                    PopupMenuItem(
                                      value: 'hide',
                                      child: Text('Hide'),
                                    ),
                                  ],
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ad.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (ad.content != null &&
                                ad.content!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                ad.content!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Learn more',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _AdBanner extends StatelessWidget {
  final _Ad ad;
  final VoidCallback? onReport;
  final VoidCallback? onHide;

  const _AdBanner({required this.ad, this.onReport, this.onHide});

  void _open(BuildContext context) {
    if (ad.targetUrl != null && ad.targetUrl!.isNotEmpty) {
      Navigator.of(context).pushNamed(
        '/ad-webview',
        arguments: {'url': ad.targetUrl, 'title': ad.title},
      );
      HomeApiService.clickAd(ad.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sponsored link not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0EA5A6), Color(0xFF22C55E)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        ad.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (ad.content != null && ad.content!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ad.content!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ad.mediaUrl != null && ad.mediaUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ad.mediaUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Sponsored',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report') onReport?.call();
                  if (value == 'hide') onHide?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'report', child: Text('Report')),
                  PopupMenuItem(value: 'hide', child: Text('Hide')),
                ],
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryViewer extends StatefulWidget {
  final List<_Story> stories;
  final int initialIndex;
  final ValueChanged<_Story>? onDeleted;

  const _StoryViewer({
    required this.stories,
    this.initialIndex = 0,
    this.onDeleted,
  });

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  final TextEditingController _replyController = TextEditingController();
  bool _sendingReply = false;
  bool _deleting = false;
  late int _currentIndex;
  Timer? _storyTimer;
  double _storyProgress = 0;

  _Story get _story => widget.stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _trackView();
  }

  void _trackView() {
    if (_story.id != null) {
      HomeApiService.viewStory(_story.id!);
    }
    _restartStoryTimer();
  }

  void _showStoryAt(int index) {
    if (index < 0 || index >= widget.stories.length) return;
    setState(() {
      _currentIndex = index;
      _storyProgress = 0;
    });
    _trackView();
  }

  void _restartStoryTimer() {
    _storyTimer?.cancel();
    const totalTicks = 100;
    var tick = 0;
    _storyTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      tick += 1;
      final nextProgress = tick / totalTicks;
      if (nextProgress >= 1) {
        timer.cancel();
        if (_currentIndex < widget.stories.length - 1) {
          _showStoryAt(_currentIndex + 1);
        } else {
          Navigator.of(context).pop();
        }
        return;
      }
      setState(() => _storyProgress = nextProgress);
    });
  }

  void _openStoryShare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_story.id != null)
            ListTile(
              leading: const Icon(Icons.repeat_rounded, color: Colors.white),
              title: const Text('Repost story'),
              iconColor: Colors.white,
              textColor: Colors.white,
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await HomeApiService.repostStory(_story.id!);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Story reposted' : 'Unable to repost'),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.link_rounded, color: Colors.white),
            title: const Text('Copy link'),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () async {
              Navigator.of(context).pop();
              final link =
                  _story.mediaUrl ??
                  '${ApiConfig.baseUrl}/stories/${_story.id ?? ''}';
              await Clipboard.setData(ClipboardData(text: link));
              if (_story.id != null) {
                await HomeApiService.shareStory(
                  _story.id!,
                  channel: 'copy_link',
                );
              }
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _openStoryMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_story.isYourStory && _story.id != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white),
              title: const Text('Delete story'),
              iconColor: Colors.white,
              textColor: Colors.white,
              onTap: () {
                Navigator.of(context).pop();
                _deleteStory();
              },
            ),
          ListTile(
            leading: const Icon(
              Icons.report_gmailerrorred,
              color: Colors.white,
            ),
            title: const Text('Report'),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_off, color: Colors.white),
            title: const Text('Mute'),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_off, color: Colors.white),
            title: Text('Unfollow ${_story.userName}'),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _deleteStory() async {
    final storyId = _story.id;
    if (storyId == null || _deleting) return;
    final messenger = ScaffoldMessenger.of(context);
    final storyToDelete = _story;
    setState(() => _deleting = true);
    widget.onDeleted?.call(storyToDelete);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Deleting story...')));
    final ok = await HomeApiService.deleteStory(storyId);
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Story deleted')));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to delete story')),
      );
    }
  }

  void _sendStoryMessage(BuildContext context) {
    if (_sendingReply || _story.id == null) return;
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    _sendStoryReply(text);
  }

  Future<void> _sendStoryReply(String text) async {
    if (_story.id == null) return;
    setState(() => _sendingReply = true);
    final ok = await HomeApiService.replyToStory(
      storyId: _story.id!,
      message: text,
    );
    if (!mounted) return;
    setState(() => _sendingReply = false);
    if (ok) {
      _replyController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reply sent')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to send reply')));
    }
  }

  Future<void> _sendStoryEmoji(String emoji) async {
    if (_story.id == null) return;
    await HomeApiService.reactStory(_story.id!, emoji);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reaction sent')));
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaUrl = HomeApiService.normalizeMediaUrl(_story.mediaUrl);
    final thumbnailUrl = HomeApiService.normalizeMediaUrl(_story.thumbnailUrl);
    final avatarUrl = HomeApiService.normalizeMediaUrl(_story.avatarUrl);
    final mediaType = _story.mediaType ?? 'image';

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final width = MediaQuery.sizeOf(context).width;
                    if (details.localPosition.dx < width * 0.35) {
                      _showStoryAt(_currentIndex - 1);
                    } else {
                      _showStoryAt(_currentIndex + 1);
                    }
                  },
                  child: Center(
                    child: mediaUrl == null
                        ? _StoryViewerFallback(
                            name: _story.userName,
                            avatarUrl: avatarUrl,
                          )
                        : _isImageMediaTypeValue(mediaType)
                        ? Image.network(
                            mediaUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => _StoryViewerFallback(
                              name: _story.userName,
                              avatarUrl: avatarUrl,
                            ),
                          )
                        : VideoPreview.network(
                            url: mediaUrl,
                            fit: BoxFit.contain,
                            autoplay: true,
                            looping: true,
                            muted: false,
                            showPlayOverlay: false,
                            fallback:
                                thumbnailUrl != null && thumbnailUrl.isNotEmpty
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        thumbnailUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            _StoryViewerFallback(
                                              name: _story.userName,
                                              avatarUrl: avatarUrl,
                                            ),
                                      ),
                                      const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.4,
                                        ),
                                      ),
                                    ],
                                  )
                                : _StoryViewerFallback(
                                    name: _story.userName,
                                    avatarUrl: avatarUrl,
                                  ),
                          ),
                  ),
                ),
              ),

              // top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xCC000000), Color(0x00000000)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (widget.stories.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: List.generate(widget.stories.length, (
                                  index,
                                ) {
                                  final active = index == _currentIndex;
                                  return Expanded(
                                    child: Container(
                                      height: 3,
                                      margin: EdgeInsets.only(
                                        right:
                                            index == widget.stories.length - 1
                                            ? 0
                                            : 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: index < _currentIndex
                                            ? 1
                                            : index == _currentIndex
                                            ? _storyProgress.clamp(0, 1)
                                            : 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 2),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFE2E8F0),
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        color: Colors.black54,
                                        size: 18,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _story.userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.stories.length > 1
                                          ? 'Story ${_currentIndex + 1} of ${widget.stories.length}'
                                          : (_story.isAd
                                                ? 'Sponsored'
                                                : 'Story'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: _deleting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.more_vert_rounded,
                                        color: Colors.white,
                                      ),
                                onPressed: _deleting
                                    ? null
                                    : () => _openStoryMenu(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // bottom controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 24, 12, 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xB3000000)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Reply…',
                                    hintStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white10,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: const BorderSide(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _sendingReply
                                    ? null
                                    : () => _sendStoryMessage(context),
                                icon: _sendingReply
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _StoryReactionButton(
                                    label: '👍',
                                    onTap: () => _sendStoryEmoji('👍'),
                                  ),
                                  _StoryReactionButton(
                                    label: '🔥',
                                    onTap: () => _sendStoryEmoji('🔥'),
                                  ),
                                  _StoryReactionButton(
                                    label: '❤️',
                                    onTap: () => _sendStoryEmoji('❤️'),
                                  ),
                                  _StoryReactionButton(
                                    label: '👏',
                                    onTap: () => _sendStoryEmoji('👏'),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () => _openStoryShare(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryViewerFallback extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _StoryViewerFallback({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111827), Color(0xFF000000)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: Colors.black54,
                      size: 32,
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Story preview unavailable right now.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryReactionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _StoryReactionButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShimmerLine(widthFactor: 0.7),
            SizedBox(height: 10),
            _ShimmerLine(widthFactor: 1),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double widthFactor;

  const _ShimmerLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * widthFactor;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: -1, end: 2),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
          onEnd: () {},
          builder: (context, value, child) {
            return ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Color(0xFFE5E7EB),
                    Color(0xFFF3F4F6),
                    Color(0xFFE5E7EB),
                  ],
                  stops: const [0.1, 0.5, 0.9],
                  transform: _SlideGradient(value * rect.width),
                ).createShader(rect);
              },
              blendMode: BlendMode.srcATop,
              child: Container(
                width: width,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double slide;

  const _SlideGradient(this.slide);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(slide, 0, 0);
  }
}

// ---------------- POSTS ----------------

class _FeedPost {
  final int id;
  final int? recommendationId;
  final int userId;
  final String name;
  final String? avatarUrl;
  final String subtitle;
  final String timeAgo;
  final String text;
  final List<Map<String, dynamic>> media;
  final int commentCount;
  final int reactionCount;
  final bool isSaved;
  final bool isLiked;
  final String? reactionType;
  final bool isSystem;

  _FeedPost({
    required this.id,
    this.recommendationId,
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.subtitle,
    required this.timeAgo,
    required this.text,
    required this.media,
    required this.commentCount,
    required this.reactionCount,
    required this.isSaved,
    required this.isLiked,
    this.reactionType,
    this.isSystem = false,
  });
}

enum _Reaction { none, like, clap, fire, heart, idea }

class _FeedPostCard extends StatefulWidget {
  final _FeedPost post;
  final VoidCallback onHidden;

  const _FeedPostCard({super.key, required this.post, required this.onHidden});

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  bool _showReactions = false;
  bool _sendingLike = false;
  late int _reactionCount;
  late int _commentCount;
  late bool _isSaved;
  late _Reaction _selectedReaction;

  bool get _liked => _selectedReaction != _Reaction.none;
  bool get _isSystem => widget.post.isSystem;

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();
    _reactionCount = widget.post.reactionCount;
    _commentCount = widget.post.commentCount;
    _isSaved = widget.post.isSaved;
    _selectedReaction = _reactionFromState(
      widget.post.reactionType,
      widget.post.isLiked,
    );
  }

  @override
  void didUpdateWidget(covariant _FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.reactionCount != widget.post.reactionCount ||
        oldWidget.post.commentCount != widget.post.commentCount ||
        oldWidget.post.isSaved != widget.post.isSaved ||
        oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.reactionType != widget.post.reactionType) {
      _reactionCount = widget.post.reactionCount;
      _commentCount = widget.post.commentCount;
      _isSaved = widget.post.isSaved;
      _selectedReaction = _reactionFromState(
        widget.post.reactionType,
        widget.post.isLiked,
      );
    }
  }

  _Reaction _reactionFromState(String? type, bool isLiked) {
    final parsed = _reactionFromType(type);
    if (parsed != _Reaction.none) return parsed;
    return isLiked ? _Reaction.like : _Reaction.none;
  }

  _Reaction _reactionFromType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'heart':
        return _Reaction.heart;
      case 'clap':
        return _Reaction.clap;
      case 'fire':
        return _Reaction.fire;
      case 'idea':
        return _Reaction.idea;
      case 'like':
        return _Reaction.like;
      default:
        return _Reaction.none;
    }
  }

  String _reactionType(_Reaction reaction) {
    switch (reaction) {
      case _Reaction.like:
        return 'like';
      case _Reaction.heart:
        return 'heart';
      case _Reaction.clap:
        return 'clap';
      case _Reaction.fire:
        return 'fire';
      case _Reaction.idea:
        return 'idea';
      case _Reaction.none:
        return 'like';
    }
  }

  String _reactionLabel(_Reaction reaction) {
    switch (reaction) {
      case _Reaction.heart:
        return 'Love';
      case _Reaction.clap:
        return 'Clap';
      case _Reaction.fire:
        return 'Fire';
      case _Reaction.idea:
        return 'Insight';
      case _Reaction.like:
        return 'Like';
      case _Reaction.none:
        return 'Like';
    }
  }

  Color _reactionColor(_Reaction r) {
    switch (r) {
      case _Reaction.like:
        return const Color(0xFF2563EB); // blue
      case _Reaction.clap:
        return Colors.amber;
      case _Reaction.fire:
        return Colors.deepOrange;
      case _Reaction.heart:
        return Colors.pinkAccent;
      case _Reaction.idea:
        return Colors.teal;
      case _Reaction.none:
        return Colors.grey[600]!;
    }
  }

  double _mediaAspectRatio(Map<String, dynamic> media, int index) {
    final type = (media['type'] ?? 'image').toString().toLowerCase();
    if (type.startsWith('video')) return 16 / 9;
    final position = _toInt(media['position']) ?? index;
    switch (position % 3) {
      case 0:
        return 4 / 5;
      case 1:
        return 1;
      default:
        return 3 / 4;
    }
  }

  double _mediaWidth(double ratio, double height) {
    final width = height * ratio;
    return width.clamp(150.0, 290.0);
  }

  void _toggleReactionBar() {
    if (_isAccessRestricted()) {
      _showAccessRestrictedMessage(context);
      return;
    }
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    setState(() {
      _showReactions = true;
    });
  }

  Future<void> _toggleLike() async {
    if (_isAccessRestricted()) {
      _showAccessRestrictedMessage(context);
      return;
    }
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    if (_sendingLike) return;
    final previous = _selectedReaction;
    final wasLiked = _liked;
    final previousCount = _reactionCount;
    setState(() {
      _sendingLike = true;
      if (wasLiked) {
        _selectedReaction = _Reaction.none;
        if (_reactionCount > 0) _reactionCount -= 1;
      } else {
        _selectedReaction = _Reaction.like;
        _reactionCount += 1;
      }
      _showReactions = false;
    });
    HomeApiService.updateCachedPostState(
      widget.post.id,
      isLiked: !wasLiked,
      reactionType: !wasLiked ? _reactionType(_Reaction.like) : null,
      reactionCount: _reactionCount,
    );

    final response = wasLiked
        ? await HomeApiService.unlikePost(widget.post.id)
        : await HomeApiService.reactToPost(
            widget.post.id,
            type: _reactionType(_Reaction.like),
          );
    if (response == null && mounted) {
      setState(() {
        _selectedReaction = previous;
        _reactionCount = previousCount;
      });
      HomeApiService.updateCachedPostState(
        widget.post.id,
        isLiked: wasLiked,
        reactionType: wasLiked ? _reactionType(previous) : null,
        reactionCount: previousCount,
      );
    } else if (response != null) {
      final counts = (response['counts'] as Map?) ?? const {};
      HomeApiService.updateCachedPostState(
        widget.post.id,
        isLiked: response['is_liked'] == true,
        reactionType: response['user_reaction']?.toString(),
        reactionCount: _toInt(counts['reactions']) ?? _reactionCount,
      );
      setState(() {
        _selectedReaction = _reactionFromState(
          response['user_reaction']?.toString(),
          response['is_liked'] == true,
        );
        _reactionCount = _toInt(counts['reactions']) ?? _reactionCount;
      });
    }
    if (mounted) setState(() => _sendingLike = false);
  }

  Future<void> _selectReaction(_Reaction r) async {
    if (_isAccessRestricted()) {
      _showAccessRestrictedMessage(context);
      return;
    }
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    final previous = _selectedReaction;
    final previousCount = _reactionCount;
    final wasLiked = _liked;
    setState(() {
      _selectedReaction = r;
      _showReactions = false;
      if (!wasLiked && r != _Reaction.none) {
        _reactionCount += 1;
      }
    });
    HomeApiService.updateCachedPostState(
      widget.post.id,
      isLiked: r != _Reaction.none,
      reactionType: r != _Reaction.none ? _reactionType(r) : null,
      reactionCount: _reactionCount,
    );
    final response = r == _Reaction.none
        ? await HomeApiService.unlikePost(widget.post.id)
        : await HomeApiService.reactToPost(
            widget.post.id,
            type: _reactionType(r),
          );
    if (response == null && mounted) {
      setState(() {
        _selectedReaction = previous;
        _reactionCount = previousCount;
      });
      HomeApiService.updateCachedPostState(
        widget.post.id,
        isLiked: wasLiked,
        reactionType: wasLiked ? _reactionType(previous) : null,
        reactionCount: previousCount,
      );
      return;
    }
    final counts = (response!['counts'] as Map?) ?? const {};
    HomeApiService.updateCachedPostState(
      widget.post.id,
      isLiked: response['is_liked'] == true,
      reactionType: response['user_reaction']?.toString(),
      reactionCount: _toInt(counts['reactions']) ?? _reactionCount,
    );
    setState(() {
      _selectedReaction = _reactionFromState(
        response['user_reaction']?.toString(),
        response['is_liked'] == true,
      );
      _reactionCount = _toInt(counts['reactions']) ?? _reactionCount;
    });
  }

  String _timeAgo(String? iso) {
    if (iso == null) return 'now';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _openComments(BuildContext context) {
    if (_isAccessRestricted()) {
      _showAccessRestrictedMessage(context);
      return;
    }
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    final theme = Theme.of(context);
    String filter = 'Most relevant';
    final commentController = TextEditingController();
    bool loading = true;
    bool sending = false;
    bool didLoad = false;
    List<Map<String, dynamic>> comments = [];
    Map<String, dynamic>? replyingTo;
    List<Map<String, dynamic>> mentionableUsers = [];
    List<Map<String, dynamic>> mentionSuggestions = [];
    final Map<int, String> mentionedUsers = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          theme.bottomSheetTheme.backgroundColor ?? theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return StatefulBuilder(
              builder: (context, setLocalState) {
                Future<void> loadComments() async {
                  final rows = await HomeApiService.fetchPostComments(
                    widget.post.id,
                    perPage: 30,
                  );
                  setLocalState(() {
                    comments = rows;
                    loading = false;
                  });
                }

                Future<void> toggleCommentLike(
                  Map<String, dynamic> comment,
                ) async {
                  final commentId = _toInt(comment['id']);
                  if (commentId == null) return;
                  final wasLiked = comment['is_liked'] == true;
                  final response = wasLiked
                      ? await HomeApiService.unlikePostComment(commentId)
                      : await HomeApiService.likePostComment(commentId);
                  if (response == null) return;
                  final updated = Map<String, dynamic>.from(comment)
                    ..addAll(response);
                  final nextComments = comments.map((row) {
                    if (_toInt(row['id']) == commentId) {
                      return updated;
                    }
                    return row;
                  }).toList();
                  setLocalState(() {
                    comments = nextComments;
                  });
                }

                void refreshMentionSuggestions() {
                  mentionedUsers.removeWhere(
                    (_, name) => !commentController.text.contains('@$name'),
                  );
                  final selection = commentController.selection;
                  final cursor = selection.baseOffset >= 0
                      ? selection.baseOffset
                      : commentController.text.length;
                  final prefix = commentController.text.substring(0, cursor);
                  final match = RegExp(
                    r'(?:^|\s)@([^\s@]*)$',
                  ).firstMatch(prefix);
                  if (match == null) {
                    mentionSuggestions = [];
                    return;
                  }
                  final query = (match.group(1) ?? '').trim().toLowerCase();
                  mentionSuggestions = mentionableUsers
                      .where((user) {
                        final name = (user['name'] ?? '').toString().trim();
                        if (name.isEmpty) return false;
                        final userId = _toInt(user['id']);
                        if (userId != null &&
                            mentionedUsers.containsKey(userId)) {
                          return false;
                        }
                        if (query.isEmpty) return true;
                        final lowered = name.toLowerCase();
                        return lowered.startsWith(query) ||
                            lowered.contains(query);
                      })
                      .take(6)
                      .toList();
                }

                Future<void> loadMentionableUsers() async {
                  final rows = await HomeApiService.fetchMentionableUsers();
                  setLocalState(() {
                    mentionableUsers = rows;
                    refreshMentionSuggestions();
                  });
                }

                void insertMention(Map<String, dynamic> user) {
                  final userId = _toInt(user['id']);
                  final name = (user['name'] ?? '').toString().trim();
                  if (userId == null || name.isEmpty) return;
                  final selection = commentController.selection;
                  final cursor = selection.baseOffset >= 0
                      ? selection.baseOffset
                      : commentController.text.length;
                  final prefix = commentController.text.substring(0, cursor);
                  final match = RegExp(
                    r'(?:^|\s)@([^\s@]*)$',
                  ).firstMatch(prefix);
                  if (match == null) return;
                  final mentionStart =
                      match.start + (prefix[match.start] == ' ' ? 1 : 0);
                  final replacement = '@$name ';
                  final nextText =
                      commentController.text.substring(0, mentionStart) +
                      replacement +
                      commentController.text.substring(cursor);
                  commentController.value = TextEditingValue(
                    text: nextText,
                    selection: TextSelection.collapsed(
                      offset: mentionStart + replacement.length,
                    ),
                  );
                  mentionedUsers[userId] = name;
                  setLocalState(() => mentionSuggestions = []);
                }

                Future<void> sendComment() async {
                  final content = commentController.text.trim();
                  if (content.isEmpty || sending) return;
                  final replyTarget = replyingTo;
                  final mentionIds = mentionedUsers.entries
                      .where(
                        (entry) =>
                            commentController.text.contains('@${entry.value}'),
                      )
                      .map((entry) => entry.key)
                      .toList();
                  setLocalState(() => sending = true);
                  final ok = await HomeApiService.addPostComment(
                    widget.post.id,
                    content,
                    parentId: _toInt(replyTarget?['id']),
                    mentions: mentionIds,
                  );
                  if (ok) {
                    commentController.clear();
                    setLocalState(() {
                      replyingTo = null;
                      mentionSuggestions = [];
                      mentionedUsers.clear();
                    });
                    if (mounted) setState(() => _commentCount += 1);
                    HomeApiService.updateCachedPostState(
                      widget.post.id,
                      commentCount: _commentCount,
                    );
                    await loadComments();
                  }
                  setLocalState(() => sending = false);
                }

                if (!didLoad) {
                  didLoad = true;
                  loadComments();
                  loadMentionableUsers();
                  commentController.addListener(() {
                    setLocalState(() => refreshMentionSuggestions());
                  });
                }

                final keyboardInset = math.max(
                  MediaQuery.viewInsetsOf(context).bottom,
                  MediaQuery.viewInsetsOf(ctx).bottom,
                );

                return AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + keyboardInset),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Comments',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          DropdownButton<String>(
                            value: filter,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: 'Most relevant',
                                child: Text('Most relevant'),
                              ),
                              DropdownMenuItem(
                                value: 'All comments',
                                child: Text('All comments'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setLocalState(() => filter = value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // comments list
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : comments.isEmpty
                            ? Center(
                                child: Text(
                                  'No comments yet',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: comments.length,
                                itemBuilder: (_, i) {
                                  final comment = comments[i];
                                  final user =
                                      (comment['user']
                                          as Map<String, dynamic>?) ??
                                      {};
                                  final createdAt = comment['created_at']
                                      ?.toString();
                                  final name = (user['name'] ?? 'User')
                                      .toString();
                                  final avatarUrl =
                                      HomeApiService.normalizeMediaUrl(
                                        user['avatar_url']?.toString(),
                                      );
                                  final timeAgo = _timeAgo(createdAt);
                                  final parentId = _toInt(comment['parent_id']);
                                  final parentComment = parentId == null
                                      ? null
                                      : comments
                                            .cast<Map<String, dynamic>?>()
                                            .firstWhere(
                                              (row) =>
                                                  _toInt(row?['id']) ==
                                                  parentId,
                                              orElse: () => null,
                                            );
                                  final replyName =
                                      ((parentComment?['user']
                                                  as Map<
                                                    String,
                                                    dynamic
                                                  >?)?['name'] ??
                                              '')
                                          .toString();
                                  return Dismissible(
                                    key: ValueKey(
                                      'feed_comment_${widget.post.id}_${comment['id']}',
                                    ),
                                    direction: DismissDirection.startToEnd,
                                    confirmDismiss: (_) async {
                                      setLocalState(() => replyingTo = comment);
                                      commentController.text = '@$name ';
                                      commentController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset:
                                                  commentController.text.length,
                                            ),
                                          );
                                      return false;
                                    },
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 12),
                                      child: const Icon(
                                        Icons.reply_rounded,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: parentId == null ? 0 : 18,
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(
                                            0xFFE5E7EB,
                                          ),
                                          backgroundImage:
                                              avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child:
                                              avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? null
                                              : const Icon(
                                                  Icons.person_rounded,
                                                  size: 18,
                                                  color: Color(0xFF4B5563),
                                                ),
                                        ),
                                        title: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (replyName.isNotEmpty)
                                              Text(
                                                'Replying to $replyName',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: const Color(
                                                        0xFF2563EB,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            Text(
                                              comment['content']?.toString() ??
                                                  '',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          '$name • $timeAgo',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        trailing: Builder(
                                          builder: (_) {
                                            final counts =
                                                (comment['counts'] as Map?) ??
                                                const {};
                                            final likeCount =
                                                _toInt(counts['likes']) ?? 0;
                                            final isLiked =
                                                comment['is_liked'] == true;
                                            return Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  onTap: () =>
                                                      toggleCommentLike(
                                                        comment,
                                                      ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 4,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isLiked
                                                              ? Icons
                                                                    .favorite_rounded
                                                              : Icons
                                                                    .favorite_border_rounded,
                                                          size: 16,
                                                          color: isLiked
                                                              ? const Color(
                                                                  0xFFEF4444,
                                                                )
                                                              : theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                        ),
                                                        if (likeCount > 0) ...[
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            '$likeCount',
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      if (replyingTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Replying to ${(((replyingTo!['user'] as Map<String, dynamic>?)?['name']) ?? 'comment').toString()}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setLocalState(() => replyingTo = null);
                                  commentController.clear();
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ),
                      if (mentionSuggestions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MentionSuggestionBox(
                            users: mentionSuggestions,
                            onSelected: insertMention,
                          ),
                        ),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFE5E7EB),
                            child: Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              scrollPadding: EdgeInsets.only(
                                bottom: keyboardInset + 24,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Add a comment…',
                                filled: true,
                                fillColor: theme.cardColor,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                  borderSide: BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: sending ? null : sendComment,
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openPostDetail() {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    if (widget.post.recommendationId != null) {
      HomeApiService.sendRecommendationFeedback(
        recommendationId: widget.post.recommendationId!,
        action: 'clicked',
      );
    }
    Navigator.of(context).pushNamed('/post-detail', arguments: widget.post.id);
  }

  void _openUserProfile() {
    if (widget.post.userId == 0) return;
    Navigator.of(
      context,
    ).pushNamed('/user-profile', arguments: {'id': widget.post.userId});
  }

  void _openShare(BuildContext context) {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Copy link'),
            onTap: () async {
              Navigator.of(context).pop();
              await _onShareViaPost();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Linking post options
  void _onSavePost() {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    if (_isSaved) {
      HomeApiService.unsavePost(widget.post.id).then((ok) {
        if (ok) {
          setState(() => _isSaved = false);
          HomeApiService.updateCachedPostState(widget.post.id, isSaved: false);
          _showSnack('Removed from saved');
        } else {
          _showSnack('Unable to remove');
        }
      });
      return;
    }
    HomeApiService.savePost(widget.post.id).then((ok) {
      if (ok) {
        setState(() => _isSaved = true);
        HomeApiService.updateCachedPostState(widget.post.id, isSaved: true);
        _showSnack('Saved');
      } else {
        _showSnack('Could not save post');
      }
    });
  }

  Future<void> _onShareViaPost() async {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    final url = '${ApiConfig.baseUrl}/posts/${widget.post.id}';
    await Clipboard.setData(ClipboardData(text: url));
    await HomeApiService.sharePost(widget.post.id, channel: 'copy_link');
    _showSnack('Link copied');
  }

  void _onNotInterested() {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    HomeApiService.hidePost(widget.post.id).then((ok) {
      if (ok) {
        widget.onHidden();
        final snack = SnackBar(
          content: const Text('Post hidden'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              HomeApiService.unhidePost(widget.post.id);
            },
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snack);
      } else {
        _showSnack('Unable to hide post');
      }
    });
  }

  void _onUnfollow() {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    HomeApiService.muteUser(widget.post.userId).then((ok) {
      if (ok) {
        widget.onHidden();
        final snack = SnackBar(
          content: Text('Unfollowed ${widget.post.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              HomeApiService.unmuteUser(widget.post.userId);
            },
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snack);
      } else {
        _showSnack('Unable to unfollow');
      }
    });
  }

  void _onReportPost() {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report post'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tell us why (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              Navigator.of(context).pop();
              final ok = await HomeApiService.reportPost(
                widget.post.id,
                reason: reason.isEmpty ? null : reason,
              );
              if (!mounted) return;
              _showSnack(ok ? 'Report submitted' : 'Report failed');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openPostOptions(BuildContext context) {
    if (_isSystem) {
      _showSnack('This is a welcome post.');
      return;
    }
    final post = widget.post;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.bookmark_border_rounded),
            title: Text(_isSaved ? 'Unsave' : 'Save'),
            onTap: () {
              _onSavePost();
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Share via'),
            onTap: () {
              _onShareViaPost();
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.hide_source_rounded),
            title: const Text('Not interested'),
            onTap: () {
              _onNotInterested();
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_off_rounded),
            title: Text('Unfollow ${post.name}'),
            onTap: () {
              _onUnfollow();
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_rounded),
            title: const Text('Report post'),
            onTap: () {
              _onReportPost();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final post = widget.post;

    final likeColor = _liked
        ? _reactionColor(_selectedReaction)
        : Colors.grey[600];
    final likeLabelColor = _liked
        ? _reactionColor(_selectedReaction)
        : Colors.grey[700];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _openUserProfile,
                borderRadius: BorderRadius.circular(999),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.surfaceContainerHighest,
                  backgroundImage:
                      post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                      ? NetworkImage(post.avatarUrl!)
                      : null,
                  child: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF4B5563),
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _openUserProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (post.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          post.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (post.timeAgo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          post.timeAgo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_isSaved)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Saved',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onPressed: _isSystem ? null : () => _openPostOptions(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (post.text.isNotEmpty) ...[
            GestureDetector(
              onTap: _openPostDetail,
              child: Text(
                post.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  height: 1.55,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (post.media.isNotEmpty)
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: post.media.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final media = post.media[i];
                  final ratio = _mediaAspectRatio(media, i);
                  final cardWidth = _mediaWidth(ratio, 190);
                  final url = HomeApiService.normalizeMediaUrl(
                    media['url']?.toString(),
                  );
                  final thumbnailUrl = HomeApiService.normalizeMediaUrl(
                    media['thumbnail_url']?.toString(),
                  );
                  final type = (media['type'] ?? 'image').toString();
                  if (url == null || url.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final mediaList = post.media
                      .map(
                        (m) => {
                          'type': (m['type'] ?? 'image').toString(),
                          'url':
                              HomeApiService.normalizeMediaUrl(
                                (m['url'] ?? '').toString(),
                              ) ??
                              '',
                        },
                      )
                      .where((m) => (m['url'] ?? '').toString().isNotEmpty)
                      .toList();
                  void openViewer() {
                    if (mediaList.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatMediaViewer(
                          media: mediaList.cast<Map<String, String>>(),
                          initialIndex: i,
                        ),
                      ),
                    );
                  }

                  if ((type).toLowerCase().startsWith('video')) {
                    return GestureDetector(
                      onTap: openViewer,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: cardWidth,
                          height: 190,
                          color: Colors.black,
                          child: VideoPreview.network(
                            url: url,
                            fit: BoxFit.contain,
                            autoplay: false,
                            looping: false,
                            muted: false,
                            showPlayOverlay: true,
                            tapToToggle: false,
                            fallback:
                                thumbnailUrl != null && thumbnailUrl.isNotEmpty
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        thumbnailUrl,
                                        fit: BoxFit.contain,
                                      ),
                                      const Center(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0x66000000),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(10),
                                            child: Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: openViewer,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        url,
                        width: cardWidth,
                        height: 190,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: cardWidth,
                          height: 190,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (post.media.isNotEmpty) const SizedBox(height: 10),

          if (_reactionCount > 0 || _commentCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_reactionCount > 0 ? '$_reactionCount likes' : ''}${_reactionCount > 0 && _commentCount > 0 ? ' • ' : ''}${_commentCount > 0 ? '$_commentCount comments' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: !_showReactions
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey('reaction_bar'),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _ReactionChip(
                          emoji: '👍',
                          color: _reactionColor(_Reaction.like),
                          onTap: () => _selectReaction(_Reaction.like),
                        ),
                        _ReactionChip(
                          emoji: '👏',
                          color: _reactionColor(_Reaction.clap),
                          onTap: () => _selectReaction(_Reaction.clap),
                        ),
                        _ReactionChip(
                          emoji: '🔥',
                          color: _reactionColor(_Reaction.fire),
                          onTap: () => _selectReaction(_Reaction.fire),
                        ),
                        _ReactionChip(
                          emoji: '❤️',
                          color: _reactionColor(_Reaction.heart),
                          onTap: () => _selectReaction(_Reaction.heart),
                        ),
                        _ReactionChip(
                          emoji: '💡',
                          color: _reactionColor(_Reaction.idea),
                          onTap: () => _selectReaction(_Reaction.idea),
                        ),
                      ],
                    ),
                  ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _toggleLike,
                onLongPress: _toggleReactionBar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _liked
                        ? _reactionColor(_selectedReaction).withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _liked
                          ? _reactionColor(_selectedReaction).withOpacity(0.24)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      _liked && _selectedReaction != _Reaction.like
                          ? Text(switch (_selectedReaction) {
                              _Reaction.heart => '❤️',
                              _Reaction.clap => '👏',
                              _Reaction.fire => '🔥',
                              _Reaction.idea => '💡',
                              _Reaction.like => '👍',
                              _Reaction.none => '👍',
                            }, style: const TextStyle(fontSize: 18))
                          : Icon(
                              _liked
                                  ? Icons.thumb_up_alt_rounded
                                  : Icons.thumb_up_alt_outlined,
                              size: 18,
                              color: likeColor,
                            ),
                      const SizedBox(width: 4),
                      Text(
                        _reactionLabel(_selectedReaction),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: likeLabelColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _PostActionButton(
                icon: Icons.mode_comment_outlined,
                label: 'Comment',
                onTap: () => _openComments(context),
              ),
              _RepostButton(postId: widget.post.id),
              _PostActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () => _openShare(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(emoji, style: TextStyle(fontSize: 24, color: color)),
      ),
    );
  }
}

class _RepostButton extends StatefulWidget {
  final int postId;

  const _RepostButton({required this.postId});

  @override
  State<_RepostButton> createState() => _RepostButtonState();
}

class _RepostButtonState extends State<_RepostButton> {
  bool _reposted = false;
  bool _loading = false;

  Future<void> _toggleRepost() async {
    if (_loading) return;
    final previous = _reposted;
    setState(() {
      _loading = true;
      _reposted = !_reposted;
    });
    final ok = previous
        ? await HomeApiService.unrepostPost(widget.postId)
        : await HomeApiService.repostPost(widget.postId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) {
        _reposted = previous;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _reposted ? Colors.purple : Colors.grey[700];

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _toggleRepost,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            AnimatedRotation(
              duration: const Duration(milliseconds: 220),
              turns: _reposted ? 0.25 : 0.0, // 90 degrees
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.repeat_rounded, size: 18, color: color),
                  if (_reposted && !_loading)
                    const Positioned(
                      bottom: -1,
                      right: -1,
                      child: Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.purple,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Repost',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: labelColor ?? Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== PLACEHOLDER PAGES =====================

class _PlaceholderPage extends StatelessWidget {
  final String label;

  const _PlaceholderPage({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        '$label page coming soon',
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
      ),
    );
  }
}
