import 'package:flutter/material.dart';

import '../errors/app_failure.dart';

void showError(BuildContext context, Object error) {
  final message = error is AppFailure
      ? error.message
      : error is FormatException
      ? error.message
      : 'Could not complete this action. Please try again.';
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message), showCloseIcon: true));
}

String formatSize(int? size) {
  if (size == null) return 'Unknown size';
  if (size < 1024) return '$size bytes';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KiB';
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MiB';
}
