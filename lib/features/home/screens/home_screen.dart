import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'network_screen.dart';
import 'post_screen.dart';
import 'notifications_screen.dart';
import 'jobs_screen.dart';
import 'funding_screen.dart';

const double _topBarHeight = 72.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final ScrollController _scrollController;
  bool _showTopBar = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final direction = _scrollController.position.userScrollDirection;

    if (direction == ScrollDirection.reverse && _showTopBar) {
      setState(() => _showTopBar = false);
    } else if (direction == ScrollDirection.forward && !_showTopBar) {
      setState(() => _showTopBar = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
        final pages = <Widget>[
        _HomeFeedPage(controller: _scrollController),
        const NetworkScreen(),
        const SizedBox.shrink(),
        const JobsScreen(),
        const NotificationsScreen(),
        const FundingScreen(),
      ];


    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      drawerEdgeDragWidth: 0,
      drawer: const _ProfileDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            // FEED
            Positioned.fill(
              top: _showTopBar ? _topBarHeight : 0,
              child: pages[_selectedIndex],
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: _showTopBar ? 0 : -_topBarHeight,
              left: 0,
              right: 0,
              height: _topBarHeight,
              child: Material(
                color: const Color(0xFFF5F5F7),
                elevation: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(
                      builder: (ctx) => _HomeTopBar(
                        openDrawer: () => Scaffold.of(ctx).openDrawer(),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          // POST
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PostScreen(),
              ),
            );
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
        },

        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label: 'Network',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box_rounded),
            label: 'Post',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Funding',
          ),
        ],
      ),
    );
  }
}

// ===================== TOP BAR =====================

class _HomeTopBar extends StatelessWidget {
  final VoidCallback openDrawer;

  const _HomeTopBar({required this.openDrawer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: openDrawer,
            child: const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFDBEAFE),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                Navigator.of(context).pushNamed('/search');
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search alumni, schools, jobs…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/messages');
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Messages',
          ),
        ],
      ),
    );
  }
}

// ===================== PROFILE DRAWER =====================

class _ProfileDrawer extends StatelessWidget {
  const _ProfileDrawer();

