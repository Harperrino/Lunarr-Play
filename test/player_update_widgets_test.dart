import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:m3uxtream_player/core/services/release_update_service.dart';
import 'package:m3uxtream_player/features/updates/providers/update_providers.dart';
import 'package:m3uxtream_player/features/updates/widgets/player_version_label.dart';
import 'package:m3uxtream_player/features/updates/widgets/update_available_button.dart';
import 'package:m3uxtream_player/shared/widgets/custom_app_bar.dart';

import 'support/localized_test_app.dart';

void main() {
  testWidgets('settings label reads the actual package version', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerPackageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'Lunarr',
              packageName: 'lunarr',
              version: '1.0.3-rc.5',
              buildNumber: '11',
            ),
          ),
        ],
        child: const LocalizedTestApp(child: PlayerVersionLabel()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Player version: 1.0.3-rc.5'), findsOneWidget);
  });
  for (final width in [600.0, 1200.0]) {
    testWidgets(
      'update indicator beside logo does not overlap search at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final compact = width < 900;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              startupUpdateProvider.overrideWith(
                (_) async => AvailableRelease(
                  '1.0.3',
                  Uri.https(
                    'github.com',
                    '/Harperrino/Lunarr-Play/releases/tag/v1.0.3',
                  ),
                ),
              ),
            ],
            child: LocalizedTestApp(
              child: Scaffold(
                appBar: CustomAppBar(
                  onCloseRequested: () {},
                  brandAccessory: UpdateAvailableButton(compact: compact),
                  brandAccessoryWidth: compact ? 48 : 160,
                  search: const TextField(key: ValueKey('search')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('player-update-available')),
          findsOneWidget,
        );
        final update = tester.getRect(
          find.byKey(const ValueKey('player-update-available')),
        );
        final logo = tester.getRect(
          find.byKey(const ValueKey('window-bar-brand-mark')),
        );
        final search = tester.getRect(find.byKey(const ValueKey('search')));
        expect(update.left, greaterThanOrEqualTo(logo.right));
        expect(update.right, lessThanOrEqualTo(search.left));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('no update leaves the header indicator hidden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [startupUpdateProvider.overrideWith((_) async => null)],
        child: const LocalizedTestApp(child: UpdateAvailableButton()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-update-available')), findsNothing);
  });
}
