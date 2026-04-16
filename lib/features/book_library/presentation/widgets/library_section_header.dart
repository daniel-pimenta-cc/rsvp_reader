import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// Uppercase tracked section header used to separate the In Progress /
/// Not Started / Read groups within the library.
class LibrarySectionHeader extends StatelessWidget {
  final String label;
  final int? count;

  const LibrarySectionHeader({required this.label, this.count, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.sectionHeader(scheme),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