  void _openAnalytics(BuildContext context) {
    Navigator.of(context).pushNamed('/analytics');
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pushNamed('/profile');
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width * 0.75;

    return SizedBox(
      width: width,
      child: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              InkWell(
                onTap: () => _openProfile(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFFDBEAFE),
                        child: Icon(
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
                              'Michael Annor',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Software • UX/UI • IT Auditor',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Location + school 
              InkWell(
                onTap: () => _openProfile(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ghana',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Alpha Beta College',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.grey[300],
              ),
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
                                text: '21 ',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: 'profile viewers',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
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
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.grey[300],
              ),

              const Spacer(),

              // Settings
              ListTile(
                onTap: () => _openSettings(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading:
                    const Icon(Icons.settings_rounded, color: Colors.black87),
                title: Text(
                  'Settings',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.black54,
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // backend linked to logout
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.05),
                      side: BorderSide(color: Colors.red[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Log out',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w600,
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

// ===================== HOME FEED =====================

class _HomeFeedPage extends StatelessWidget {
  final ScrollController controller;

  const _HomeFeedPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final posts = [
      _FeedPost(
        name: 'Akosua Mensah',
        subtitle: 'Alumni • University of Ghana, 2019',
        timeAgo: '2h',
        text:
            'Excited to announce our first alumni meetup for 2025 🎉. Looking forward to reconnecting with everyone!',
      ),
      _FeedPost(
        name: 'Alpha Beta College',
        subtitle: 'School • Accra',
        timeAgo: '5h',
        text:
            'We’re launching a new library upgrade project. Alumni can now support directly from the app.',
      ),
      _FeedPost(
        name: 'Kwame Boateng',
        subtitle: 'Software Engineer • Ashesi University',
        timeAgo: '1d',
        text:
            'Just joined Alumni Global Network. Happy to connect with other tech enthusiasts and mentor SHS students.',
      ),
      _FeedPost(
        name: 'Rixrod Company Limited',
        subtitle: 'Company • Accra',
        timeAgo: '2d',
        text:
            'We are hiring 3 interns from partner schools for our 2025 innovation lab. Apply via Alumni Global.',
      ),
      _FeedPost(
        name: 'Verix Teams',
        subtitle: 'HR, CRM & Project Management',
        timeAgo: '3d',
        text:
            'New partnership with Alumni Global Network to support career development for SHS graduates.',
      ),
    ];

    final stories = [
      _Story(userName: 'You', isYourStory: true),
      _Story(userName: 'Akosua'),
      _Story(userName: 'Alpha Beta'),
      _Story(userName: 'Kwame'),
      _Story(userName: 'Ama'),
      _Story(userName: 'Verix Teams'),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.separated(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: posts.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoriesBar(stories: stories);
          }
          final post = posts[index - 1];
          return _FeedPostCard(post: post);
        },
      ),
    );
  }
}

// ---------------- STORIES ----------------

class _Story {
  final String userName;
  final bool isYourStory;

  _Story({required this.userName, this.isYourStory = false});
}

class _StoriesBar extends StatelessWidget {
  final List<_Story> stories;

  const _StoriesBar({required this.stories});

  void _openStory(BuildContext context, _Story story) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StoryViewer(story: story),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];
          return GestureDetector(
            onTap: () => _openStory(context, story),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: story.isYourStory
                        ? LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.6),
                            ],
                          )
                        : null,
                    border: story.isYourStory
                        ? null
                        : Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFE5E7EB),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    story.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
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

class _StoryViewer extends StatelessWidget {
  final _Story story;

  const _StoryViewer({required this.story});

  void _openStoryShare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ListTile(
            leading: Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
            title: Text('Share with a friend'),
            iconColor: Colors.white,
            textColor: Colors.white,
          ),
          ListTile(
            leading: Icon(Icons.groups_rounded, color: Colors.white),
            title: Text('Share to a group'),
            iconColor: Colors.white,
            textColor: Colors.white,
          ),
          ListTile(
            leading: Icon(Icons.link_rounded, color: Colors.white),
            title: Text('Copy link'),
            iconColor: Colors.white,
            textColor: Colors.white,
          ),
          SizedBox(height: 12),
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
          ListTile(
            leading:
                const Icon(Icons.report_gmailerrorred, color: Colors.white),
            title: const Text('Report'),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              // TODO: hook story "Report"
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_off, color: Colors.white),
            title: const Text('Mute'),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              // TODO: hook story "Mute"
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_off, color: Colors.white),
            title: Text('Unfollow ${story.userName}'),
            iconColor: Colors.white,
            textColor: Colors.white,
            onTap: () {
              // TODO: hook story "Unfollow"
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _sendStoryMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message sent')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! > 0) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Text(
                  "${story.userName}'s story",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // top bar
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.more_vert_rounded, color: Colors.white),
                      onPressed: () => _openStoryMenu(context),
                    ),
                  ],
                ),
              ),

              // bottom controls
              Positioned(
                left: 12,
                right: 12,
                bottom: 16,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Reply…',
                              hintStyle:
                                  const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white10,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                    color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                    color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: const BorderSide(
                                    color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _sendStoryMessage(context),
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            _StoryReactionButton(label: '👍'),
                            _StoryReactionButton(label: '🔥'),
                            _StoryReactionButton(label: '❤️'),
                            _StoryReactionButton(label: '👏'),
                          ],
                        ),
                        IconButton(
                          onPressed: () => _openStoryShare(context),
                          icon: const Icon(Icons.share_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryReactionButton extends StatelessWidget {
  final String label;

  const _StoryReactionButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

// ---------------- POSTS ----------------

class _FeedPost {
  final String name;
  final String subtitle;
  final String timeAgo;
  final String text;

  _FeedPost({
    required this.name,
    required this.subtitle,
    required this.timeAgo,
    required this.text,
  });
}

enum _Reaction { none, like, clap, fire, heart, idea }

class _FeedPostCard extends StatefulWidget {
  final _FeedPost post;

  const _FeedPostCard({required this.post});

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  bool _showReactions = false;
  _Reaction _selectedReaction = _Reaction.none;

  bool get _liked => _selectedReaction != _Reaction.none;

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

  void _toggleReactionBar() {
    setState(() {
      _showReactions = true;
    });
  }

  void _toggleLike() {
    setState(() {
      if (_liked) {
        _selectedReaction = _Reaction.none;
      } else {
        _selectedReaction = _Reaction.like;
      }
      _showReactions = false;
    });
  }

  void _selectReaction(_Reaction r) {
    setState(() {
      _selectedReaction = r;
      _showReactions = false;
    });
  }

  void _openComments(BuildContext context) {
    final theme = Theme.of(context);
    String filter = 'Most relevant';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
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
                      // search bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search comments…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide:
                                BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide:
                                BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(999)),
                            borderSide: BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // comments list
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: 6,
                          itemBuilder: (_, i) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFFE5E7EB),
                              child: Icon(Icons.person_rounded,
                                  size: 18, color: Color(0xFF4B5563)),
                            ),
                            title: Text(
                              i.isEven
                                  ? 'Looks great, congrats! 🎉'
                                  : 'Following this project closely.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              '2h ago',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFE5E7EB),
                            child: Icon(Icons.person_rounded,
                                size: 18, color: Color(0xFF4B5563)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Add a comment…',
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(999)),
                                  borderSide: BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
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

  void _openShare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ListTile(
            leading: Icon(Icons.person_add_alt_1_rounded),
            title: Text('Share with a friend'),
          ),
          ListTile(
            leading: Icon(Icons.groups_rounded),
            title: Text('Share to a group'),
          ),
          ListTile(
            leading: Icon(Icons.link_rounded),
            title: Text('Copy link'),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // Linking post options
  void _onSavePost() {
    // TODO: implement Save post
  }

  void _onShareViaPost() {
    // TODO: implement Share via
  }

  void _onNotInterested() {
    // TODO: implement Not interested
  }

  void _onUnfollow() {
    // TODO: implement Unfollow
  }

  void _onReportPost() {
    // TODO: implement Report post
  }

  void _openPostOptions(BuildContext context) {
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
            title: const Text('Save'),
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
    final post = widget.post;

    final likeColor =
        _liked ? _reactionColor(_selectedReaction) : Colors.grey[600];
    final likeLabelColor =
        _liked ? _reactionColor(_selectedReaction) : Colors.grey[700];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE5E7EB),
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFF4B5563),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onPressed: () => _openPostOptions(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            post.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[900],
              height: 1.4,
            ),
          ),

          const SizedBox(height: 10),

          if (_showReactions) ...[
            Row(
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
            const SizedBox(height: 6),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              
              GestureDetector(
                onTap: _toggleLike,
                onLongPress: _toggleReactionBar,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _liked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 18,
                        color: likeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Like',
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
              const _RepostButton(),
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
        child: Text(
          emoji,
          style: TextStyle(fontSize: 24, color: color),
        ),
      ),
    );
  }
}

class _RepostButton extends StatefulWidget {
  const _RepostButton();

  @override
  State<_RepostButton> createState() => _RepostButtonState();
}

class _RepostButtonState extends State<_RepostButton> {
  bool _reposted = false;

  void _toggleRepost() {
    setState(() {
      _reposted = !_reposted;
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
                  Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: color,
                  ),
                  if (_reposted)
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
              ),
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
            Icon(
              icon,
              size: 18,
              color: iconColor ?? Colors.grey[600],
            ),
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
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
