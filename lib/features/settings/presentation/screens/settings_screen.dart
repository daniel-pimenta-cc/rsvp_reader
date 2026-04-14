import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../rsvp_reader/presentation/providers/display_settings_provider.dart';
import '../../../rsvp_reader/presentation/widgets/display_settings_panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(displaySettingsProvider);

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      appBar: AppBar(
        backgroundColor: settings.backgroundColor,
        foregroundColor: settings.wordColor,
        elevation: 0,
        title: Text(l10n.settings,
            style: TextStyle(color: settings.wordColor)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DisplaySettingsPanel(),
            const SizedBox(height: 24),
            Divider(color: settings.wordColor.withAlpha(40), height: 1),
            const SizedBox(height: 16),
            Text(
              l10n.settingsAbout.toUpperCase(),
              style: TextStyle(
                color: settings.wordColor.withAlpha(140),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('RSVP Reader',
                  style: TextStyle(color: settings.wordColor)),
              subtitle: Text('v0.1.0',
                  style:
                      TextStyle(color: settings.wordColor.withAlpha(160))),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
