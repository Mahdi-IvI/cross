import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/document/domain/entities/upload_source.dart';
import '../../features/document/presentation/pages/document_page.dart';
import '../../features/document/presentation/pages/properties/doc_properties_page.dart';
import '../../features/document/presentation/pages/upload/upload_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/documentScanner/document_scanner_page.dart';
import '../../features/documentScanner/edit_photo_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/library',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      if (auth.isLoading) return path == '/startup' ? null : '/startup';
      final authenticated = auth.asData?.value != null;
      final authRoute = path == '/login' || path == '/register';
      if (!authenticated) return authRoute ? null : '/login';
      if (authRoute || path == '/startup') return '/library';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/library'),
          child: const Text('Go to your library'),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/startup',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const AuthPage()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const AuthPage(register: true),
      ),
      GoRoute(
        path: '/library',
        builder: (_, state) => DocumentPage(
          folderId: int.tryParse(state.uri.queryParameters['folder'] ?? ''),
          view: state.uri.queryParameters['view'] == 'favorites'
              ? 'favorites'
              : 'all',
        ),
      ),
      GoRoute(
        path: '/documents/:id',
        builder: (_, state) => DocPropertiesPage(
          id: int.tryParse(state.pathParameters['id']!) ?? -1,
        ),
      ),
      GoRoute(
        path: '/upload',
        redirect: (_, state) => state.extra is UploadSource ? null : '/library',
        builder: (_, state) => UploadPage(
          parentId: int.tryParse(state.uri.queryParameters['folder'] ?? ''),
          source: state.extra! as UploadSource,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/scan',
        builder: (_, state) => DocumentScannerPage(
          parentId: int.tryParse(state.uri.queryParameters['folder'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/scan/pages/:pageId',
        builder: (_, state) => EditPhotoPage(
          parentId: int.tryParse(state.uri.queryParameters['folder'] ?? ''),
          pageId: state.pathParameters['pageId']!,
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
