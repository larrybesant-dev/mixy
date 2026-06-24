import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/core/components/electric_button.dart';
import 'package:mixmingle/core/components/glass_card.dart';
import 'package:mixmingle/core/components/neon_badge.dart';
import 'package:mixmingle/core/components/section_header.dart';
import 'package:mixmingle/core/theme/colors_v2.dart';
import 'package:mixmingle/core/theme/spacing.dart';
import 'package:mixmingle/core/theme/typography_v2.dart';
import 'package:mixmingle/shared/widgets/mix_mingle_logo.dart';
import 'package:mixmingle/core/services/landing_music_service.dart';

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LandingMusicService? _music;
  bool _musicPlaying = false;
  bool _musicStarted = false; // has music been started at all?

  /// Web-safe image provider - returns null on web to avoid CORS errors
  ImageProvider? _safeImageProvider(String? url) {
    if (kIsWeb || url == null || url.isEmpty) {
      return null; // Let gradient/placeholder show instead
    }
    return NetworkImage(url);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    // Start landing music after the first frame so providers are ready.
    // On web, browsers block autoplay – we'll start on first user gesture instead.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final svc = ref.read(landingMusicProvider);
      if (svc != null) {
        _music = svc;
        if (!kIsWeb) {
          // Native: autoplay is allowed.
          await _music!.start();
          if (mounted) setState(() { _musicPlaying = true; _musicStarted = true; });
        }
        // Web: wait for first user gesture (see _onFirstGesture).
      }
    });
  }

  /// Called on the first pointer-down on web to satisfy the browser autoplay policy.
  Future<void> _onFirstGesture() async {
    if (_musicStarted || _music == null) return;
    _musicStarted = true;
    await _music!.start();
    if (mounted) setState(() => _musicPlaying = true);
  }

  /// Toggle music on/off via the floating button.
  Future<void> _toggleMusic() async {
    if (_music == null) return;
    if (_musicPlaying) {
      await _music!.fadeOut();
      if (mounted) setState(() => _musicPlaying = false);
    } else {
      _musicStarted = true;
      await _music!.start();
      if (mounted) setState(() => _musicPlaying = true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Fade out music when landing page leaves the tree.
    _music?.fadeOut();
    super.dispose();
  }

  String _getTimeAgo(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return 'Just now';
      }

      final difference = DateTime.now().difference(dateTime);
      if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return 'Just now';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ðŸ  LANDING PAGE IS BUILDING');
    final textTheme = ElectricTypography.textTheme;

    return Scaffold(
      backgroundColor: ElectricColors.surface,
      body: Listener(
        // Web autoplay fix: start music on first user gesture.
        onPointerDown: kIsWeb ? (_) => _onFirstGesture() : null,
        child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ElectricColors.surface,
                  ElectricColors.surfaceElevated
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: Spacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroSection(textTheme),
                  _buildLiveActivity(textTheme),
                  _buildMeetSingles(textTheme),
                  _buildStatsSection(textTheme),
                  _buildFeaturedSessions(textTheme),
                  _buildHowItWorks(textTheme),
                  _buildRisingStars(textTheme),
                  _buildTestimonials(textTheme),
                  _buildCTA(textTheme),
                  _buildFooter(textTheme),
                ],
              ),
            ),
          ),
          // Debug indicator - top left
          Positioned(
            top: 40,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LANDING PAGE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Floating music toggle button (top-right)
          Positioned(
            top: 40,
            right: 16,
            child: Tooltip(
              message: _musicPlaying ? 'Mute music' : 'Play music',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _toggleMusic,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ElectricColors.surfaceElevated.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ElectricColors.neonMagenta.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _musicPlaying ? Icons.music_note : Icons.music_off,
                      color: _musicPlaying
                          ? ElectricColors.neonMagenta
                          : ElectricColors.onSurfaceSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeroSection(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: Spacing.xxl, horizontal: Spacing.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [ElectricColors.deepViolet, ElectricColors.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const MixMingleLogo(fontSize: 48),
          const SizedBox(height: Spacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.xs),
            decoration: BoxDecoration(
              gradient: ElectricColors.electricDiagonal,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: ElectricColors.neonMagenta,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              '🔥 NEW: Live Video Speed Dating',
              style: textTheme.labelLarge?.copyWith(
                color: ElectricColors.onSurfacePrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Stream live energy from creators worldwide',
            style: textTheme.displaySmall?.copyWith(height: 1.05),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Party from home, drop into electric rooms, and discover the next wave of talent.',
            style: textTheme.titleMedium?.copyWith(
              color: ElectricColors.onSurfaceSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xl),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            alignment: WrapAlignment.center,
            children: [
              ElectricButton(
                label: 'Sign Up Free',
                icon: const Icon(Icons.star, size: 18),
                variant: ElectricButtonVariant.secondary,
                onPressed: () {
                  debugPrint('ðŸ”˜ Sign Up button pressed');
                  Navigator.pushNamed(context, '/signup');
                },
              ),
              ElectricButton(
                label: 'Sign In',
                icon: const Icon(Icons.login, size: 18),
                variant: ElectricButtonVariant.secondary,
                onPressed: () {
                  debugPrint('ðŸ”˜ Sign In button pressed');
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActivity(TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rooms')
          .where('isLive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        final activities = <Map<String, dynamic>>[];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final hostName = data['hostName'] ?? 'Unknown User';
            final roomName = data['name'] ?? data['title'] ?? 'Untitled Room';
            final time = _getTimeAgo(data['createdAt']);
            activities.add({
              'icon': '🔴',
              'text': '$hostName went live in $roomName',
              'time': time,
              'status': NeonStatus.speaking,
            });
          }
        }

        // Show placeholder if no real data
        if (activities.isEmpty) {
          activities.addAll([
            {
              'icon': '🎧',
              'text': 'Be the first to go live!',
              'time': 'Now',
              'status': NeonStatus.online
            },
            {
              'icon': '🎤',
              'text': 'Start your stream and connect',
              'time': 'Today',
              'status': NeonStatus.online
            },
            {
              'icon': '🔴',
              'text': 'Share your sound with the world',
              'time': 'Soon',
              'status': NeonStatus.speaking
            },
          ]);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Live Activity',
                subtitle: 'Real-time motion from across the grid',
              ),
              const SizedBox(height: Spacing.sm),
              ...activities.map((activity) => Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.xs),
                      child: Row(
                        children: [
                          Text(activity['icon']! as String,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: Spacing.sm),
                          NeonBadge(
                              status: activity['status']! as NeonStatus,
                              size: NeonBadgeSize.small),
                          const SizedBox(width: Spacing.xs),
                          Expanded(
                            child: Text(
                              activity['text']! as String,
                              style: textTheme.bodySmall?.copyWith(
                                color: ElectricColors.onSurfacePrimary,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Text(
                            activity['time']! as String,
                            style: textTheme.labelSmall?.copyWith(
                              color: ElectricColors.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection(TextTheme textTheme) {
    return StreamBuilder<List<int>>(
      stream: Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
        final onlineUsers = await _firestore
            .collection('users')
            .where('isOnline', isEqualTo: true)
            .get();
        final totalUsers = await _firestore.collection('users').get();
        final liveRooms = await _firestore
            .collection('rooms')
            .where('isActive', isEqualTo: true)
            .get();
        return [
          onlineUsers.docs.length,
          totalUsers.docs.length,
          liveRooms.docs.length
        ];
      }),
      builder: (context, snapshot) {
        final activeUsers = snapshot.data?[0] ?? 0;
        final totalUsers = snapshot.data?[1] ?? 0;
        final liveRooms = snapshot.data?[2] ?? 0;

        final stats = [
          {
            'icon': Icons.headset,
            'value': liveRooms > 0 ? '$liveRooms Live' : 'New!',
            'label': liveRooms > 0 ? 'Active rooms now' : 'Be first to go live'
          },
          {
            'icon': Icons.people,
            'value': totalUsers > 0 ? '$totalUsers+' : '0',
            'label': 'Community members'
          },
          {
            'icon': Icons.access_time,
            'value': activeUsers > 0 ? '$activeUsers' : '24/7',
            'label': activeUsers > 0 ? 'Users online now' : 'Always open'
          },
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.xl),
          child: Column(
            children: [
              const SectionHeader(
                title: 'Join the global community',
                subtitle: 'Real-time stats from our platform',
              ),
              const SizedBox(height: Spacing.lg),
              Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.md,
                alignment: WrapAlignment.center,
                children: stats
                    .map(
                      (stat) => SizedBox(
                        width: 200,
                        child: GlassCard(
                          elevation: GlassCardElevation.medium,
                          padding: const EdgeInsets.all(Spacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(stat['icon']! as IconData,
                                  color: ElectricColors.electricCyan, size: 32),
                              const SizedBox(height: Spacing.sm),
                              Text(
                                stat['value']! as String,
                                style: textTheme.headlineMedium?.copyWith(
                                    color: ElectricColors.onSurfacePrimary),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                stat['label']! as String,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                    color: ElectricColors.onSurfaceSecondary,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeaturedSessions(TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rooms')
          .where('isLive', isEqualTo: true)
          .orderBy('viewerCount', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        final sessions = <Map<String, dynamic>>[];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            sessions.add({
              'id': doc.id,
              'dj': data['hostName'] ?? 'Unknown Host',
              'title': data['name'] ?? data['title'] ?? 'Untitled Session',
              'genre': data['category'] ?? 'Music',
              'listeners': data['viewerCount'] ?? 1,
            });
          }
        }

        // Show placeholder if no real data
        if (sessions.isEmpty) {
          sessions.addAll([
            {
              'dj': 'Coming Soon',
              'title': 'Be the first to go live!',
              'genre': 'All Genres',
              'listeners': 0
            },
            {
              'dj': 'Your Stream',
              'title': 'Start broadcasting now',
              'genre': 'Music',
              'listeners': 0
            },
            {
              'dj': 'Join Us',
              'title': 'Create your first room',
              'genre': 'Community',
              'listeners': 0
            },
          ]);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Featured live sessions',
                subtitle: 'Discover what is peaking right now',
                showAccent: true,
              ),
              const SizedBox(height: Spacing.lg),
              ...sessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: GlassCard(
                    elevation: GlassCardElevation.medium,
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: ElectricColors.electricDiagonal,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.music_note,
                              color: ElectricColors.onSurfacePrimary, size: 32),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  NeonBadge(
                                      status: session['listeners'] > 0
                                          ? NeonStatus.speaking
                                          : NeonStatus.offline,
                                      size: NeonBadgeSize.medium),
                                  const SizedBox(width: Spacing.xs),
                                  Text(
                                    session['listeners'] > 0
                                        ? 'LIVE Â· ${session['genre']}'
                                        : session['genre']! as String,
                                    style: textTheme.labelMedium?.copyWith(
                                        color:
                                            ElectricColors.onSurfaceSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                session['title']! as String,
                                style: textTheme.titleLarge,
                              ),
                              Text(
                                session['dj']! as String,
                                style: textTheme.bodyMedium?.copyWith(
                                    color: ElectricColors.onSurfaceMuted),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Text(
                                session['listeners'] > 0
                                    ? '${session['listeners']} listening'
                                    : 'Ready to start',
                                style: textTheme.labelSmall?.copyWith(
                                    color: ElectricColors.onSurfaceSecondary),
                              ),
                            ],
                          ),
                        ),
                        ElectricButton(
                          label: session['listeners'] > 0 ? 'Join' : 'Start',
                          variant: ElectricButtonVariant.secondary,
                          onPressed: () => Navigator.pushNamed(context,
                              session['listeners'] > 0 ? '/home' : '/login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: ElectricButton(
                  label: 'View all live sessions',
                  variant: ElectricButtonVariant.secondary,
                  onPressed: () => Navigator.pushNamed(context, '/home'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHowItWorks(TextTheme textTheme) {
    final steps = [
      {
        'step': '1',
        'emoji': '🎧',
        'title': 'Join a room',
        'desc': 'Browse live rooms and drop in instantly.'
      },
      {
        'step': '2',
        'emoji': '🎤',
        'title': 'Go live',
        'desc': 'Start your own stream with zero setup friction.'
      },
      {
        'step': '3',
        'emoji': '💰',
        'title': 'Tip & connect',
        'desc': 'Support creators and build connections.'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'How it works',
            subtitle: 'Three quick steps to get in the mix',
          ),
          const SizedBox(height: Spacing.lg),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: GlassCard(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ElectricColors.electricDiagonal,
                      ),
                      child: Center(
                        child: Text(
                          step['step']!,
                          style: textTheme.titleLarge?.copyWith(
                              color: ElectricColors.onSurfacePrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(step['emoji']!,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: Spacing.xs),
                              Text(step['title']!,
                                  style: textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            step['desc']!,
                            style: textTheme.bodyMedium?.copyWith(
                                color: ElectricColors.onSurfaceSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetSingles(TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('photoUrl', isNotEqualTo: null)
          .limit(12)
          .snapshots(),
      builder: (context, snapshot) {
        final profiles = <Map<String, dynamic>>[];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['photoUrl'] != null || data['avatarUrl'] != null) {
              final location = data['location'];
              String locationStr = '';
              if (location is Map) {
                locationStr = location['city']?.toString() ?? '';
              } else if (location is String) {
                locationStr = location;
              }

              profiles.add({
                'name': data['displayName'] ?? data['username'] ?? 'User',
                'age': data['age'],
                'location': locationStr,
                'photoUrl': data['photoUrl'] ?? data['avatarUrl'],
                'isOnline': data['isOnline'] ?? false,
                'lookingFor': data['lookingFor'] ?? 'Friends',
              });
            }
          }
        }

        // Show placeholder if no real data
        if (profiles.isEmpty) {
          profiles.addAll([
            {
              'name': 'Join us',
              'photoUrl': null,
              'age': null,
              'location': 'Worldwide',
              'isOnline': false,
              'lookingFor': 'Connection'
            },
            {
              'name': 'Meet new people',
              'photoUrl': null,
              'age': null,
              'location': 'Global',
              'isOnline': false,
              'lookingFor': 'Friends'
            },
            {
              'name': 'Start dating',
              'photoUrl': null,
              'age': null,
              'location': 'Your City',
              'isOnline': false,
              'lookingFor': 'Romance'
            },
            {
              'name': 'Find your match',
              'photoUrl': null,
              'age': null,
              'location': 'Everywhere',
              'isOnline': false,
              'lookingFor': 'Love'
            },
          ]);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ElectricColors.neonMagenta.withValues(alpha: 0.15),
                      ElectricColors.deepViolet.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ElectricColors.neonMagenta,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.xs),
                          decoration: BoxDecoration(
                            color: ElectricColors.neonMagenta,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: ElectricColors.neonMagenta,
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            '🔥 NEW',
                            style: textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      '💘 Live Video Speed Dating',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Meet singles nearby through 3-minute video dates',
                      style: textTheme.titleSmall?.copyWith(
                        color: ElectricColors.onSurfaceSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 4;
                  if (constraints.maxWidth < 600) {
                    crossAxisCount = 2;
                  } else if (constraints.maxWidth < 900) {
                    crossAxisCount = 3;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: Spacing.md,
                      mainAxisSpacing: Spacing.md,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: profiles.length > 12 ? 12 : profiles.length,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return GlassCard(
                        padding: const EdgeInsets.all(Spacing.sm),
                        elevation: GlassCardElevation.low,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: profile['photoUrl'] == null
                                          ? ElectricColors.electricDiagonal
                                          : null,
                                      image: _safeImageProvider(
                                                  profile['photoUrl']) !=
                                              null
                                          ? DecorationImage(
                                              image: _safeImageProvider(
                                                  profile['photoUrl'])!,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: profile['photoUrl'] == null
                                        ? const Center(
                                            child: Icon(
                                              Icons.favorite,
                                              size: 40,
                                              color: ElectricColors
                                                  .onSurfacePrimary,
                                            ),
                                          )
                                        : null,
                                  ),
                                  if (profile['isOnline'] == true)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF4CAF50),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF4CAF50),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              profile['age'] != null
                                  ? '${profile['name']}, ${profile['age']}'
                                  : profile['name']!,
                              style: textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            if (profile['location'] != null &&
                                profile['location'].toString().isNotEmpty)
                              Text(
                                profile['location']!,
                                style: textTheme.labelSmall?.copyWith(
                                  color: ElectricColors.onSurfaceMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: Spacing.lg),
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Join thousands finding love through video',
                      style: textTheme.bodySmall?.copyWith(
                        color: ElectricColors.onSurfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRisingStars(TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .orderBy('followersCount', descending: true)
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        final djs = <Map<String, dynamic>>[];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final followers = data['followersCount'] ?? 0;
            djs.add({
              'name': data['displayName'] ?? data['username'] ?? 'User',
              'genre': data['interests']?.isNotEmpty == true
                  ? (data['interests'][0] ?? 'Music')
                  : 'Music',
              'followers': _formatCount(followers),
              'avatarUrl': data['avatarUrl'],
            });
          }
        }

        // Show placeholder if no real data
        if (djs.isEmpty) {
          djs.addAll([
            {'name': 'Join Us', 'genre': 'Be the first', 'followers': '0'},
            {'name': 'You', 'genre': 'Start streaming', 'followers': '0'},
            {'name': 'Creator', 'genre': 'Build your brand', 'followers': '0'},
            {'name': 'Artist', 'genre': 'Share your sound', 'followers': '0'},
          ]);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Rising stars',
                subtitle: 'Creators building the future of live music',
              ),
              const SizedBox(height: Spacing.lg),
              Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.md,
                children: djs
                    .map(
                      (dj) => SizedBox(
                        width: 170,
                        child: GlassCard(
                          padding: const EdgeInsets.all(Spacing.lg),
                          elevation: GlassCardElevation.low,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _safeImageProvider(dj['avatarUrl']) != null
                                  ? CircleAvatar(
                                      radius: 36,
                                      backgroundImage:
                                          _safeImageProvider(dj['avatarUrl']),
                                    )
                                  : const CircleAvatar(
                                      radius: 36,
                                      backgroundColor:
                                          ElectricColors.surfaceMuted,
                                      child: Icon(Icons.person,
                                          size: 32,
                                          color:
                                              ElectricColors.onSurfacePrimary),
                                    ),
                              const SizedBox(height: Spacing.sm),
                              Text(dj['name']!,
                                  style: textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                dj['genre']!,
                                style: textTheme.bodySmall?.copyWith(
                                    color: ElectricColors.onSurfaceSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                '${dj['followers']} followers',
                                style: textTheme.labelSmall?.copyWith(
                                    color: ElectricColors.onSurfaceMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestimonials(TextTheme textTheme) {
    final testimonials = [
      {
        'emoji': '🌊',
        'quote':
            'Pure sonic adventure. Every room has its own vibe, every DJ tells a story.',
        'name': 'Sofia Waves',
        'title': 'Ambient Composer',
      },
      {
        'emoji': '⚡',
        'quote':
            'This is where electronic music culture thrives. The community here is incredible.',
        'name': 'Kai Thunder',
        'title': 'Festival Curator',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Community love',
            subtitle: 'Words from people on the floor',
          ),
          const SizedBox(height: Spacing.lg),
          ...testimonials.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: GlassCard(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(item['emoji']!, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      '"${item['quote']}"',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: ElectricColors.onSurfacePrimary,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      item['name']!,
                      style: textTheme.titleMedium
                          ?.copyWith(color: ElectricColors.neonMagenta),
                    ),
                    Text(
                      item['title']!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: ElectricColors.onSurfaceSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTA(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.xl),
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: ElectricColors.electricDiagonal,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: ElectricColors.glassShadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Ready to join the party?',
            style: textTheme.headlineMedium
                ?.copyWith(color: ElectricColors.onSurfacePrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Your next favorite creator is live right now.',
            style: textTheme.titleMedium?.copyWith(
                color: ElectricColors.onSurfacePrimary.withValues(alpha: 0.85)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            alignment: WrapAlignment.center,
            children: [
              ElectricButton(
                label: 'Join the community',
                icon: const Icon(Icons.bolt, size: 18),
                onPressed: () => Navigator.pushNamed(context, '/signup'),
              ),
              ElectricButton(
                label: 'Explore live sessions',
                variant: ElectricButtonVariant.secondary,
                onPressed: () => Navigator.pushNamed(context, '/home'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      color: ElectricColors.surfaceMuted,
      child: Column(
        children: [
          const MixMingleLogo(fontSize: 28),
          const SizedBox(height: Spacing.sm),
          Text(
            'Connect with live users and music lovers worldwide',
            style: textTheme.bodySmall
                ?.copyWith(color: ElectricColors.onSurfaceSecondary),
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.lg,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('About',
                    style: TextStyle(color: ElectricColors.onSurfacePrimary)),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Privacy',
                    style: TextStyle(color: ElectricColors.onSurfacePrimary)),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Terms',
                    style: TextStyle(color: ElectricColors.onSurfacePrimary)),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Contact',
                    style: TextStyle(color: ElectricColors.onSurfacePrimary)),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Â© 2026 Mix & Mingle. All rights reserved.',
            style: textTheme.labelSmall
                ?.copyWith(color: ElectricColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
