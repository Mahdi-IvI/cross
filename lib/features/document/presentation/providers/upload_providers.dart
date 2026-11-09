import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../data/datasources/upload_source_picker.dart';
import '../../domain/entities/upload_source.dart';

final uploadSourcePickerProvider = Provider<UploadSourcePicker>(
  (ref) => UploadSourcePicker(),
);

// Android may restart the app while the native camera is open. Recover once on
// sign-in/startup and let the user finish the upload form; never upload silently.
final recoveredUploadProvider = FutureProvider<UploadSource?>((ref) async {
  final account = ref.watch(
    activeSessionProvider.select((session) => session?.accountKey),
  );
  if (account == null) {
    return null;
  }
  final source = await ref.watch(uploadSourcePickerProvider).recover();
  if (!ref.mounted) {
    await source?.dispose();
    return null;
  }
  return source;
}, retry: (_, _) => null);
