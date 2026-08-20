import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/subscription_plan.dart';
import '../../auth/providers/auth_provider.dart';
import '../../listings/providers/listings_provider.dart';
import '../providers/subscription_checkout_provider.dart';
import '../providers/subscription_plans_provider.dart';

/// Business sellers are auto-placed on the Free plan; this shows the
/// current plan, listing-cap usage, and lets them pay to upgrade -
/// one-time 30-day charges via Paystack, not recurring billing (see
/// SubscriptionPaymentService on the backend for why).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final listingsAsync = ref.watch(myListingsProvider);
    final currentPlan = user?.activeSubscription?.plan;

    final activeListingCount = listingsAsync.value?.where((l) => l.status == ListingStatus.active).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Current plan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentPlan?.name ?? 'Free',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentPlan == null || currentPlan.price == 0
                        ? 'No cost'
                        : '${Formatters.currency(currentPlan.price)}/month',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    currentPlan?.maxActiveListings != null
                        ? 'Listings: $activeListingCount / ${currentPlan!.maxActiveListings} used'
                        : 'Listings: $activeListingCount used (unlimited)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Other plans', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            plansAsync.when(
              data: (plans) => Column(
                children: plans
                    .where((p) => p.code != currentPlan?.code)
                    .map((plan) => _PlanTile(plan: plan))
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text(
                'Could not load other plans.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends ConsumerStatefulWidget {
  const _PlanTile({required this.plan});

  final SubscriptionPlan plan;

  @override
  ConsumerState<_PlanTile> createState() => _PlanTileState();
}

class _PlanTileState extends ConsumerState<_PlanTile> {
  bool _isSubmitting = false;

  Future<void> _upgrade(String email) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final result = await ref.read(subscriptionCheckoutServiceProvider).checkout(widget.plan);
      if (!mounted) return;

      await FlutterPaystackPlus.openPaystackPopup(
        context: context,
        customerEmail: email,
        amount: (widget.plan.price * 100).round().toString(),
        reference: result.reference,
        authorizationUrl: result.authorizationUrl,
        callBackUrl: ApiConstants.paystackCallbackUrl,
        onSuccess: () async {
          // Untrusted client signal only - same pattern as order checkout.
          try {
            await ref.read(authProvider.notifier).confirmSubscriptionPayment(result.reference);
          } catch (_) {
            // Fall through - the webhook may still confirm it server-side.
          }
        },
        onClosed: () {},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessageFrom(e, fallback: 'Could not start checkout.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).value?.email;
    final plan = widget.plan;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  plan.maxActiveListings != null ? 'Up to ${plan.maxActiveListings} listings' : 'Unlimited listings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${Formatters.currency(plan.price)}/mo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (email == null)
                SizedBox(
                  width: 140,
                  child: Text(
                    'Add an email in Edit Profile to subscribe',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _upgrade(email),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Upgrade'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
