import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/responsive/responsive_utils.dart';
import '../core/theme/enhanced_theme.dart';
import '../core/animations/app_animations.dart';
import '../app/app_routes.dart';
import '../shared/widgets/club_background.dart';
import '../shared/widgets/glow_text.dart';

/// Onboarding page provider using NotifierProvider instead of deprecated StateProvider
final onboardingPageProvider =
    NotifierProvider<OnboardingPageNotifier, int>(() {
  return OnboardingPageNotifier();
});

class OnboardingPageNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setPage(int page) => state = page;
  void nextPage() => state++;
  void previousPage() {
    if (state > 0) state--;
  }
}

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;

  final List<OnboardingPageData> _pages = [
    const OnboardingPageData(
      title: 'Welcome to Mix & Mingle',
      subtitle: 'Connect with amazing people through video chat',
      icon: Icons.waving_hand,
      color: Color(0xFF8F00FF),
      description:
          'Join live conversations, make new friends, and discover exciting communities.',
    ),
    const OnboardingPageData(
      title: 'Safe & Fun Environment',
      subtitle: 'Your safety is our priority',
      icon: Icons.security,
      color: Color(0xFF00E6FF),
      description:
          'We use advanced moderation and community guidelines to keep everyone safe.',
    ),
    const OnboardingPageData(
      title: 'Real-time Video Chat',
      subtitle: 'Experience seamless video conversations',
      icon: Icons.videocam,
      color: Color(0xFFFF006B),
      description:
          'High-quality video calls with friends and communities around the world.',
    ),
    const OnboardingPageData(
      title: 'Discover & Connect',
      subtitle: 'Find your perfect match',
      icon: Icons.favorite,
      color: Color(0xFFFFB800),
      description:
          'Browse rooms, join conversations, and meet people with similar interests.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: EnhancedTheme.normalAnimation,
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    ref.read(onboardingPageProvider.notifier).setPage(page);
    _animationController.reset();
    _animationController.forward();
  }

  void _nextPage() {
    final currentPage = ref.read(onboardingPageProvider);
    if (currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: EnhancedTheme.normalAnimation,
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingPageProvider);
    final isLastPage = currentPage == _pages.length - 1;

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: Responsive.responsivePadding(context),
                child: Align(
                  alignment: Alignment.topRight,
                  child: AppAnimations.fadeIn(
                    child: TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: Responsive.responsiveFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildOnboardingPage(
                      _pages[index],
                      index == currentPage,
                    );
                  },
                ),
              ),

              // Page indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildPageIndicator(index, currentPage),
                  ),
                ),
              ),

              // Navigation buttons
              Padding(
                padding: Responsive.responsivePadding(context),
                child: SizedBox(
                  width: double.infinity,
                  child: AppAnimations.scaleIn(
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.responsiveSpacing(context, 16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.responsiveBorderRadius(context, 12),
                          ),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Get Started' : 'Next',
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: Responsive.responsiveSpacing(context, 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingPageData page, bool isActive) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeIn,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: Responsive.responsivePadding(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with glow effect
                  Container(
                    width: Responsive.responsiveValue(
                      context: context,
                      mobile: 120.0,
                      tablet: 160.0,
                      desktop: 200.0,
                    ),
                    height: Responsive.responsiveValue(
                      context: context,
                      mobile: 120.0,
                      tablet: 160.0,
                      desktop: 200.0,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: page.color.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: page.color.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      page.icon,
                      size: Responsive.responsiveIconSize(context, 60),
                      color: page.color,
                    ),
                  ),

                  SizedBox(height: Responsive.responsiveSpacing(context, 48)),

                  // Title
                  GlowText(
                    text: page.title,
                    fontSize: Responsive.responsiveFontSize(context, 28),
                    fontWeight: FontWeight.bold,
                  ),

                  SizedBox(height: Responsive.responsiveSpacing(context, 16)),

                  // Subtitle
                  Text(
                    page.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 18),
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
                  ),

                  SizedBox(height: Responsive.responsiveSpacing(context, 24)),

                  // Description
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.responsiveSpacing(context, 24),
                    ),
                    child: Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 16),
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator(int index, int currentPage) {
    final isActive = index == currentPage;

    return AnimatedContainer(
      duration: EnhancedTheme.fastAnimation,
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String description;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.description,
  });
}
