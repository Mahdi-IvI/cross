import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/document/presentation/providers/upload_providers.dart';

class DmsApp extends ConsumerStatefulWidget {
  const DmsApp({super.key});

  @override
  ConsumerState<DmsApp> createState() => _DmsAppState();
}

class _DmsAppState extends ConsumerState<DmsApp> {
  final messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(recoveredUploadProvider, (_, next) {
      if (next.isLoading || ref.read(activeSessionProvider) == null) return;
      if (next.hasError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || ref.read(activeSessionProvider) == null) return;
          messenger.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                'The previous photo or video could not be recovered. Please capture it again.',
              ),
            ),
          );
        });
        return;
      }
      final recovered = next.asData?.value;
      if (recovered != null) {
        ref.read(routerProvider).push('/upload', extra: recovered);
      }
    });
    return MaterialApp.router(
      title: 'DMS · Documents',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messenger,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
