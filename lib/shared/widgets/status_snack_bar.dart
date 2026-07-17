import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';

enum AppStatusSnackBarTone { error, success, warning }

SnackBar appStatusSnackBar(
  BuildContext context, {
  required String message,
  required AppStatusSnackBarTone tone,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final status = theme.extension<AppStatusColors>() ?? AppStatusColors.dark;
  final (background, foreground) = switch (tone) {
    AppStatusSnackBarTone.error => (
      colors.errorContainer,
      colors.onErrorContainer,
    ),
    AppStatusSnackBarTone.success => (
      status.successContainer,
      status.onSuccessContainer,
    ),
    AppStatusSnackBarTone.warning => (
      status.warningContainer,
      status.onWarningContainer,
    ),
  };

  return SnackBar(
    content: Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
    ),
    backgroundColor: background,
    behavior: SnackBarBehavior.floating,
  );
}
