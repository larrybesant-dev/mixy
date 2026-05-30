import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/async_state_view.dart';
import '../providers/after_dark_provider.dart';
import '../theme/after_dark_theme.dart';

const _edSurface = EmberDark.surface;

/// Persistent shell wrapping every After Dark screen.
class AfterDarkShell extends ConsumerWidget {
  final Widget child;
  const AfterDarkShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionActive = ref.watch(afterDarkSessionProvider);

    // Guard: if the session was cleared (app restart, manual lock, or direct URL
    // navigation) redirect immediately to the PIN unlock screen.
    if (!sessionActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/after-dark/unlock');
      });
      return const Scaffold(
        backgroundColor: EmberDark.surface,
        body: Center(child: AppLoadingView(label: 'Locking After Dark...')),
      );
    }

    final path = GoRouterState.of(context).uri.path;
    final tabIndex = path.startsWith('/after-dark/lounges')
        ? 1
        : path.startsWith('/after-dark/profile')
        ? 2
        : 0;

    return Scaffold(
      backgroundColor: _edSurface,
      appBar: _AfterDarkTopBar(
        onExit: () {
          ref.read(afterDarkControllerProvider).lock();
          context.go('/');
        },
      ),
      body: child,
      bottomNavigationBar: _AfterDarkTabBar(
        currentIndex: tabIndex,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/after-dark');
            case 1:
              context.go('/after-dark/lounges');
            case 2:
              context.go('/after-dark/profile');
          }
        },
      ),
    );
  }
}

// ── Top AppBar with branding + exit ──────────────────────────────────────────
class _AfterDarkTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onExit;
  const _AfterDarkTopBar({required this.onExit});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: EmberDark.surface,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [EmberDark.secondary, EmberDark.primary],
        ).createShader(bounds),
        child: Text(
          'After Dark',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: 0.4,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      actions: [
        Tooltip(
          message: 'Exit After Dark',
          child: TextButton.icon(
            onPressed: onExit,
            icon: const Icon(
              Icons.wb_sunny_outlined,
              size: 16,
              color: EmberDark.onSurfaceVariant,
            ),
            label: Text(
              'Exit',
              style: GoogleFonts.raleway(
                fontSize: 12,
                color: EmberDark.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bottom tab bar for After Dark sections ────────────────────────────────────
class _AfterDarkTabBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _AfterDarkTabBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      BottomNavigationBarItem(
        icon: Icon(Icons.local_fire_department_outlined),
        activeIcon: Icon(Icons.local_fire_department_rounded),
        label: 'Feed',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.meeting_room_outlined),
        activeIcon: Icon(Icons.meeting_room_rounded),
        label: 'Lounges',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: EmberDark.surfaceHigh,
      selectedItemColor: EmberDark.primary,
      unselectedItemColor: EmberDark.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.raleway(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.raleway(fontSize: 11),
      items: items,
    );
  }
}



