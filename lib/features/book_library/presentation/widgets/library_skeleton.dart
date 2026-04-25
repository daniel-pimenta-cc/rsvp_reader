import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/skeleton_loader.dart';

class LibrarySkeleton extends StatelessWidget {
  const LibrarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonHost(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.lg,
          AppSpacing.base,
          AppSpacing.sm,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.68,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
        ),
        itemCount: 9,
        itemBuilder: (_, i) => const SkeletonBookCard(),
      ),
    );
  }
}
