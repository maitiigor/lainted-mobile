import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';

/// Mobile-only, hardcoded per the product doc's named templates - no
/// backend involvement, just fills the compose field.
const quickReplyTemplates = [
  'Is this still available?',
  "What's your last price?",
  "I'll take it",
  'Can you do better?',
];

class QuickReplyChips extends StatelessWidget {
  const QuickReplyChips({super.key, required this.onSelected, this.trailing});

  final ValueChanged<String> onSelected;

  /// Rendered as one more item at the end of the same scrollable row,
  /// sharing its `separatorBuilder` spacing - a separate sibling `Row`
  /// next to this widget's own `Expanded` clipped the last template chip
  /// right at the seam, reading as the trailing widget overlapping it.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final itemCount = quickReplyTemplates.length + (trailing != null ? 1 : 0);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == quickReplyTemplates.length) return trailing!;

          final template = quickReplyTemplates[index];

          return ActionChip(
            label: Text(template),
            onPressed: () => onSelected(template),
          );
        },
      ),
    );
  }
}
