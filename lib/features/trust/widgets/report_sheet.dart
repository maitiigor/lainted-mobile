import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../providers/reports_provider.dart';

const _reasons = ['Spam', 'Scam or fraud', 'Inappropriate content', 'Harassment', 'Other'];

/// Shared by both report entry points (a listing, or a user from chat) -
/// the backend's polymorphic Report model takes the same shape either
/// way, only [reportableType]/[reportableId] differ.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.reportableType, required this.reportableId});

  final String reportableType;
  final String reportableId;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _descriptionController = TextEditingController();
  String _reason = _reasons.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(reportsServiceProvider).create(
            reportableType: widget.reportableType,
            reportableId: widget.reportableId,
            reason: _reason,
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Our team will review it.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageFrom(e, fallback: 'Could not submit this report.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          Text(
            widget.reportableType == 'listing' ? 'Report this listing' : 'Report this user',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (value) => setState(() => _reason = value ?? _reason),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Add details (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(_isSubmitting ? 'Submitting…' : 'Submit Report'),
            ),
          ),
        ],
      ),
    );
  }
}
