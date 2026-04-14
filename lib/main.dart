import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final dbDir = await getApplicationDocumentsDirectory();
  final dbFile = File('${dbDir.path}/rsvp_reader.db');
  final database = AppDatabase(
    NativeDatabase.createInBackground(dbFile),
  );

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const RsvpReaderApp(),
    ),
  );
}
