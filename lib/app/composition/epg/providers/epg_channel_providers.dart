import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/playlist_epg_channel_key.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/visible_live_channel_registry.dart';

/// True once the EPG catalogue inputs have delivered at least one value, so
/// visible rows show a neutral loading state instead of flashing "Kein EPG"
/// while the matching index is still warming up.
final epgMatchingInputsReadyProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(knownEpgChannelIdsProvider).hasValue &&
      ref.watch(epgChannelDisplayNamesProvider).hasValue;
});

/// Matches only the actually built Live rows (max 64) against the shared
/// matching index. This provider deliberately never watches
/// [liveChannelsStreamProvider] or the global catalogue match map: the Live
/// tab must not pay a whole-catalogue match for its first frame.
final visibleLiveEpgMatchesProvider =
    Provider.autoDispose<AsyncValue<Map<int, EpgChannelMatchResult>>>((ref) {
      ref.watch(epgCompletionRevisionProvider);
      final candidates = ref
          .watch(visibleLiveChannelCandidatesProvider)
          .valueOrNull;
      if (candidates == null) {
        return const AsyncValue.loading();
      }
      if (candidates.isEmpty) {
        return const AsyncValue.data(<int, EpgChannelMatchResult>{});
      }
      if (!ref.watch(epgMatchingInputsReadyProvider)) {
        return const AsyncValue.loading();
      }
      final index = ref.watch(epgMatchingIndexProvider);
      return AsyncValue.data({
        for (final candidate in candidates)
          candidate.channelId: index.matchProjection(
            playlistId: candidate.playlistId,
            name: candidate.name,
            tvgId: candidate.tvgId,
          ),
      });
    });

/// One bounded bulk query for the actually built Live rows. Sender tiles read
/// the resulting map synchronously; they never create one SQLite query each.
///
/// The query set comes exclusively from [visibleLiveEpgMatchesProvider]
/// (bounded to 64 rows by the registry). An empty set — or a set without any
/// EPG match — deliberately avoids opening a SQL subscription, and one
/// distinct visible set keeps exactly one bulk subscription. While the
/// registry, the match or this stream is still working, rows simply keep a
/// neutral loading state; an EPG error never moves the list into loading or
/// error.
final currentProgramsForVisibleChannelsProvider =
    StreamProvider.autoDispose<Map<int, EpgEntry?>>((ref) {
      ref.watch(epgCompletionRevisionProvider);
      final matches = ref.watch(visibleLiveEpgMatchesProvider).valueOrNull;
      if (matches == null) {
        // Matching is still warming up; stay in loading so rows render a
        // neutral EPG state instead of a wrong "Kein EPG".
        return const Stream<Map<int, EpgEntry?>>.empty();
      }
      if (matches.isEmpty) {
        return Stream.value(const <int, EpgEntry?>{});
      }

      final candidates =
          ref.watch(visibleLiveChannelCandidatesProvider).valueOrNull ??
          const <VisibleLiveChannelCandidate>[];
      final candidatesById = {
        for (final candidate in candidates) candidate.channelId: candidate,
      };
      final resolvedByChannel = <int, PlaylistEpgChannelKey>{
        for (final entry in matches.entries)
          if (entry.value.matchStatus == EpgMatchStatus.matched &&
              entry.value.resolvedEpgChannelId != null &&
              candidatesById.containsKey(entry.key))
            entry.key: PlaylistEpgChannelKey(
              playlistId: candidatesById[entry.key]!.playlistId,
              channelId: entry.value.resolvedEpgChannelId!,
            ),
      };

      if (resolvedByChannel.isEmpty) {
        return Stream.value({
          for (final channelId in matches.keys) channelId: null,
        });
      }

      var active = true;
      ref.onDispose(() => active = false);
      final now = DateTime.now();
      return ref
          .read(epgRepositoryProvider)
          .watchEntriesInRangeForPlaylistChannelIds(
            _groupEpgKeysByPlaylist(resolvedByChannel.values),
            now.subtract(const Duration(minutes: 1)),
            now.add(const Duration(minutes: 1)),
          )
          .map((entries) {
            if (!active) return const <int, EpgEntry?>{};
            final currentByEpgId = <PlaylistEpgChannelKey, EpgEntry>{};
            for (final entry in entries) {
              if (!entry.startTime.isAfter(now) && entry.endTime.isAfter(now)) {
                currentByEpgId.putIfAbsent(
                  PlaylistEpgChannelKey(
                    playlistId: entry.playlistId,
                    channelId: entry.channelId,
                  ),
                  () => entry,
                );
              }
            }
            return {
              for (final channelId in matches.keys)
                channelId: currentByEpgId[resolvedByChannel[channelId]],
            };
          });
    });

/// Descriptive alias used by catalog widgets and tests.
final currentProgramByChannelProvider =
    currentProgramsForVisibleChannelsProvider;

Map<int, Set<String>> _groupEpgKeysByPlaylist(
  Iterable<PlaylistEpgChannelKey> keys,
) {
  final grouped = <int, Set<String>>{};
  for (final key in keys) {
    grouped.putIfAbsent(key.playlistId, () => <String>{}).add(key.channelId);
  }
  return grouped;
}
