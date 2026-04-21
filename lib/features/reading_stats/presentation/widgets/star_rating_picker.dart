import 'package:flutter/material.dart';

/// 5-star rating picker. Tap a star to set the rating; tap the same
/// star again to clear it (null rating). Read-only variant shown on the
/// share card is [StarRatingRow] below.
class StarRatingPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final double size;
  const StarRatingPicker({
    required this.value,
    required this.onChanged,
    this.size = 36,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(value == i ? null : i),
            iconSize: size,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            icon: Icon(
              (value ?? 0) >= i ? Icons.star_rounded : Icons.star_border_rounded,
              color: (value ?? 0) >= i ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Read-only star row used on the exported completion card.
class StarRatingRow extends StatelessWidget {
  final int value;
  final double size;
  final Color filledColor;
  final Color emptyColor;
  const StarRatingRow({
    required this.value,
    required this.filledColor,
    required this.emptyColor,
    this.size = 20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) const SizedBox(width: 2),
          Icon(
            value >= i ? Icons.star_rounded : Icons.star_border_rounded,
            color: value >= i ? filledColor : emptyColor,
            size: size,
          ),
        ],
      ],
    );
  }
}
