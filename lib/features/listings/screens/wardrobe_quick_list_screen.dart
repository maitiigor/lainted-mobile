import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/lga.dart';
import '../../auth/providers/lga_provider.dart';
import '../providers/category_provider.dart';
import '../providers/listings_provider.dart';

const _grades = ['A++', 'A+', 'A', 'B', 'C', 'D', 'X'];

/// Doc: minimum photo count by condition grade - same rule
/// listing_photos_screen.dart already enforces after the fact; here it's
/// surfaced up front in step 2, since by then the grade (chosen in step
/// 1) is already known.
const _minimumPhotoCountByGrade = {
  'A++': 2,
  'A+': 2,
  'A': 3,
  'B': 3,
  'C': 4,
  'D': 5,
  'X': 5,
};

/// The doc's "3-step simplified flow" for personal sellers - Basics,
/// then Photos (in that order, not photo-first, so the grade-driven
/// minimum photo count is known before asking for photos), then Confirm.
/// `ListingFormScreen` stays untouched and keeps serving business
/// sellers, and everyone for editing - this screen is create-only.
class WardrobeQuickListScreen extends ConsumerStatefulWidget {
  const WardrobeQuickListScreen({super.key});

  @override
  ConsumerState<WardrobeQuickListScreen> createState() => _WardrobeQuickListScreenState();
}

class _WardrobeQuickListScreenState extends ConsumerState<WardrobeQuickListScreen> {
  int _step = 0;

  Category? _selectedCategory;
  String _grade = 'A';
  final _faultDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _minimumPriceController = TextEditingController();
  bool _isNegotiable = true;
  Lga? _selectedLga;

  final List<XFile> _photos = [];
  bool _isPickingPhotos = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isWardrobeCleanout = true;
  bool _titleTouched = false;
  bool _descriptionTouched = false;

  bool _isPublishing = false;

  int get _minimumPhotoCount => _minimumPhotoCountByGrade[_grade] ?? 3;

  bool get _needsFaultDescription => _grade == 'D' || _grade == 'X';

  @override
  void dispose() {
    _faultDescriptionController.dispose();
    _priceController.dispose();
    _minimumPriceController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _goBack() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
  }

  void _goNext() {
    if (_step == 0) {
      if (_selectedCategory == null || _selectedLga == null) {
        _showError('Pick a category and location.');
        return;
      }
      if ((double.tryParse(_priceController.text.trim()) ?? 0) <= 0) {
        _showError('Enter a valid price.');
        return;
      }
      if (_needsFaultDescription && _faultDescriptionController.text.trim().isEmpty) {
        _showError('Describe the fault/damage for grade $_grade.');
        return;
      }
    }

    if (_step == 1) {
      if (_photos.length < _minimumPhotoCount) {
        _showError(
          'Add at least $_minimumPhotoCount photo${_minimumPhotoCount == 1 ? '' : 's'} for grade $_grade.',
        );
        return;
      }

      if (!_titleTouched) {
        _titleController.text = '${_selectedCategory!.name} (Grade $_grade)';
      }
      if (!_descriptionTouched) {
        _descriptionController.text = 'Selling from my wardrobe.';
      }
    }

    setState(() => _step++);
  }

