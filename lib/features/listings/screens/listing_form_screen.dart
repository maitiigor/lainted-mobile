import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/lga.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/lga_provider.dart';
import '../providers/category_provider.dart';
import '../providers/listings_provider.dart';

const _grades = ['A++', 'A+', 'A', 'B', 'C', 'D', 'X'];
const _baleTypes = ['premium', 'mixed', 'economy', 'sorted'];

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.listingId});

  /// Null when creating a new listing; set when editing an existing one.
  final String? listingId;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _faultDescriptionController = TextEditingController();
  final _sizeController = TextEditingController();
  final _priceController = TextEditingController();
  final _minimumPriceController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _baleItemCountController = TextEditingController();
  final _baleOriginCountryController = TextEditingController();

  Category? _selectedCategory;
  String _grade = 'A';
  bool _isNegotiable = true;
  Lga? _selectedLga;
  bool _isBale = false;
  String? _baleType;
  bool _isWardrobeCleanout = false;

  bool _isLoadingExisting = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.listingId != null;

  @override
  void initState() {
    super.initState();
    if (widget.listingId != null) {
      _loadExisting(widget.listingId!);
    }
  }

  Future<void> _loadExisting(String id) async {
    setState(() => _isLoadingExisting = true);
    try {
      final listing = await ref.read(myListingsProvider.notifier).getListing(id);
      if (!mounted) return;

      final categories = await ref.read(categoryListProvider.future);
      final lgas = await ref.read(lgaListProvider.future);
      if (!mounted) return;

      setState(() {
        _titleController.text = listing.title;
        _descriptionController.text = listing.description;
        _faultDescriptionController.text = listing.faultDescription ?? '';
        _sizeController.text = listing.size ?? '';
        _priceController.text = listing.price.toStringAsFixed(0);
        _minimumPriceController.text =
            listing.minimumPrice?.toStringAsFixed(0) ?? '';
        _landmarkController.text = listing.landmark ?? '';
        _baleItemCountController.text =
            listing.baleItemCount?.toString() ?? '';
        _baleOriginCountryController.text = listing.baleOriginCountry ?? '';

        _grade = listing.conditionGrade;
        _isNegotiable = listing.isNegotiable;
        _isBale = listing.isBale;
        _baleType = listing.baleType?.name;
        _isWardrobeCleanout = listing.isWardrobeCleanout;
        _selectedCategory = categories.firstWhereOrNull(
          (c) => c.id == listing.categoryId,
        );
        _selectedLga = lgas.firstWhereOrNull((l) => l.id == listing.lgaId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessageFrom(e, fallback: 'Could not load this listing.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a category.')),
      );
      return;
    }
    if (_selectedLga == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick an LGA.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final data = {
      'category_id': _selectedCategory!.id,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'condition_grade': _grade,
      if (_faultDescriptionController.text.trim().isNotEmpty)
        'fault_description': _faultDescriptionController.text.trim(),
      if (_sizeController.text.trim().isNotEmpty)
        'size': _sizeController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0,
      'is_negotiable': _isNegotiable,
      if (_isNegotiable && _minimumPriceController.text.trim().isNotEmpty)
        'minimum_price': double.tryParse(_minimumPriceController.text.trim()),
      'lga_id': _selectedLga!.id,
      if (_landmarkController.text.trim().isNotEmpty)
        'landmark': _landmarkController.text.trim(),
      'is_bale': _isBale,
      if (_isBale) 'bale_type': _baleType,
      if (_isBale)
        'bale_item_count': int.tryParse(_baleItemCountController.text.trim()),
      if (_isBale) 'bale_origin_country': _baleOriginCountryController.text.trim(),
      'is_wardrobe_cleanout': _isWardrobeCleanout,
    };

    try {
      final notifier = ref.read(myListingsProvider.notifier);

      if (_isEditing) {
        await notifier.updateListing(widget.listingId!, data);
        if (!mounted) return;
        context.pop();
      } else {
        final created = await notifier.createListing(data);
        if (!mounted) return;
        context.pushReplacement('/listings/${created.id}/photos');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessageFrom(e, fallback: 'Could not save this listing.'),
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
    _descriptionController.dispose();
    _faultDescriptionController.dispose();
    _sizeController.dispose();
    _priceController.dispose();
    _minimumPriceController.dispose();
    _landmarkController.dispose();
    _baleItemCountController.dispose();
    _baleOriginCountryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final sellerTypeName = user?.sellerType.name ?? 'none';
    final categoriesAsync = ref.watch(categoryListProvider);
    final lgasAsync = ref.watch(lgaListProvider);
    final sectionLabelStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit listing' : 'New listing'),
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Title is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Description is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          categoriesAsync.when(
                            data: (categories) {
                              final leaves = categories
                                  .where((c) => !c.isTopLevel)
                                  .toList();

                              return DropdownButtonFormField<Category>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: leaves
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _selectedCategory = value),
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (error, stack) => Text(
                              'Could not load categories.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Condition', style: sectionLabelStyle),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final grade in _grades)
                                ChoiceChip(
                                  label: Text(grade),
                                  selected: _grade == grade,
                                  selectedColor: AppColors.gradeColor(grade),
                                  labelStyle: TextStyle(
                                    color: _grade == grade
                                        ? AppColors.surface
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _grade = grade),
                                ),
                            ],
                          ),
                          if (_grade == 'D' || _grade == 'X') ...[
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _faultDescriptionController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Describe the fault/damage',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Required for grade D/X listings'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _sizeController,
                            decoration: const InputDecoration(
                              labelText: 'Size (optional)',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Price', style: sectionLabelStyle),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price (₦)',
                              prefixIcon: Icon(Icons.sell_outlined),
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                (value ?? '').trim(),
                              );
                              return (parsed == null || parsed <= 0)
                                  ? 'Enter a valid price'
                                  : null;
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isNegotiable,
                            onChanged: (value) =>
                                setState(() => _isNegotiable = value),
                            title: const Text('Negotiable'),
                          ),
                          if (_isNegotiable)
                            TextFormField(
                              controller: _minimumPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Lowest price you\'ll accept (optional)',
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Location', style: sectionLabelStyle),
                          const SizedBox(height: AppSpacing.sm),
                          lgasAsync.when(
                            data: (lgas) => DropdownButtonFormField<Lga>(
                              initialValue: _selectedLga,
                              decoration: const InputDecoration(
                                labelText: 'LGA',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              items: lgas
                                  .map(
                                    (lga) => DropdownMenuItem(
                                      value: lga,
                                      child: Text(lga.toString()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedLga = value),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (error, stack) => Text(
                              'Could not load LGAs.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _landmarkController,
                            decoration: const InputDecoration(
                              labelText: 'Landmark (optional)',
                              prefixIcon: Icon(Icons.signpost_outlined),
                            ),
                          ),
                          if (sellerTypeName == 'business') ...[
                            const SizedBox(height: AppSpacing.lg),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _isBale,
                              onChanged: (value) =>
                                  setState(() => _isBale = value),
                              title: const Text('This is a bale (bulk lot)'),
                            ),
                            if (_isBale) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _baleType,
                                decoration: const InputDecoration(
                                  labelText: 'Bale type',
                                ),
                                items: _baleTypes
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _baleType = value),
                                validator: (value) => (_isBale && value == null)
                                    ? 'Required for bale listings'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _baleItemCountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Approximate item count',
                                ),
                                validator: (value) =>
                                    (_isBale &&
                                        (value == null || value.trim().isEmpty))
                                    ? 'Required for bale listings'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _baleOriginCountryController,
                                decoration: const InputDecoration(
                                  labelText: 'Origin country (e.g. UK, US)',
                                ),
                                validator: (value) =>
                                    (_isBale &&
                                        (value == null || value.trim().isEmpty))
                                    ? 'Required for bale listings'
                                    : null,
                              ),
                            ],
                          ],
                          if (sellerTypeName == 'personal') ...[
                            const SizedBox(height: AppSpacing.lg),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _isWardrobeCleanout,
                              onChanged: (value) =>
                                  setState(() => _isWardrobeCleanout = value),
                              title: const Text('Part of a Wardrobe Cleanout'),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
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
                                  : Text(_isEditing ? 'Save changes' : 'Continue'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
