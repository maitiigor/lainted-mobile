import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A single "value over label" stat column - shared between
/// PublicProfileScreen's rating/sales/trust-score row and
/// MyListingsScreen's wardrobe stats row rather than duplicating it.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}
