import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/widgets/player_panel.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/status_snack_bar.dart';

void main() {
  testWidgets(
    'player status tones use semantic theme roles without providers',
    (tester) async {
      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme,
          child: Builder(
            builder: (context) {
              final colors = Theme.of(context).colorScheme;
              final status = Theme.of(context).extension<AppStatusColors>()!;

              expect(
                playerStatusColorFor(context, PlayerStatusTone.error),
                colors.error,
              );
              expect(
                playerStatusColorFor(context, PlayerStatusTone.idle),
                colors.onSurfaceVariant,
              );
              expect(
                playerStatusColorFor(context, PlayerStatusTone.warning),
                status.warning,
              );
              expect(
                playerStatusColorFor(context, PlayerStatusTone.info),
                status.info,
              );
              expect(
                playerStatusColorFor(context, PlayerStatusTone.playing),
                status.success,
              );
              expect(
                playerStatusColorFor(context, PlayerStatusTone.paused),
                colors.tertiary,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );

  testWidgets(
    'global search hint uses the on-surface-variant role without providers',
    (tester) async {
      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme,
          child: Builder(
            builder: (context) {
              expect(
                globalSearchHintColor(context),
                Theme.of(context).colorScheme.onSurfaceVariant,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );

  testWidgets('global search input follows neutral surface roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.highContrastDarkTheme,
          home: const Scaffold(
            body: SizedBox(width: 360, child: GlobalSearchField()),
          ),
        ),
      ),
    );
    await tester.pump();

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.style.color, colors.onSurface);
    expect(find.byType(SearchBar), findsOneWidget);
  });

  testWidgets('status snackbars use semantic theme roles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.highContrastDarkTheme,
        home: Builder(
          builder: (context) {
            final colors = Theme.of(context).colorScheme;
            final status = Theme.of(context).extension<AppStatusColors>()!;
            final error = appStatusSnackBar(
              context,
              message: 'error',
              tone: AppStatusSnackBarTone.error,
            );
            final success = appStatusSnackBar(
              context,
              message: 'success',
              tone: AppStatusSnackBarTone.success,
            );
            final warning = appStatusSnackBar(
              context,
              message: 'warning',
              tone: AppStatusSnackBarTone.warning,
            );

            expect(error.backgroundColor, colors.errorContainer);
            expect(
              (error.content as Text).style?.color,
              colors.onErrorContainer,
            );
            expect(success.backgroundColor, status.successContainer);
            expect(
              (success.content as Text).style?.color,
              status.onSuccessContainer,
            );
            expect(warning.backgroundColor, status.warningContainer);
            expect(
              (warning.content as Text).style?.color,
              status.onWarningContainer,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
