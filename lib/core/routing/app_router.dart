import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/book_library/presentation/screens/library_screen.dart';
import '../../features/rsvp_reader/presentation/screens/rsvp_reader_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/reader/:bookId',
      pageBuilder: (context, state) {
        final bookId = state.pathParameters['bookId']!;
        return MaterialPage(
          fullscreenDialog: true,
          child: RsvpReaderScreen(bookId: bookId),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
