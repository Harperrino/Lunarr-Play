import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_channel_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

/// The playing channel does not depend on the EPG's browse filters/window or
/// whether its row is still mounted in the Live list.
final selectedChannelProgrammesProvider =
    StreamProvider.autoDispose<List<EpgEntry>>((ref) {
      final channel = ref.watch(selectedChannelProvider);
      if (channel == null || channel.channelType != 'live') {
        return Stream.value(const []);
      }
      ref.watch(epgCompletionRevisionProvider);
      if (!ref.watch(epgMatchingInputsReadyProvider)) {
        final ids = ref.watch(knownEpgChannelIdsProvider);
        final names = ref.watch(epgChannelDisplayNamesProvider);
        if (ids.hasError) {
          return Stream.error(ids.error!, ids.stackTrace);
        }
        if (names.hasError) {
          return Stream.error(names.error!, names.stackTrace);
        }
        return const Stream.empty();
      }
      final match = ref.watch(epgMatchingIndexProvider).matchChannel(channel);
      final id = match.resolvedEpgChannelId;
      if (id == null) return Stream.value(const []);
      final now = ref.watch(epgCurrentMinuteProvider);
      return ref
          .watch(epgRepositoryProvider)
          .watchEntriesInRangeForPlaylistChannelIds(
            {
              channel.playlistId: {id},
            },
            now.subtract(const Duration(minutes: 1)),
            now.add(const Duration(hours: 24)),
          );
    });

({EpgEntry? current, EpgEntry? next}) selectCurrentAndNextProgramme(
  Iterable<EpgEntry> entries,
  DateTime now,
) {
  EpgEntry? current;
  EpgEntry? next;
  for (final entry in entries) {
    if (!entry.startTime.isAfter(now) && entry.endTime.isAfter(now)) {
      if (current == null || entry.startTime.isAfter(current.startTime)) {
        current = entry;
      }
    } else if (entry.startTime.isAfter(now)) {
      if (next == null || entry.startTime.isBefore(next.startTime)) {
        next = entry;
      }
    }
  }
  return (current: current, next: next);
}
