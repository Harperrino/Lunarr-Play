import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';

Channel _channel(int id, bool favorite) {
  return Channel(
    id: id,
    playlistId: 1,
    name: 'Channel $id',
    streamUrl: 'https://example.invalid/$id',
    providerOrder: id,
    isFavorite: favorite,
    isWatchLater: false,
    channelType: 'live',
  );
}

void main() {
  test(
    'keeps favorite mutations independent and reconciles through Drift',
    () async {
      final stream = StreamController<List<Channel>>();
      final firstCall = Completer<bool>();
      final secondCall = Completer<bool>();
      final controller = ChannelFavoriteController(
        (channelId) => channelId == 1 ? firstCall.future : secondCall.future,
        channelStream: stream.stream,
      );
      addTearDown(() async {
        controller.dispose();
        await stream.close();
      });

      final firstToggle = controller.toggle(1, currentFavorite: false);
      final secondToggle = controller.toggle(2, currentFavorite: true);
      expect(controller.state.isBusy(1), isTrue);
      expect(controller.state.isBusy(2), isTrue);
      expect(controller.state.isFavorite(_channel(1, false)), isTrue);
      expect(controller.state.isFavorite(_channel(2, true)), isFalse);

      firstCall.complete(true);
      secondCall.complete(true);
      await Future.wait([firstToggle, secondToggle]);
      expect(controller.state.isBusy(1), isTrue);
      expect(controller.state.isBusy(2), isTrue);

      stream.add([_channel(1, true), _channel(2, false)]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.optimisticFavorites, isEmpty);
    },
  );

  test(
    'rolls back only the failed channel and keeps the error for the snackbar',
    () async {
      final stream = StreamController<List<Channel>>();
      final controller = ChannelFavoriteController(
        (_) async => throw StateError('write failed'),
        channelStream: stream.stream,
      );
      addTearDown(() async {
        controller.dispose();
        await stream.close();
      });

      final toggle = controller.toggle(1, currentFavorite: false);
      await toggle;

      expect(controller.state.isBusy(1), isFalse);
      expect(controller.state.isFavorite(_channel(1, false)), isFalse);
      expect(controller.state.hasError, isTrue);
      expect(controller.state.error, isA<StateError>());
    },
  );

  test(
    'ignores a second toggle for the same channel while it is busy',
    () async {
      var calls = 0;
      final completer = Completer<bool>();
      final controller = ChannelFavoriteController((_) {
        calls++;
        return completer.future;
      });
      addTearDown(controller.dispose);

      final first = controller.toggle(1, currentFavorite: false);
      final second = controller.toggle(1, currentFavorite: false);
      completer.complete(true);
      await Future.wait([first, second]);

      expect(calls, 1);
      expect(controller.state.isBusy(1), isFalse);
    },
  );
}
