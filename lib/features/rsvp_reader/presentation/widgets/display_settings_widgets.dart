part of 'display_settings_panel.dart';

/// Available reading fonts. The [value] is what we persist; [googleFont] is
/// the name used by the google_fonts package; [label] is shown in the picker.
const _fontOptions = <({String value, String googleFont, String label})>[
  (value: 'RobotoMono', googleFont: 'Roboto Mono', label: 'Roboto Mono'),
  (value: 'JetBrainsMono', googleFont: 'JetBrains Mono', label: 'JetBrains Mono'),
  (value: 'FiraCode', googleFont: 'Fira Code', label: 'Fira Code'),
  (value: 'SourceCodePro', googleFont: 'Source Code Pro', label: 'Source Code Pro'),
];

const _fontPreviewSample = 'The quick brown fox jumps 0123';

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color.withAlpha(140),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.labelColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: labelColor, fontSize: 14)),
        ),
        child,
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Color labelColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.labelColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: labelColor, fontSize: 14)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                      color: labelColor.withAlpha(140), fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PlusMinusControl extends StatelessWidget {
  final int value;
  final Color color;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _PlusMinusControl({
    required this.value,
    required this.color,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
            icon: Icons.text_decrease, color: color, onTap: onDecrease),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        _CircleButton(
            icon: Icons.text_increase, color: color, onTap: onIncrease),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color color;
  final ValueChanged<Color> onChanged;

  const _ColorRow({
    required this.label,
    required this.labelColor,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: labelColor, fontSize: 14)),
        ),
        GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(40), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 300,
          child: ColorPicker(
            color: color,
            onColorChanged: onChanged,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.wheel: true,
            },
            enableShadesSelection: true,
            enableOpacity: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Font picker that renders each option in its own typeface and shows
/// a sample line below using the currently selected font.
class _FontSelector extends StatelessWidget {
  final String label;
  final String currentValue;
  final Color labelColor;
  final Color backgroundColor;
  final ValueChanged<String> onChanged;

  const _FontSelector({
    required this.label,
    required this.currentValue,
    required this.labelColor,
    required this.backgroundColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = _fontOptions.firstWhere(
      (o) => o.value == currentValue,
      orElse: () => _fontOptions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
            DropdownButton<String>(
              value: currentValue,
              dropdownColor:
                  Color.lerp(backgroundColor, Colors.white, 0.12),
              underline: const SizedBox.shrink(),
              selectedItemBuilder: (context) => _fontOptions
                  .map((opt) => Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          opt.label,
                          style: GoogleFonts.getFont(
                            opt.googleFont,
                            color: labelColor,
                            fontSize: 14,
                          ),
                        ),
                      ))
                  .toList(),
              items: _fontOptions
                  .map((opt) => DropdownMenuItem(
                        value: opt.value,
                        child: Text(
                          opt.label,
                          style: GoogleFonts.getFont(
                            opt.googleFont,
                            color: labelColor,
                            fontSize: 15,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Color.lerp(backgroundColor, Colors.white, 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: labelColor.withAlpha(30)),
          ),
          child: Text(
            _fontPreviewSample,
            style: GoogleFonts.getFont(
              current.googleFont,
              color: labelColor,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
