import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/providers/onboarding_prefs_provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final user = await ref.read(authProvider.future);
    if (!mounted) return;

    if (user != null) {
      if (user.accountStatus == AccountStatus.pendingDeletion) {
        context.go('/account/restore');
        return;
      }
      context.go(user.needsProfileSetup ? '/auth/profile-setup' : '/home');
      return;
    }

    // Returning devices land on password login (no SMS cost); a brand-new
    // device sees onboarding first, which itself leads to phone/OTP signup.
    final hasSeenOnboarding = ref
        .read(onboardingPrefsProvider)
        .hasSeenOnboarding;
    context.go(hasSeenOnboarding ? '/auth/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Same asset as the native splash screen (see
              // flutter_native_splash config in pubspec.yaml) - keeps this
              // Dart-rendered splash visually continuous with it instead
              // of a flash/swap once Flutter takes over.
              // TESTING new logo mark - swap back to logo-no-bg.png to revert.
              Image.asset(
                'assets/images/splash-no-bg.jpeg',
                width: 220,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront_outlined,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
