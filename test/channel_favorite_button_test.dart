import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_favorite_button.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  testWidgets('channel list favorite action is accessible at 200 percent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var toggles = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Row(
              children: [
                const Expanded(child: Text('Live Channel')),
                ChannelFavoriteButton(
                  channelId: 9,
                  isFavorite: false,
                  isBusy: false,
                  onToggle: () => toggles += 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Zu Favoriten hinzufügen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('channel-favorite-toggle-9')));
    expect(toggles, 1);
    semantics.dispose();
  });
}
