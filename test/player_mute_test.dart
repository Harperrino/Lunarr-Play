@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';

import 'helpers/media_kit_test_init.dart';

class _TestBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => PlayerBufferSecondsNotifier.defaultSeconds;
}

class _TestForceStereoNotifier extends ForceStereoEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

class _TestPreferredAudioLanguageNotifier
    extends PreferredAudioLanguageNotifier {
  @override
  Future<String?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureMediaKitForTests();
  });

  group('PlayerNotifier.toggleMute', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          playerBufferSecondsProvider.overrideWith(
            _TestBufferSecondsNotifier.new,
          ),
          forceStereoEnabledProvider.overrideWith(_TestForceStereoNotifier.new),
          preferredAudioLanguageProvider.overrideWith(
            _TestPreferredAudioLanguageNotifier.new,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> waitForVolume(double expected) async {
      for (var i = 0; i < 50; i++) {
        final volume = container
            .read(playerNotifierProvider)
            .valueOrNull
            ?.volume;
        if (volume != null && (volume - expected).abs() < 0.01) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('Timed out waiting for volume $expected');
    }

    test('restores exact volume after mute/unmute cycle', () async {
      await container.read(playerNotifierProvider.future);

      await container
          .read(playerNotifierProvider.notifier)
          .setVolumeNormalized(0.5);
      await waitForVolume(0.5);

      await container.read(playerNotifierProvider.notifier).toggleMute();
      await waitForVolume(0.0);

      await container.read(playerNotifierProvider.notifier).toggleMute();
      await waitForVolume(0.5);

      final volume = container.read(playerNotifierProvider).valueOrNull!.volume;
      expect(volume, closeTo(0.5, 0.01));
    });
  });
}