  Future<void> _pickPhotos() async {
    if (_isPickingPhotos) return;

    final remaining = 6 - _photos.length;
    if (remaining <= 0) {
      _showError('A listing can have at most 6 photos.');
      return;
    }

    setState(() => _isPickingPhotos = true);
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty) {
        setState(() => _photos.addAll(picked.take(remaining)));
      }
    } finally {
      if (mounted) setState(() => _isPickingPhotos = false);
    }
  }

  Future<void> _publish() async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      final notifier = ref.read(myListingsProvider.notifier);

      final created = await notifier.createListing({
        'category_id': _selectedCategory!.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'condition_grade': _grade,
        if (_needsFaultDescription) 'fault_description': _faultDescriptionController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'is_negotiable': _isNegotiable,
        if (_isNegotiable && _minimumPriceController.text.trim().isNotEmpty)
          'minimum_price': double.tryParse(_minimumPriceController.text.trim()),
        'lga_id': _selectedLga!.id,
        'is_wardrobe_cleanout': _isWardrobeCleanout,
      });

      for (final photo in _photos) {
        final bytes = await photo.readAsBytes();
        await notifier.uploadPhoto(listingUuid: created.id, bytes: bytes, filename: photo.name);
      }

      await notifier.publishListing(created.id);

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      _showError(errorMessageFrom(e, fallback: 'Could not publish this listing.'));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Sell an item (${_step + 1}/3)'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_step) {
            0 => _BasicsStep(
                selectedCategory: _selectedCategory,
                onCategoryChanged: (value) => setState(() => _selectedCategory = value),
                grade: _grade,
                onGradeChanged: (value) => setState(() => _grade = value),
                faultDescriptionController: _faultDescriptionController,
                needsFaultDescription: _needsFaultDescription,
                priceController: _priceController,
                isNegotiable: _isNegotiable,
                onNegotiableChanged: (value) => setState(() => _isNegotiable = value),
                minimumPriceController: _minimumPriceController,
                selectedLga: _selectedLga,
                onLgaChanged: (value) => setState(() => _selectedLga = value),
                onNext: _goNext,
              ),
            1 => _PhotosStep(
                photos: _photos,
                minimumPhotoCount: _minimumPhotoCount,
                grade: _grade,
                isPicking: _isPickingPhotos,
                onPick: _pickPhotos,
                onRemove: (index) => setState(() => _photos.removeAt(index)),
                onNext: _goNext,
              ),
            _ => _ConfirmStep(
                titleController: _titleController,
                onTitleChanged: () => _titleTouched = true,
                descriptionController: _descriptionController,
                onDescriptionChanged: () => _descriptionTouched = true,
                isWardrobeCleanout: _isWardrobeCleanout,
                onCleanoutChanged: (value) => setState(() => _isWardrobeCleanout = value),
                isPublishing: _isPublishing,
                onPublish: _publish,
              ),
          },
        ),
      ),
    );
  }
}

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.grade,
    required this.onGradeChanged,
    required this.faultDescriptionController,
    required this.needsFaultDescription,
    required this.priceController,
    required this.isNegotiable,
    required this.onNegotiableChanged,
    required this.minimumPriceController,
    required this.selectedLga,
    required this.onLgaChanged,
    required this.onNext,
  });

  final Category? selectedCategory;
  final ValueChanged<Category?> onCategoryChanged;
  final String grade;
  final ValueChanged<String> onGradeChanged;
  final TextEditingController faultDescriptionController;
  final bool needsFaultDescription;
  final TextEditingController priceController;
  final bool isNegotiable;
  final ValueChanged<bool> onNegotiableChanged;
  final TextEditingController minimumPriceController;
  final Lga? selectedLga;
  final ValueChanged<Lga?> onLgaChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final categoriesAsync = ref.watch(categoryListProvider);
        final lgasAsync = ref.watch(lgaListProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The basics', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            categoriesAsync.when(
              data: (categories) {
                final leaves = categories.where((c) => !c.isTopLevel).toList();

                return DropdownButtonFormField<Category>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: leaves.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: onCategoryChanged,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => const Text('Could not load categories.'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Condition', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final g in _grades)
                  ChoiceChip(
                    label: Text(g),
                    selected: grade == g,
                    selectedColor: AppColors.gradeColor(g),
                    labelStyle: TextStyle(
                      color: grade == g ? AppColors.surface : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => onGradeChanged(g),
                  ),
              ],
            ),
            if (needsFaultDescription) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: faultDescriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Describe the fault/damage'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (₦)', prefixIcon: Icon(Icons.sell_outlined)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isNegotiable,
              onChanged: onNegotiableChanged,
              title: const Text('Negotiable'),
            ),
            if (isNegotiable)
              TextField(
                controller: minimumPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Lowest price you'll accept (optional)"),
              ),
            const SizedBox(height: AppSpacing.lg),
            lgasAsync.when(
              data: (lgas) => DropdownButtonFormField<Lga>(
                initialValue: selectedLga,
                decoration: const InputDecoration(labelText: 'LGA', prefixIcon: Icon(Icons.location_on_outlined)),
                items: lgas.map((lga) => DropdownMenuItem(value: lga, child: Text(lga.toString()))).toList(),
                onChanged: onLgaChanged,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => const Text('Could not load LGAs.'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onNext, child: const Text('Next')),
            ),
          ],
        );
      },
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.photos,
    required this.minimumPhotoCount,
    required this.grade,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
    required this.onNext,
  });

  final List<XFile> photos;
  final int minimumPhotoCount;
  final String grade;
  final bool isPicking;
  final VoidCallback onPick;
  final void Function(int index) onRemove;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Add at least $minimumPhotoCount photo${minimumPhotoCount == 1 ? '' : 's'} for grade $grade condition.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (index, photo) in photos.indexed)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Image.file(File(photo.path), width: 90, height: 90, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: AppColors.error),
                      onPressed: () => onRemove(index),
                    ),
                  ),
                ],
              ),
            if (photos.length < 6)
              InkWell(
                onTap: isPicking ? null : onPick,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: isPicking
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo_outlined),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onNext, child: const Text('Next')),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.titleController,
    required this.onTitleChanged,
    required this.descriptionController,
    required this.onDescriptionChanged,
    required this.isWardrobeCleanout,
    required this.onCleanoutChanged,
    required this.isPublishing,
    required this.onPublish,
  });

  final TextEditingController titleController;
  final VoidCallback onTitleChanged;
  final TextEditingController descriptionController;
  final VoidCallback onDescriptionChanged;
  final bool isWardrobeCleanout;
  final ValueChanged<bool> onCleanoutChanged;
  final bool isPublishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirm', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Title'),
          onChanged: (_) => onTitleChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
          onChanged: (_) => onDescriptionChanged(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: isWardrobeCleanout,
          onChanged: onCleanoutChanged,
          title: const Text('Wardrobe Cleanout mode'),
          subtitle: const Text("Lets buyers know you're selling fast"),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isPublishing ? null : onPublish,
            child: isPublishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
                  )
                : const Text('Publish'),
          ),
        ),
      ],
    );
  }
}
