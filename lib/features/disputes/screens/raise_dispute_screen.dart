import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/dispute.dart';
import '../providers/disputes_provider.dart';

const _disputeTypeLabels = {
  DisputeType.notReceived: "I never received this item",
  DisputeType.gradeMismatch: "It doesn't match the listed grade",
  DisputeType.wrongItem: 'I received the wrong item',
  DisputeType.itemDamaged: 'It arrived damaged',
  DisputeType.sellerNoShow: "The seller didn't show up for pickup",
  DisputeType.other: 'Something else',
};

class RaiseDisputeScreen extends ConsumerStatefulWidget {
  const RaiseDisputeScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends ConsumerState<RaiseDisputeScreen> {
  final _statementController = TextEditingController();
  DisputeType _type = DisputeType.notReceived;
  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickAndUpload() async {
    if (_isUploading || _photoUrls.length >= 4) return;

    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      for (final file in picked.take(4 - _photoUrls.length)) {
        final bytes = await file.readAsBytes();
        final url = await ref
            .read(disputesProvider.notifier)
            .uploadPhoto(bytes: bytes, filename: file.name);
        if (mounted) setState(() => _photoUrls.add(url));
      }
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not upload photo.'));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_statementController.text.trim().isEmpty) {
      _showError('Tell us what happened.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dispute = await ref.read(disputesProvider.notifier).raise(
            widget.orderId,
            disputeType: _type,
            buyerStatement: _statementController.text.trim(),
            buyerPhotos: _photoUrls.isEmpty ? null : _photoUrls,
          );
      if (!mounted) return;
      context.pushReplacement('/disputes/${dispute.id}');
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not raise a dispute.'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Raise a dispute')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What went wrong?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<DisputeType>(
                groupValue: _type,
                onChanged: (value) => setState(() => _type = value!),
                child: Column(
                  children: [
                    for (final type in DisputeType.values)
                      RadioListTile<DisputeType>(
                        value: type,
                        title: Text(_disputeTypeLabels[type]!),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Tell us more', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _statementController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe what happened - the more detail, the faster this gets resolved.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Photos (optional)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final url in _photoUrls)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Image.network(url, width: 72, height: 72, fit: BoxFit.cover),
                    ),
                  if (_photoUrls.length < 4)
                    Material(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: InkWell(
                        onTap: _isUploading ? null : _pickAndUpload,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Center(
                            child: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                        )
                      : const Text('Submit dispute'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
