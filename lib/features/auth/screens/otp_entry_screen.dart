import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/user.dart';
import '../providers/auth_provider.dart';

class OtpEntryScreen extends ConsumerStatefulWidget {
  const OtpEntryScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}

class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  static const _resendCooldown = 30;

  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorText;
  int _secondsLeft = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _secondsLeft = _resendCooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      await ref.read(authProvider.notifier).requestOtp(widget.phone);
      _startCountdown();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code resent.')));
    } catch (e) {
      setState(
        () => _errorText = errorMessageFrom(
          e,
          fallback: 'Could not resend code. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verify(String code) async {
    // Synchronous re-entry guard: Pinput can invoke onCompleted more than
    // once for a single completed code before the rebuild that disables it
    // takes effect, which would otherwise fire two verify requests for one
    // code - the first succeeds, the second correctly fails (already used),
    // and only the failure would be visible.
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final needsProfileSetup = await ref
          .read(authProvider.notifier)
          .verifyOtp(widget.phone, code);
      if (!mounted) return;

      final user = ref.read(authProvider).value;
      if (user?.accountStatus == AccountStatus.pendingDeletion) {
        context.go('/account/restore');
        return;
      }
      context.go(needsProfileSetup ? '/auth/set-password' : '/home');
    } catch (e) {
      setState(
        () => _errorText = errorMessageFrom(
          e,
          fallback: 'Incorrect or expired code.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 44,
      height: 48,
      textStyle: Theme.of(context).textTheme.headlineSmall,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.accent.withValues(alpha: 0.22),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify your number',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'We sent a 6-digit code to ${widget.phone}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Pinput(
                      length: 6,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: defaultPinTheme.copyWith(
                        decoration: defaultPinTheme.decoration?.copyWith(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onCompleted: _isSubmitting ? null : _verify,
                      enabled: !_isSubmitting,
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: _isSubmitting
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: (_secondsLeft == 0 && !_isResending)
                                ? _resend
                                : null,
                            child: _isResending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _secondsLeft == 0
                                        ? 'Resend code'
                                        : 'Resend code in ${_secondsLeft}s',
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
