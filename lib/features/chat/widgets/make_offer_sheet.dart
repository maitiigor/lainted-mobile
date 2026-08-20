import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';

/// Amount-entry sheet reused for both making a fresh offer and countering
/// an existing one. The 30%-of-price lowball hint here is a client-side
/// convenience only - the backend's `Offer.is_lowball` accessor is the
/// actual source of truth once the offer is submitted.
class MakeOfferSheet extends StatefulWidget {
  const MakeOfferSheet({
    super.key,
    required this.listingPrice,
    required this.title,
    this.initialAmount,
  });

  final double listingPrice;
  final String title;
  final double? initialAmount;

  @override
  State<MakeOfferSheet> createState() => _MakeOfferSheetState();
}

class _MakeOfferSheetState extends State<MakeOfferSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialAmount != null
        ? widget.initialAmount!.toStringAsFixed(0)
        : '',
  );

  double? get _amount => double.tryParse(_controller.text);

  bool get _isLowball {
    final amount = _amount;
    return amount != null && amount < widget.listingPrice * 0.30;
  }

  bool get _isValid {
    final amount = _amount;
    return amount != null && amount > 0 && amount <= widget.listingPrice;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Asking price: ${Formatters.currency(widget.listingPrice)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            // Not TextInputType.number - iOS's numeric keypad has a
            // long-standing bug where the caret gets stuck and can't be
            // moved past the first couple of characters. The standard
            // keyboard has correct cursor behavior; digits-only is still
            // enforced below regardless of which keyboard is shown.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              // `prefixText` merges into the same text layout the caret
              // navigates, which on iOS can block the cursor from ever
              // reaching the field's very start - `prefixIcon` renders as
              // a genuinely separate widget area instead, sidestepping it.
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: AppSpacing.md),
                child: Text('₦'),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: 'Your offer amount',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_isLowball) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This is below 30% of the asking price.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isValid ? () => Navigator.pop(context, _amount) : null,
              child: const Text('Send offer'),
            ),
          ),
        ],
      ),
    );
  }
}
