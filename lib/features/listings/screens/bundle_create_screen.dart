import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/formatters.dart';
import '../providers/bundles_provider.dart';
import '../providers/listings_provider.dart';

class BundleCreateScreen extends ConsumerStatefulWidget {
  const BundleCreateScreen({super.key});

  @override
  ConsumerState<BundleCreateScreen> createState() =>
      _BundleCreateScreenState();
}

class _BundleCreateScreenState extends ConsumerState<BundleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _requiredCountController = TextEditingController(text: '2');
  final _priceController = TextEditingController();

  final Set<String> _selectedIds = {};
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least 2 listings to bundle.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(bundlesProvider.notifier).createBundle(
        title: _titleController.text.trim(),
        requiredItemCount: int.parse(_requiredCountController.text.trim()),
        bundlePrice: double.parse(_priceController.text.trim()),
        listingIds: _selectedIds.toList(),
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessageFrom(e, fallback: 'Could not create this bundle.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _requiredCountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(myListingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create bundle')),
      body: listingsAsync.when(
        data: (listings) {
          final active = listings.where((l) => l.isActive).toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _requiredCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Items required',
                            ),
                            validator: (value) {
                              final n = int.tryParse((value ?? '').trim());
                              return (n == null || n < 2)
                                  ? 'At least 2'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Bundle price (₦)',
                            ),
                            validator: (value) {
                              final n = double.tryParse((value ?? '').trim());
                              return (n == null || n <= 0)
                                  ? 'Enter a valid price'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Pick listings for this bundle',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (active.isEmpty)
                      Text(
                        'You need at least 2 active listings to create a bundle.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textMuted),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: active.length,
                          itemBuilder: (context, index) {
                            final listing = active[index];
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _selectedIds.contains(listing.id),
                              onChanged: (checked) => setState(() {
                                if (checked ?? false) {
                                  _selectedIds.add(listing.id);
                                } else {
                                  _selectedIds.remove(listing.id);
                                }
                              }),
                              title: Text(listing.title),
                              subtitle: Text(Formatters.currency(listing.price)),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.surface,
                                ),
                              )
                            : const Text('Create bundle'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Could not load your listings.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
