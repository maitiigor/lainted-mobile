import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../auth/providers/auth_provider.dart';

const _resendCooldown = 30;

/// Doc: "Change phone number (OTP verification)". Two internal steps in
/// one screen (matching WardrobeQuickListScreen's local-step pattern
/// rather than two routes) - mirrors phone_entry_screen.dart's input and
/// otp_entry_screen.dart's Pinput, but pushed/popped as a settings
/// sub-flow rather than the auth stack's go().
class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  int _step = 0;

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '+234');
  String _phone = '';
  bool _isSubmitting = false;
  String? _errorText;
  int _secondsLeft = 0;
  Timer? _timer;

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

  Future<void> _requestOtp() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _sendOtp(_phoneController.text.trim());
    if (mounted && _errorText == null) setState(() => _step = 1);
  }

  /// Step 1's "Resend code" reuses this directly, not _requestOtp() -
  /// its Form/_formKey only exists in step 0's widget tree, so
  /// `_formKey.currentState` is null by the time step 1 is showing and
  /// re-validating there would silently no-op the resend.
  Future<void> _sendOtp(String phone) async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authProvider.notifier).requestPhoneChangeOtp(phone);
      if (!mounted) return;
      _phone = phone;
      _startCountdown();
    } catch (e) {
      setState(() => _errorText = errorMessageFrom(e, fallback: 'Could not send code.'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirm(String code) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authProvider.notifier).confirmPhoneChange(_phone, code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number updated.')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorText = errorMessageFrom(e, fallback: 'Incorrect or expired code.'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Change Phone Number')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _step == 0 ? _buildPhoneStep() : _buildOtpStep(),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Enter your new number - we'll text you a one-time code to verify it.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'New phone number',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length < 10 ? 'Enter a valid Nigerian phone number' : null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isSubmitting || _secondsLeft > 0) ? null : _requestOtp,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                    )
                  : const Text('Send Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final defaultPinTheme = PinTheme(
      width: 44,
      height: 48,
      textStyle: Theme.of(context).textTheme.headlineSmall,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.accent.withValues(alpha: 0.22),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verify your new number', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'We sent a 6-digit code to $_phone',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Pinput(
            length: 6,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration?.copyWith(
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            ),
            onCompleted: _isSubmitting ? null : _confirm,
            enabled: !_isSubmitting,
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Center(
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : TextButton(
                  onPressed: _secondsLeft == 0 ? () => _sendOtp(_phone) : null,
                  child: Text(_secondsLeft == 0 ? 'Resend code' : 'Resend code in ${_secondsLeft}s'),
                ),
        ),
      ],
    );
  }
}
