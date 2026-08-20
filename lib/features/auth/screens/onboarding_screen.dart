import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/providers/onboarding_prefs_provider.dart';

class _Slide {
  const _Slide(this.imageAsset, this.icon, this.title, this.body);

  /// Falls back to [icon] via Image.asset's errorBuilder if this file
  /// hasn't been dropped into assets/images/ yet - see the doc comment
  /// on OnboardingScreen for the exact filenames expected.
  final String imageAsset;
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    'assets/images/onboarding_buy.jpg',
    Icons.storefront_outlined,
    'Buy near you',
    'Find affordable secondhand fashion from people in your own area.',
  ),
  _Slide(
    'assets/images/onboarding_sell.jpg',
    Icons.sell_outlined,
    'Sell in minutes',
    'Turn your old clothes into cash with a simple listing flow.',
  ),
  _Slide(
    'assets/images/onboarding_protected.jpg',
    Icons.shield_outlined,
    'Every transaction protected',
    'Chat stays private, payments stay in-app, and escrow protects both sides.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  Future<void> _finish() async {
    await ref.read(onboardingPrefsProvider).markOnboardingSeen();
    if (!mounted) return;
    context.go('/auth/phone');
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = MediaQuery.of(context).size.height * 0.55;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      const heroRadius = BorderRadius.only(
                        bottomLeft: Radius.circular(AppSpacing.radiusLg),
                        bottomRight: Radius.circular(AppSpacing.radiusLg),
                      );

                      return Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: heroRadius,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.textPrimary.withValues(alpha: 0.14),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: heroRadius,
                              child: SizedBox(
                                height: heroHeight,
                                width: double.infinity,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      slide.imageAsset,
                                      fit: BoxFit.cover,
                                      // Bounds decode memory regardless of the
                                      // source file's resolution - already a
                                      // physical-pixel value, comfortably above
                                      // any phone's rendered width for this layout.
                                      cacheWidth: 1200,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: AppColors.accent.withValues(alpha: 0.3),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          slide.icon,
                                          size: 96,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    // A flat, uniform warm scrim rather than
                                    // a photographic BlendMode (overlay/
                                    // multiply) - those amplify whatever
                                    // contrast is already in the source
                                    // photo, which crushed the already-dark
                                    // shadow areas in some photos to near-
                                    // black right where the fade below
                                    // needs to be smooth. A flat alpha tint
                                    // warms every photo by the same amount
                                    // regardless of its own lighting.
                                    Container(color: AppColors.primary.withValues(alpha: 0.16)),
                                    // Fades the photo's bottom edge into the
                                    // page background instead of a hard cut -
                                    // routed through the same warm tint (not
                                    // straight to transparent) so the fade's
                                    // starting point matches the scrim above
                                    // it instead of a visible seam.
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        height: heroHeight * 0.35,
                                        decoration: BoxDecoration(
                                          // Passes through a visible warm
                                          // brand-color band on the way down
                                          // instead of rushing straight to
                                          // white - reads as an intentional
                                          // colored glow rather than the
                                          // photo just washing out pale.
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [0.0, 0.65, 1.0],
                                            colors: [
                                              AppColors.primary.withValues(alpha: 0),
                                              AppColors.primary.withValues(alpha: 0.55),
                                              AppColors.background,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                Text(
                                  slide.title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  slide.body,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _page ? AppColors.primary : AppColors.accent,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_page == _slides.length - 1) {
                          _finish();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Text(_page == _slides.length - 1 ? 'Get Started' : 'Next'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _finish,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
