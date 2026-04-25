import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'core/utils/platform_capabilities.dart';
import 'database/app_database.dart';
import 'features/library_sync/presentation/providers/drive_auth_provider.dart';
import 'features/library_sync/presentation/providers/library_sync_provider.dart';
import 'features/library_sync/presentation/providers/sync_config_provider.dart';
import 'features/rsvp_reader/presentation/providers/display_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (PlatformCapabilities.isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  final dbDir = await getApplicationDocumentsDirectory();
  final dbFile = File('${dbDir.path}/rsvp_reader.db');
  final database = AppDatabase(
    NativeDatabase.createInBackground(dbFile),
  );

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
    ],
  );

  // Fire an initial sync on startup if the user has configured a folder.
  // We need to wait for SyncConfigNotifier.load() to finish first.
  if (PlatformCapabilities.supportsDriveSync) {
    unawaited(_initialSync(container));
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RsvpReaderApp(),
    ),
  );
}

Future<void> _initialSync(ProviderContainer container) async {
  final configNotifier = container.read(syncConfigProvider.notifier);
  while (!configNotifier.isLoaded) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (!container.read(syncConfigProvider).isActive) return;

  // Restore the previous Google session silently; without a signed-in
  // user the sync provider is a no-op and we'd just burn the startup.
  final signedIn =
      await container.read(driveAuthProvider.notifier).trySilentSignIn();
  if (!signedIn) return;

  // Wait for local display settings to load before we snapshot them for the
  // push — otherwise the service would read the defaulted initial state
  // (const DisplaySettings()) and overwrite the remote's real values.
  await container.read(displaySettingsProvider.notifier).load();

  await container.read(librarySyncProvider.notifier).triggerSync();
}
