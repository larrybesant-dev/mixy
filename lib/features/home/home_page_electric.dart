/// Home Page Electric
/// Main landing page after onboarding completion
/// Shows: Live Rooms, Speed Dating, Discovery, Chats
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/design_constants.dart';
import '../../core/design_system/app_layout.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/room.dart';
import '../../shared/widgets/club_background.dart';
import '../../shared/providers/all_providers.dart';
import '../../core/intelligence/vibe_intelligence_service.dart';
import '../onboarding/widgets/onboarding_welcome_overlay.dart';
import '../discover/room_discovery_page.dart';
import '../chat/screens/chat_list_page.dart';
import '../profile/screens/profile_page.dart';
import '../match_inbox/screens/match_inbox_page.dart';
import '../match_inbox/providers/match_inbox_providers.dart';
import '../room/providers/room_providers.dart';
import '../../core/web/web_window_service.dart';
import '../feed/social_feed_page.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../services/analytics/analytics_service.dart';
import '../../core/analytics/analytics_service.dart' as core_analytics;
import 'widgets/active_friends_row.dart';
import '../discover_users/providers/active_friends_provider.dart';

/// Home Page with Electric theme - main post-onboarding landing
class HomePageElectric extends ConsumerStatefulWidget {
  const HomePageElectric({super.key});

  @override
  ConsumerState<HomePageElectric> createState() => _HomePageElectricState();
}

class _HomePageElectricState extends ConsumerState<HomePageElectric> {
  int _selectedIndex = 0;
  bool _dismissedSuggestion = false;
  bool _overlayTriggered = false;

  // Vibe palette — same keys as rooms list page for consistency
  static const _kVibeColors = <String, Color>{
    'Chill': Color(0xFF4A90FF),
    'Hype': Color(0xFFFF4D8B),
    'Deep Talk': Color(0xFF8B5CF6),
    'Late Night': Color(0xFF6366F1),
    'Study': Color(0xFF00E5CC),
    'Party': Color(0xFFFFAB00),
  };
  static const _kVibeIcons = <String, IconData>{
    'Chill': Icons.waves_outlined,
    'Hype': Icons.bolt,
    'Deep Talk': Icons.forum_outlined,
    'Late Night': Icons.nightlight_outlined,
    'Study': Icons.menu_book_outlined,
    'Party': Icons.celebration_outlined,
  };
  Color _vc(String? v) => _kVibeColors[v] ?? DesignColors.accent;
  IconData _vi(String? v) => _kVibeIcons[v] ?? Icons.graphic_eq;

  @override
  void initState() {
    super.initState();
    core_analytics.AnalyticsService.instance.logScreenView(screenName: 'screen_home');
  }

