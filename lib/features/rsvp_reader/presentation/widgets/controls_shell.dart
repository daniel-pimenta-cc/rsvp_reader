import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class ControlsShell extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  const ControlsShell({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor.withAlpha(215),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.sm,
              AppSpacing.base,
              AppSpacing.md,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
