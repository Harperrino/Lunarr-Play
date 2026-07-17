@Tags(['native'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/streaming_diagnostics_providers.dart';
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

class _TestStreamingDiagnosticsSettingsNotifier
    extends StreamingDiagnosticsSettingsNotifier {
  @override
  Future<StreamingDiagnosticsSettings> build() async {
    return const StreamingDiagnosticsSettings(
      autoFallbackEnabled: false,
      showOnErrorEnabled: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureMediaKitForTests();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        playerBufferSecondsProvider.overrideWith(
          _TestBufferSecondsNotifier.new,
        ),
        forceStereoEnabledProvider.overrideWith(_TestForceStereoNotifier.new),
        preferredAudioLanguageProvider.overrideWith(
          _TestPreferredAudioLanguageNotifier.new,
        ),
        streamingDiagnosticsSettingsProvider.overrideWith(
          _TestStreamingDiagnosticsSettingsNotifier.new,
        ),
      ],
    );
  }

  test(
    'PlayerNotifier starts as AsyncLoading and then becomes AsyncData',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final initial = container.read(playerNotifierProvider);
      expect(initial.isLoading, isTrue);

      final state = await container.read(playerNotifierProvider.future);
      expect(state.player, isNotNull);
      expect(container.read(playerNotifierProvider).hasValue, isTrue);
    },
  );

  test(
    'openStream waits for player initialization instead of returning early',
    () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'player_startup_init_test',
      );
      final missingFile = File(
        '${tempDir.path}${Platform.pathSeparator}missing.mp4',
      );
      final fileUrl = Uri.file(missingFile.path).toString();

      final container = ProviderContainer(
        overrides: [
          playerBufferSecondsProvider.overrideWith(
            _TestBufferSecondsNotifier.new,
          ),
          forceStereoEnabledProvider.overrideWith(_TestForceStereoNotifier.new),
          preferredAudioLanguageProvider.overrideWith(
            _TestPreferredAudioLanguageNotifier.new,
          ),
          streamingDiagnosticsSettingsProvider.overrideWith(
            _TestStreamingDiagnosticsSettingsNotifier.new,
          ),
          selectedChannelProvider.overrideWith(
            (ref) => const Channel(
              id: 1,
              playlistId: 1,
              name: 'VOD Dummy',
              streamUrl: 'https://example.com/dummy.mp4',
              isFavorite: false,
              isWatchLater: false,
              channelType: 'vod',
            ),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      // Trigger initialization but do not await it.
      container.read(playerNotifierProvider);
      expect(container.read(playerNotifierProvider).isLoading, isTrue);

      // This should wait for initialization and then attempt to open the stream.
      await container.read(playerNotifierProvider.notifier).openStream(fileUrl);

      // After awaiting openStream the provider must have left the loading state.
      final asyncValue = container.read(playerNotifierProvider);
      expect(asyncValue.isLoading, isFalse);
      expect(asyncValue.hasValue, isTrue);
    },
  );
}