  @override
  Widget build(BuildContext context) {
    // Show the welcome overlay exactly once for every new account that has
    // not yet completed onboarding (onboardingComplete == false in Firestore).
    ref.listen<AsyncValue<UserProfile?>>(currentUserProfileProvider, (_, next) {
      next.whenData((profile) {
        if (!_overlayTriggered &&
            profile != null &&
            !profile.onboardingComplete) {
          _overlayTriggered = true;
          // Post-frame so the widget tree is settled before adding the overlay.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(welcomeOverlayVisibleProvider.notifier).show();
            }
          });
        }
      });
    });

    final showOverlay = ref.watch(welcomeOverlayVisibleProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;

    return Stack(
      children: [
        ClubBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(profile),
            body: _buildBody(),
            bottomNavigationBar: _buildNeonNavBar(),
          ),
        ),
        if (showOverlay) const OnboardingWelcomeOverlay(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  NEON APP BAR
  // ══════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(UserProfile? profile) {
    return AppBar(
      backgroundColor: DesignColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(children: [
        // Logo dot pulse
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.accent,
            boxShadow: [
              BoxShadow(
                  color: DesignColors.accent.withValues(alpha: 0.7),
                  blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.spaceSM),
        const Text(
          'MIX & MINGLE',
          style: TextStyle(
            color: DesignColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: DesignColors.primaryGlow,
          ),
        ),
        if (profile?.vibeTag != null) ...[
          const SizedBox(width: AppSpacing.spaceSM),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceSM, vertical: AppSpacing.spaceXS),
            decoration: BoxDecoration(
              color: _vc(profile!.vibeTag).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSizes.chipBorderRadius),
              border: Border.all(
                  color: _vc(profile.vibeTag).withValues(alpha: 0.45)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_vi(profile.vibeTag), size: 11, color: _vc(profile.vibeTag)),
              const SizedBox(width: AppSpacing.spaceXS),
              Text(profile.vibeTag!,
                  style: AppTypography.chipLabel
                      .copyWith(color: _vc(profile.vibeTag))),
            ]),
          ),
        ],
      ]),
      actions: [
        // Friends pop-out button (web only — Yahoo Messenger style)
        if (kIsWeb)
          const IconButton(
            icon: Icon(Icons.people_outlined, color: DesignColors.accent),
            tooltip: 'Friends List',
            onPressed: WebWindowService.openBuddyList,
          ),
        // Notification bell with live unread badge
        Consumer(
          builder: (_, ref2, __) {
            final unread =
                ref2.watch(unreadNotificationCountProvider).value ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: DesignColors.textGray),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/notifications'),
                ),
                if (unread > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D8B),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: DesignColors.background, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/settings'),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: profile?.photoUrl != null
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(profile!.photoUrl!))
                : CircleAvatar(
                    radius: 16,
                    backgroundColor: DesignColors.accent.withValues(alpha: 0.2),
                    child: const Icon(Icons.person,
                        size: 16, color: DesignColors.accent)),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  NEON BOTTOM NAV BAR
  // ══════════════════════════════════════════════════════════
  Widget _buildNeonNavBar() {
    const items = [
      _NavItem(Icons.home_outlined, Icons.home, 'Home'),
      _NavItem(Icons.favorite_border, Icons.favorite, 'Matches'),
      _NavItem(Icons.bolt_outlined, Icons.bolt, 'Speed'),
      _NavItem(Icons.video_call_outlined, Icons.video_call, 'Rooms'),
      _NavItem(Icons.dynamic_feed_outlined, Icons.dynamic_feed, 'Feed'),
      _NavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
      _NavItem(Icons.person_outline, Icons.person, 'Profile'),
    ];

    // Badge count for Matches tab (index 1)
    final newMatchCount = ref.watch(newMatchCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: DesignColors.background,
        border: Border(
            top:
                BorderSide(color: DesignColors.accent.withValues(alpha: 0.15))),
        boxShadow: [
          BoxShadow(
              color: DesignColors.accent.withValues(alpha: 0.06),
              blurRadius: 20),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = _selectedIndex == i;
              // Matches tab badge (index 1)
              final showBadge = i == 1 && newMatchCount > 0;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = i);
                  final tabNames = [
                    'home', 'matches', 'speed_dating', 'rooms', 'feed', 'chats', 'profile'
                  ];
                  if (i < tabNames.length) {
                    AnalyticsService().trackScreenView(tabNames[i]);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 48,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(AppSpacing.spaceSM - 2),
                          decoration: BoxDecoration(
                            color: selected
                                ? (i == 1
                                    ? const Color(0xFFFF4D8B)
                                        .withValues(alpha: 0.15)
                                    : DesignColors.accent
                                        .withValues(alpha: 0.15))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color: (i == 1
                                                ? const Color(0xFFFF4D8B)
                                                : DesignColors.accent)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                selected ? item.activeIcon : item.icon,
                                size: AppSizes.iconNav,
                                color: selected
                                    ? (i == 1
                                        ? const Color(0xFFFF4D8B)
                                        : DesignColors.accent)
                                    : DesignColors.textGray,
                              ),
                              if (showBadge)
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                        minWidth: 16, minHeight: 16),
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF4D8B),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      newMatchCount > 9
                                          ? '9+'
                                          : '$newMatchCount',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.spaceXS - 2),
                        Text(item.label,
                            style: AppTypography.navLabel.copyWith(
                              color: selected
                                  ? (i == 1
                                      ? const Color(0xFFFF4D8B)
                                      : DesignColors.accent)
                                  : DesignColors.textGray,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w400,
                            )),
                      ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final Widget body;
    switch (_selectedIndex) {
      case 0:
        body = _buildHomeTab();
      case 1:
        body = _buildMatchInboxTab();
      case 2:
        body = _buildSpeedDatingTab();
      case 3:
        body = _buildRoomsTab();
      case 4:
        body = _buildFeedTab();
      case 5:
        body = _buildChatsTab();
      case 6:
        body = _buildProfileTab();
      default:
        body = _buildHomeTab();
    }
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: body),
      ],
    );
  }

  /// Home Tab — personalized vibe greeting + heating-up rooms
  Widget _buildHomeTab() {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final p = profileAsync.asData?.value;
    final roomsAsync = ref.watch(liveRoomsProvider);
    // #2 Composite heating-up score: joinVelocity x2 + viewerCount
    final liveRooms = <Room>[...(roomsAsync.value ?? <Room>[])]..sort((a, b) {
        final aScore = (a.joinVelocity * 2) + a.viewerCount;
        final bScore = (b.joinVelocity * 2) + b.viewerCount;
        return bScore.compareTo(aScore);
      });
    final heatingUp = liveRooms.take(6).toList();

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : hour < 21
                ? 'Good evening'
                : 'Late night vibes';
    final name = p?.displayName?.split(' ').first ?? 'there';
    // #3 — smart vibe greeting: prefer topVibe (behaviour-driven) over static vibeTag
    final vibe = p?.topVibe ?? p?.vibeTag;
    final vibeLabel = (p != null && p.topVibe != null && p.topVibeCount > 1)
        ? '${p.topVibe} vibes — x${p.topVibeCount} rooms'
        : vibe != null
            ? '$vibe vibes today'
            : null;

    final sw = MediaQuery.sizeOf(context).width;
    final hPad = AppLayout.responsivePaddingH(sw);
    final activeFriends = ref.watch(activeFriendsProvider).value ?? [];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, AppSpacing.spaceLG, hPad, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting,', style: AppTypography.greeting),
              const SizedBox(height: AppSpacing.spaceXS),
              Text(name, style: AppTypography.display),
              if (vibe != null) ...[
                const SizedBox(height: AppSpacing.spaceSM),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spaceSM + 2,
                      vertical: AppSpacing.spaceXS),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _vc(vibe).withValues(alpha: 0.2),
                      _vc(vibe).withValues(alpha: 0.05),
                    ]),
                    borderRadius:
                        BorderRadius.circular(AppSizes.chipBorderRadius),
                    border: Border.all(color: _vc(vibe).withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_vi(vibe), size: 13, color: _vc(vibe)),
                    const SizedBox(width: AppSpacing.spaceXS),
                    Text(vibeLabel ?? '$vibe vibes today',
                        style:
                            AppTypography.chipLabel.copyWith(color: _vc(vibe))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        // ── Active Friends row ──────────────────────────────────────────
        if (activeFriends.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(0, AppSpacing.spaceLG, 0, 0),
              child: ActiveFriendsRow(
                presenceList: activeFriends,
                onAvatarTap: (p) => Navigator.pushNamed(
                  context,
                  '/profile/user',
                  arguments: p.userId,
                ),
              ),
            ),
          ),
        // ── CTA cards ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, AppSpacing.spaceXL, hPad, 0),
            child: Row(children: [
              Expanded(
                  child: _ctaCard(
                icon: Icons.add_circle_outline,
                label: 'Start a Room',
                sublabel: 'Go live now',
                color: const Color(0xFFFF4D8B),
                onTap: () => Navigator.pushNamed(context, '/create-room'),
              )),
              const SizedBox(width: AppSpacing.spaceMD),
              Expanded(
                  child: _ctaCard(
                icon: Icons.bolt,
                label: 'Speed Dating',
                sublabel: '5-min video dates',
                color: DesignColors.gold,
                onTap: () => setState(() => _selectedIndex = 2),
              )),
              const SizedBox(width: AppSpacing.spaceMD),
              Expanded(
                  child: _ctaCard(
                icon: Icons.people_alt_outlined,
                label: 'Find People',
                sublabel: 'Discover others',
                color: DesignColors.tertiary,
                onTap: () =>
                    Navigator.pushNamed(context, '/discover-users'),
              )),
            ]),
          ),
        ),
        // #7 — Adaptive vibe suggestion banner
        if (!_dismissedSuggestion)
          SliverToBoxAdapter(child: _buildVibeSuggestionBanner(p)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, AppSpacing.spaceXXL - 4, 0, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🔥 Heating Up', style: AppTypography.sectionTitle),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 3),
                  child: Text('See All',
                      style: AppTypography.caption
                          .copyWith(color: DesignColors.accent)),
                ),
                const SizedBox(width: AppSpacing.spaceSM),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildHeatingUpRail(heatingUp, hPad)),
        const SliverToBoxAdapter(child: AppSectionGap()),
      ],
    );
  }

  // #7 — Vibe suggestion banner
  Widget _buildVibeSuggestionBanner(UserProfile? p) {
    if (p == null) return const SizedBox.shrink();
    final suggestion =
        ref.read(vibeIntelligenceServiceProvider).getVibeSuggestion(p);
    if (suggestion == null) return const SizedBox.shrink();
    const nudgeColor = Color(0xFFFFAB00);
    final sw2 = MediaQuery.sizeOf(context).width;
    final hPad2 = AppLayout.responsivePaddingH(sw2);
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad2, AppSpacing.spaceLG, hPad2, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMD + 2,
            vertical: AppSpacing.spaceSM + 2),
        decoration: BoxDecoration(
          color: nudgeColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
          border: Border.all(color: nudgeColor.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.lightbulb_outline,
              size: AppSizes.iconStandard - 6, color: nudgeColor),
          const SizedBox(width: AppSpacing.spaceSM + 2),
          Expanded(
            child: Text(suggestion,
                style: AppTypography.caption
                    .copyWith(color: nudgeColor, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () => setState(() => _dismissedSuggestion = true),
            child: const Icon(Icons.close,
                size: AppSizes.iconStandard - 8, color: nudgeColor),
          ),
        ]),
      ),
    );
  }

  Widget _ctaCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.spaceLG, horizontal: AppSpacing.spaceMD + 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: AppSizes.iconLarge),
          const SizedBox(height: AppSpacing.spaceSM),
          Text(label,
              style: AppTypography.bodySm.copyWith(
                  color: DesignColors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.spaceXS - 2),
          Text(sublabel, style: AppTypography.captionSm),
        ]),
      ),
    );
  }

  Widget _buildHeatingUpRail(List<Room> rooms, double hPad) {
    if (rooms.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(hPad),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.spaceXL),
          decoration: BoxDecoration(
            color: DesignColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
            border:
                Border.all(color: DesignColors.accent.withValues(alpha: 0.15)),
          ),
          child: Column(children: [
            const Icon(Icons.mic_none_outlined,
                size: AppSizes.iconXl + 8, color: DesignColors.accent),
            const SizedBox(height: AppSpacing.spaceSM + 2),
            const Text('No live rooms yet — be the first!',
                style: AppTypography.bodySm),
            const SizedBox(height: AppSpacing.spaceMD + 2),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/create-room'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spaceXL,
                    vertical: AppSpacing.spaceSM + 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF4A90FF), Color(0xFF8B5CF6)]),
                  borderRadius:
                      BorderRadius.circular(AppSizes.buttonBorderRadius + 10),
                ),
                child: const Text('Start a Room',
                    style: AppTypography.buttonLabel),
              ),
            ),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 164,
      child: ListView.builder(
        padding: EdgeInsets.only(
            left: hPad,
            right: AppSpacing.spaceSM,
            top: AppSpacing.spaceSM,
            bottom: AppSpacing.spaceSM),
        scrollDirection: Axis.horizontal,
        itemCount: rooms.length,
        itemBuilder: (_, i) {
          final room = rooms[i];
          final color = _vc(room.vibeTag);
          return GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/room', arguments: room.id),
            child: Container(
              width: 164,
              margin: const EdgeInsets.only(right: AppSpacing.spaceMD),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.2),
                    DesignColors.background
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.spaceMD),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.spaceSM - 2,
                            vertical: AppSpacing.spaceXS - 2),
                        decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.spaceXS)),
                        child: const Text('LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                      ),
                      const Spacer(),
                      Text(room.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                              color: DesignColors.white,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.spaceXS),
                      Row(children: [
                        Icon(Icons.remove_red_eye_outlined,
                            size: AppSpacing.spaceMD - 1, color: color),
                        const SizedBox(width: AppSpacing.spaceXS - 1),
                        Text('${room.viewerCount}',
                            style: AppTypography.captionSm.copyWith(
                                color: color, fontWeight: FontWeight.w600)),
                        const SizedBox(width: AppSpacing.spaceSM - 2),
                        const Icon(Icons.videocam_outlined,
                            size: 11, color: DesignColors.textGray),
                        const SizedBox(width: AppSpacing.spaceXS - 1),
                        Text('${room.camCount}',
                            style: AppTypography.captionSm),
                      ]),
                    ]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Match Inbox Tab
  Widget _buildMatchInboxTab() {
    return const MatchInboxPage();
  }

  Widget _buildSpeedDatingTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppSizes.avatarHero,
              height: AppSizes.avatarHero,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignColors.gold.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                      color: DesignColors.gold.withValues(alpha: 0.3),
                      blurRadius: 30)
                ],
              ),
              child: const Icon(Icons.bolt, size: 52, color: DesignColors.gold),
            ),
            const SizedBox(height: AppSpacing.spaceXL),
            const Text(
              'SPEED DATING',
              style: TextStyle(
                  color: DesignColors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: DesignColors.secondaryGlow),
            ),
            const SizedBox(height: AppSpacing.spaceSM + 2),
            const Text(
              'Match. Connect. Vibe. — 5-minute video dates.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: AppSpacing.spaceXXL + 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/speed-dating'),
              child: Container(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [DesignColors.gold, Color(0xFFFF6B35)]),
                  borderRadius:
                      BorderRadius.circular(AppSizes.buttonBorderRadius + 10),
                  boxShadow: [
                    BoxShadow(
                        color: DesignColors.gold.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: const Text(
                  'START SPEED DATING',
                  style: AppTypography.buttonLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsTab() {
    return const RoomDiscoveryPage();
  }

  /// Feed Tab — Facebook-style social news feed
  Widget _buildFeedTab() {
    return const SocialFeedPage();
  }

  /// Chats Tab
  Widget _buildChatsTab() {
    return const ChatListPage();
  }

  /// Profile Tab
  Widget _buildProfileTab() {
    return const ProfilePage();
  }
}

// ══════════════════════════════════════════════════════════
//  DATA CLASSES
// ══════════════════════════════════════════════════════════

@immutable
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
