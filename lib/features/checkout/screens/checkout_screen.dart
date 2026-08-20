import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery_address.dart';
import '../../../shared/models/lga.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/offer.dart';
import '../../../shared/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/lga_provider.dart';
import '../providers/checkout_provider.dart';
import '../providers/delivery_addresses_provider.dart';

/// Flat placeholder fee per tier, mirroring OrderService's own map exactly
/// - purely a cosmetic preview here, the backend response is authoritative.
const _deliveryFees = {
  DeliveryTier.pickup: 0.0,
  DeliveryTier.standard: 1500.0,
  DeliveryTier.bulky: 5000.0,
  DeliveryTier.furniture: 15000.0,
};

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen.fromOffer({super.key, required this.offer}) : listing = null;

  const CheckoutScreen.fromListing({super.key, required this.listing}) : offer = null;

  final Offer? offer;
  final Listing? listing;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  DeliveryAddress? _selectedAddress;
  DeliveryTier _tier = DeliveryTier.pickup;
  PaymentMethod _method = PaymentMethod.online;
  late final TextEditingController _emailController;
  bool _isSubmitting = false;

  /// Live Sendbox quote for the selected tier+address, once it resolves -
  /// null (falling back to the flat estimate below) while loading, on
  /// failure, or for Pickup (never quoted at all). Purely a preview:
  /// checkoutFromOffer/checkoutFromListing always re-quote fresh
  /// server-side regardless of what this shows.
  double? _liveFee;
  bool _isQuoting = false;
  Timer? _quoteDebounce;

  Listing get _listing => widget.offer?.listing ?? widget.listing!;
  double get _itemPrice => widget.offer?.amount ?? _listing.price;
  double get _protectionFee =>
      _method == PaymentMethod.online ? double.parse((_itemPrice * 0.015).toStringAsFixed(2)) : 0.0;
  double get _deliveryFee => _liveFee ?? _deliveryFees[_tier] ?? 0.0;
  double get _total => _itemPrice + _protectionFee + _deliveryFee;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: ref.read(authProvider).value?.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _quoteDebounce?.cancel();
    super.dispose();
  }

  void _onTierChanged(DeliveryTier tier) {
    setState(() => _tier = tier);
    _scheduleQuote();
  }

  void _onAddressChanged(DeliveryAddress address) {
    setState(() => _selectedAddress = address);
    _scheduleQuote();
  }

  void _scheduleQuote() {
    _quoteDebounce?.cancel();

    final address = _selectedAddress;
    if (_tier == DeliveryTier.pickup || address == null) {
      setState(() => _liveFee = null);
      return;
    }

    // Falls straight back to the flat estimate while this is in flight -
    // never leaves the total blank/stuck.
    setState(() {
      _liveFee = null;
      _isQuoting = true;
    });

    _quoteDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final fee = await ref.read(checkoutProvider.notifier).getDeliveryQuote(
              listingId: _listing.id,
              deliveryAddressId: address.id,
              tier: _tier,
            );
        if (mounted) setState(() => _liveFee = fee);
      } catch (_) {
        // Silent - _deliveryFee already falls back to the flat estimate.
      } finally {
        if (mounted) setState(() => _isQuoting = false);
      }
    });
  }

  Future<void> _addAddress() async {
    final address = await showModalBottomSheet<DeliveryAddress>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddAddressSheet(),
    );
    if (address != null && mounted) {
      _onAddressChanged(address);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final address = _selectedAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a delivery address first.')),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (_method == PaymentMethod.online && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an email address to pay online.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = widget.offer != null
          ? await ref.read(checkoutProvider.notifier).checkoutFromOffer(
                widget.offer!.id,
                deliveryAddressId: address.id,
                tier: _tier,
                method: _method,
                email: email,
              )
          : await ref.read(checkoutProvider.notifier).checkoutFromListing(
                widget.listing!.id,
                deliveryAddressId: address.id,
                tier: _tier,
                method: _method,
                email: email,
              );

      if (!mounted) return;

      final authorizationUrl = result.authorizationUrl;
      final reference = result.reference;
      if (authorizationUrl == null || reference == null) {
        // Cash on delivery - already confirmed, nothing to pay online.
        context.go('/orders/${result.order.id}');
        return;
      }

      await FlutterPaystackPlus.openPaystackPopup(
        context: context,
        customerEmail: email,
        amount: (_total * 100).round().toString(),
        reference: reference,
        authorizationUrl: authorizationUrl,
        callBackUrl: ApiConstants.paystackCallbackUrl,
        onSuccess: () async {
          // Untrusted client signal only - the package skips its own
          // verification in authorizationUrl mode, so this always hits our
          // backend's server-side Paystack verify before treating the
          // order as paid.
          try {
            final order = await ref
                .read(checkoutProvider.notifier)
                .confirmPayment(result.order.id, reference);
            if (mounted) context.go('/orders/${order.id}');
          } catch (_) {
            if (mounted) context.go('/orders/${result.order.id}');
          }
        },
        onClosed: () {
          // Cancelled, or the WebView just closed before completing - the
          // webhook may still land server-side, so don't assume failure.
          // Order Detail's pull-to-refresh is the fallback for checking.
          if (mounted) context.go('/orders/${result.order.id}');
        },
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
    final addressesAsync = ref.watch(deliveryAddressesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_listing.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Text('Delivery address', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              addressesAsync.when(
                data: (addresses) {
                  if (_selectedAddress != null &&
                      !addresses.any((a) => a.id == _selectedAddress!.id)) {
                    _selectedAddress = null;
                  }

                  return RadioGroup<String>(
                    groupValue: _selectedAddress?.id,
                    onChanged: (id) => _onAddressChanged(addresses.firstWhere((a) => a.id == id)),
                    child: Column(
                      children: [
                        for (final address in addresses)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: address.id,
                            title: Text(address.summary),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addAddress,
                            icon: const Icon(Icons.add),
                            label: const Text('Add new address'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text(
                  'Could not load addresses.',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Delivery method', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<DeliveryTier>(
                groupValue: _tier,
                onChanged: (value) => _onTierChanged(value!),
                child: Column(
                  children: [
                    for (final tier in DeliveryTier.values)
                      RadioListTile<DeliveryTier>(
                        contentPadding: EdgeInsets.zero,
                        value: tier,
                        title: Text(_tierLabel(tier)),
                        subtitle: Text(
                          _deliveryFees[tier] == 0 ? 'Free' : Formatters.currency(_deliveryFees[tier]!),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Payment method', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<PaymentMethod>(
                groupValue: _method,
                onChanged: (value) => setState(() => _method = value!),
                child: Column(
                  children: [
                    RadioListTile<PaymentMethod>(
                      contentPadding: EdgeInsets.zero,
                      value: PaymentMethod.online,
                      title: const Text('Pay online (card, transfer, USSD)'),
                    ),
                    RadioListTile<PaymentMethod>(
                      contentPadding: EdgeInsets.zero,
                      value: PaymentMethod.cashOnDelivery,
                      title: const Text('Cash on delivery'),
                    ),
                  ],
                ),
              ),
              if (_method == PaymentMethod.online) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email for payment receipt'),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _SummaryRow(label: 'Item price', value: _itemPrice),
              if (_protectionFee > 0)
                _SummaryRow(label: 'Protection fee (1.5%)', value: _protectionFee),
              _SummaryRow(label: 'Delivery fee', value: _deliveryFee, isLoading: _isQuoting),
              const Divider(),
              _SummaryRow(label: 'Total', value: _total, isBold: true),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Please wait…' : 'Confirm and pay'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tierLabel(DeliveryTier tier) {
    switch (tier) {
      case DeliveryTier.pickup:
        return 'Pickup (meet the seller)';
      case DeliveryTier.standard:
        return 'Standard delivery (bike)';
      case DeliveryTier.bulky:
        return 'Bulky delivery (car)';
      case DeliveryTier.furniture:
        return 'Furniture delivery (van/truck)';
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isLoading = false,
  });

  final String label;
  final double value;
  final bool isBold;

  /// Shows a small inline spinner next to the flat-estimate value while a
  /// live Sendbox quote is in flight - the number itself never disappears.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Row(
            children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(Formatters.currency(value), style: style),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddAddressSheet extends ConsumerStatefulWidget {
  const _AddAddressSheet();

  @override
  ConsumerState<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  final _landmarkController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  Lga? _selectedLga;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _landmarkController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _selectedLga != null &&
      _landmarkController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_isSubmitting || !_isValid) return;
    setState(() => _isSubmitting = true);

    try {
      final address = await ref.read(deliveryAddressesProvider.notifier).create(
            lgaId: _selectedLga!.id,
            landmark: _landmarkController.text.trim(),
            fullAddress: _addressController.text.trim(),
            recipientPhone: _phoneController.text.trim(),
          );
      if (mounted) Navigator.pop(context, address);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not save this address.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lgasAsync = ref.watch(lgaListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New delivery address', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          lgasAsync.when(
            data: (lgas) => Autocomplete<Lga>(
              displayStringForOption: (lga) => '${lga.name}, ${lga.state}',
              optionsBuilder: (value) {
                if (value.text.isEmpty) return const Iterable<Lga>.empty();
                return lgas.where(
                  (lga) => lga.name.toLowerCase().contains(value.text.toLowerCase()),
                );
              },
              onSelected: (lga) => setState(() => _selectedLga = lga),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(hintText: 'Search your LGA'),
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const Text('Could not load LGAs.'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _landmarkController,
            decoration: const InputDecoration(hintText: 'Landmark (e.g. Near the big mango tree)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Full address'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Recipient phone number'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isValid && !_isSubmitting ? _submit : null,
              child: Text(_isSubmitting ? 'Saving…' : 'Save address'),
            ),
          ),
        ],
      ),
    );
  }
}
