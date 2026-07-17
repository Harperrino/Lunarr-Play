import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/core/services/epg_sync_service.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// Default EPG grid window: 2 h past → 10 h future (12 h total, centered on now).
const Duration epgGridWindowPast = Duration(hours: 2);
const Duration epgGridWindowFuture = Duration(hours: 10);
const Duration epgGridWindowDuration = Duration(hours: 12);
const Duration epgWarmCacheDuration = Duration(minutes: 5);

DateTime epgGridWindowStartAroundNow([DateTime? now]) {
  return (now ?? DateTime.now()).subtract(epgGridWindowPast);
}

DateTime epgGridWindowEndAroundNow([DateTime? now]) {
  return (now ?? DateTime.now()).add(epgGridWindowFuture);
}

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  return EpgRepository(ref.watch(databaseProvider));
});

final epgSyncServiceProvider = Provider<EpgSyncService>((ref) {
  return EpgSyncService(
    ref.watch(epgRepositoryProvider),
    ref.watch(playlistRepositoryProvider),
  );
});

/// Bounded warm-cache window so Live/EPG tab returns stay hot without keeping
/// the matching path alive indefinitely.
final epgWarmCacheDurationProvider = Provider<Duration>((ref) {
  return epgWarmCacheDuration;
});

/// Optional time window for EPG grid queries (M5C).
final epgWindowStartProvider = StateProvider<DateTime>((ref) {
  return epgGridWindowStartAroundNow();
});

final epgWindowEndProvider = StateProvider<DateTime>((ref) {
  final start = ref.watch(epgWindowStartProvider);
  return start.add(epgGridWindowDuration);
});

/// All known XMLTV channel IDs (programmes + channel catalogue).
final knownEpgChannelIdsProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) {
  ref.watch(epgSyncServiceProvider);
  return ref.watch(epgRepositoryProvider).watchKnownEpgChannelIds();
});

/// XMLTV display names keyed by channel id — used for playlist ↔ EPG matching.
final epgChannelDisplayNamesProvider =
    StreamProvider.autoDispose<Map<String, List<String>>>((ref) {
      ref.watch(epgSyncServiceProvider);
      return ref.watch(epgRepositoryProvider).watchEpgChannelDisplayNames();
    });

/// Reactive stream of EPG entries within the configured window (unscoped — M5A/Settings).
final epgEntriesStreamProvider = StreamProvider.autoDispose<List<EpgEntry>>((
  ref,
) {
  final start = ref.watch(epgWindowStartProvider);
  final end = ref.watch(epgWindowEndProvider);
  return ref.watch(epgRepositoryProvider).watchEntriesInRange(start, end);
});

/// Pre-built matching index — rebuilt when EPG catalogue changes.
final epgMatchingIndexProvider = Provider.autoDispose<EpgMatchingIndex>((ref) {
  final link = ref.keepAlive();
  final warmDuration = ref.watch(epgWarmCacheDurationProvider);
  Timer? disposeTimer;
  ref.onCancel(() {
    disposeTimer = Timer(warmDuration, link.close);
  });
  ref.onResume(() {
    disposeTimer?.cancel();
    disposeTimer = null;
  });
  ref.onDispose(() {
    disposeTimer?.cancel();
  });

  ref.watch(epgSyncServiceProvider);

  final knownIds =
      ref.watch(knownEpgChannelIdsProvider).valueOrNull ?? const {};
  final displayNames =
      ref.watch(epgChannelDisplayNamesProvider).valueOrNull ?? const {};

  return EpgMatchingIndex(
    knownEpgChannelIds: knownIds,
    displayNamesByChannelId: displayNames,
  );
});

/// One match result per playlist channel — shared by Live list and EPG grid.
final epgChannelMatchesProvider =
    Provider.autoDispose<Map<int, EpgChannelMatchResult>>((ref) {
      final link = ref.keepAlive();
      final warmDuration = ref.watch(epgWarmCacheDurationProvider);
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer = Timer(warmDuration, link.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      ref.onDispose(() {
        disposeTimer?.cancel();
      });

      final index = ref.watch(epgMatchingIndexProvider);
      final channels =
          ref.watch(liveChannelsStreamProvider).valueOrNull ??
          const <Channel>[];

      return {
        for (final channel in channels) channel.id: index.matchChannel(channel),
      };
    });
