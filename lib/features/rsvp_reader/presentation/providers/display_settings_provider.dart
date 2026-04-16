import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../library_sync/presentation/providers/library_sync_provider.dart';
import '../../domain/entities/display_settings.dart';

const _prefix = 'display_';

class DisplaySettingsNotifier extends StateNotifier<DisplaySettings> {
  final SharedPreferencesAsync _prefs;
  final Ref? _ref;

  DisplaySettingsNotifier(this._prefs, [this._ref])
      : super(const DisplaySettings()) {
    load();
  }

  Future<void> load() async {
    state = DisplaySettings(
      wpm: await _prefs.getInt('${_prefix}wpm') ?? AppConstants.defaultWpm,
      fontSize: await _prefs.getDouble('${_prefix}fontSize') ??
          AppConstants.defaultFontSize,
      contextFontSize: await _prefs.getDouble('${_prefix}ctxFontSize') ??
          AppConstants.defaultContextFontSize,
      wordColorValue: await _prefs.getInt('${_prefix}wordColor') ??
          AppConstants.defaultWordColor,
      orpColorValue: await _prefs.getInt('${_prefix}orpColor') ??
          AppConstants.defaultOrpColor,
      backgroundColorValue: await _prefs.getInt('${_prefix}bgColor') ??
          AppConstants.defaultBackgroundColor,
      highlightColorValue: await _prefs.getInt('${_prefix}hlColor') ??
          AppConstants.defaultHighlightColor,
      verticalPosition: await _prefs.getDouble('${_prefix}vPos') ??
          AppConstants.defaultVerticalPosition,
      horizontalPosition: await _prefs.getDouble('${_prefix}hPos') ?? 0.5,
      fontFamily: await _prefs.getString('${_prefix}font') ??
          AppConstants.defaultFontFamily,
      showOrpHighlight:
          await _prefs.getBool('${_prefix}showOrp') ?? true,
      smartTiming:
          await _prefs.getBool('${_prefix}smartTiming') ?? true,
      rampUp:
          await _prefs.getBool('${_prefix}rampUp') ?? true,
      showFocusLine:
          await _prefs.getBool('${_prefix}showFocusLine') ?? true,
      focusLineShowsProgress:
          await _prefs.getBool('${_prefix}focusLineProgress') ?? true,
    );
  }

  Future<void> update(DisplaySettings Function(DisplaySettings) updater) async {
    state = updater(state);
    await _save();
    _notifySyncChanged();
  }

  /// Apply settings coming from a sync pull. Persists to SharedPreferences
  /// without re-triggering a sync push (the remote already has these values).
  Future<void> applyFromRemote(DisplaySettings synced) async {
    state = synced;
    await _save();
  }

  /// Flip the reader's word + background colours to match [brightness]. Called
  /// from [ThemeModeNotifier] when the resolved theme brightness changes so
  /// the reader palette stays consistent with the app chrome. Other colours
  /// (ORP accent, highlight) stay put — those are intentional choices that
  /// aren't tied to light/dark.
  Future<void> applyBrightness(Brightness brightness) async {
    final palette =
        brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    state = state.copyWith(
      wordColorValue: palette.onSurface.toARGB32(),
      backgroundColorValue: palette.background.toARGB32(),
    );
    await _save();
    _notifySyncChanged();
  }

  void _notifySyncChanged() {
    final ref = _ref;
    if (ref == null) return;
    final notifier = ref.read(librarySyncProvider.notifier);
    notifier.markSettingsDirty();
    notifier.schedulePush();
  }

  Future<void> _save() async {
    await Future.wait([
      _prefs.setInt('${_prefix}wpm', state.wpm),
      _prefs.setDouble('${_prefix}fontSize', state.fontSize),
      _prefs.setDouble('${_prefix}ctxFontSize', state.contextFontSize),
      _prefs.setInt('${_prefix}wordColor', state.wordColorValue),
      _prefs.setInt('${_prefix}orpColor', state.orpColorValue),
      _prefs.setInt('${_prefix}bgColor', state.backgroundColorValue),
      _prefs.setInt('${_prefix}hlColor', state.highlightColorValue),
      _prefs.setDouble('${_prefix}vPos', state.verticalPosition),
      _prefs.setDouble('${_prefix}hPos', state.horizontalPosition),
      _prefs.setString('${_prefix}font', state.fontFamily),
      _prefs.setBool('${_prefix}showOrp', state.showOrpHighlight),
      _prefs.setBool('${_prefix}smartTiming', state.smartTiming),
      _prefs.setBool('${_prefix}rampUp', state.rampUp),
      _prefs.setBool('${_prefix}showFocusLine', state.showFocusLine),
      _prefs.setBool(
          '${_prefix}focusLineProgress', state.focusLineShowsProgress),
    ]);
  }
}

final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>((ref) {
  return DisplaySettingsNotifier(SharedPreferencesAsync(), ref);
});
