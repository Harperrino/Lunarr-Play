import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

/// media_kit test double whose streams are inert unless a test overrides them.
class FakePlayerStream extends Fake implements PlayerStream {
  final Map<Symbol, Stream<Never>> _streams = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      return _streams.putIfAbsent(
        invocation.memberName,
        () => const Stream<Never>.empty(),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeMediaPlayer extends Fake implements Player {
  final PlayerStream _stream = FakePlayerStream();

  @override
  PlayerStream get stream => _stream;
}

class FixedPlayerNotifier extends PlayerNotifier {
  FixedPlayerNotifier(this.initialState);

  final PlayerState initialState;

  @override
  Future<PlayerState> build() async => initialState;

  @override
  VideoController videoControllerFor(Player player) => VideoController(player);
}
