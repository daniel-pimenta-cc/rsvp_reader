import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Container that groups related controls in a settings-style layout.
/// Uses the global theme (surfaceContainer + outline) — **do not** use this
/// for anything inside the reader's display-settings preview, whose colours
/// come from `DisplaySettings`, not the theme.
class SectionCard extends StatelessWidget {
  final String? header;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    this.header,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              header!.toUpperCase(),
              style: AppTypography.sectionHeader(scheme),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}
