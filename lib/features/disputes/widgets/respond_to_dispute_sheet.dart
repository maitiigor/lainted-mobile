import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_spacing.dart';

class RespondToDisputeResult {
  const RespondToDisputeResult({required this.statement, this.offerAmount});

  final String statement;
  final double? offerAmount;
}

/// Seller's response to a dispute - a statement is always required; the
/// offer amount is optional (omitting it skips straight to admin review,
/// see DisputeService::respondAsSeller on the backend). An offer above
/// the item price is rejected server-side with a clear error message.
class RespondToDisputeSheet extends StatefulWidget {
  const RespondToDisputeSheet({super.key});

  @override
  State<RespondToDisputeSheet> createState() => _RespondToDisputeSheetState();
}

class _RespondToDisputeSheetState extends State<RespondToDisputeSheet> {
  final _statementController = TextEditingController();
  final _offerController = TextEditingController();

  @override
  void dispose() {
    _statementController.dispose();
    _offerController.dispose();
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
          Text('Respond to this dispute', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _statementController,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Give your side of the story.'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Offer a partial refund (optional)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _offerController,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: AppSpacing.md),
                child: Text('₦'),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: 'Leave blank to send this straight to our support team',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _statementController.text.trim().isEmpty
                  ? null
                  : () {
                      final offer = double.tryParse(_offerController.text);
                      Navigator.pop(
                        context,
                        RespondToDisputeResult(
                          statement: _statementController.text.trim(),
                          offerAmount: offer != null && offer > 0 ? offer : null,
                        ),
                      );
                    },
              child: const Text('Submit response'),
            ),
          ),
        ],
      ),
    );
  }
}
