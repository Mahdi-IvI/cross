import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await getApplicationSupportDirectory();
    final database = await AppDatabase.open(directory.path);
    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          supportDirectoryProvider.overrideWithValue(directory.path),
        ],
        child: const DmsApp(),
      ),
    );
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'DMS startup',
      ),
    );
    runApp(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text('Your local library could not be opened.'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
