import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/lga.dart';
import '../../auth/providers/lga_provider.dart';
import '../../listings/providers/category_provider.dart';
import '../models/discovery_filters.dart';
import '../providers/discovery_provider.dart';

const _grades = ['A++', 'A+', 'A', 'B', 'C', 'D', 'X'];

Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
    ),
    builder: (context) => const FilterSheet(),
  );
}

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late DiscoveryFilters _draft;
  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = ref.read(discoveryFiltersProvider);
    _priceMinController.text = _draft.priceMin?.toStringAsFixed(0) ?? '';
    _priceMaxController.text = _draft.priceMax?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(discoveryFiltersProvider.notifier).state = _draft.copyWith(
      priceMin: double.tryParse(_priceMinController.text.trim()),
      priceMax: double.tryParse(_priceMaxController.text.trim()),
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _draft = const DiscoveryFilters();
      _priceMinController.clear();
      _priceMaxController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final lgasAsync = ref.watch(lgaListProvider);
    final sectionLabelStyle = Theme.of(context).textTheme.titleSmall;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Category', style: sectionLabelStyle),
              const SizedBox(height: AppSpacing.sm),
              categoriesAsync.when(
                data: (categories) {
                  final leaves = categories.where((c) => !c.isTopLevel).toList();

                  return DropdownButtonFormField<Category?>(
                    initialValue: leaves
                        .cast<Category?>()
                        .firstWhere((c) => c?.id == _draft.categoryId, orElse: () => null),
                    decoration: const InputDecoration(hintText: 'Any category'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Any category')),
                      for (final c in leaves) DropdownMenuItem(value: c, child: Text(c.name)),
                    ],
                    onChanged: (value) =>
                        setState(() => _draft = _draft.copyWith(categoryId: value?.id)),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Minimum grade', style: sectionLabelStyle),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final grade in _grades)
                    ChoiceChip(
                      label: Text(grade),
                      selected: _draft.minGrade == grade,
                      selectedColor: AppColors.gradeColor(grade),
                      labelStyle: TextStyle(
                        color: _draft.minGrade == grade
                            ? AppColors.surface
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) => setState(
                        () => _draft = _draft.copyWith(
                          minGrade: selected ? grade : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Price range (₦)', style: sectionLabelStyle),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceMinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _priceMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Location', style: sectionLabelStyle),
              const SizedBox(height: AppSpacing.sm),
              lgasAsync.when(
                data: (lgas) => DropdownButtonFormField<Lga?>(
                  initialValue: lgas
                      .cast<Lga?>()
                      .firstWhere((l) => l?.id == _draft.lgaId, orElse: () => null),
                  decoration: const InputDecoration(hintText: 'Any location'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any location')),
                    for (final lga in lgas) DropdownMenuItem(value: lga, child: Text('$lga')),
                  ],
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(lgaId: value?.id),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _draft.nearYou,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(nearYou: value ?? false),
                ),
                title: const Text('Near me only'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Seller type', style: sectionLabelStyle),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(value: 'wardrobe', label: Text('Personal')),
                    ButtonSegment(value: 'business', label: Text('Business')),
                  ],
                  selected: _draft.sellerType != null ? {_draft.sellerType!} : {},
                  onSelectionChanged: (selection) => setState(
                    () => _draft = _draft.copyWith(
                      sellerType: selection.isEmpty ? null : selection.first,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _apply,
                  child: const Text('Apply filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
