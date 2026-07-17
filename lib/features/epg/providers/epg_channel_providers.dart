import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';

/// Match status for a playlist channel (scoped via [channelsStreamProvider]).
final epgMatchStatusProvider = Provider.autoDispose.family<EpgMatchStatus, int>(
  (ref, channelDbId) {
    ref.watch(epgSyncNotifierProvider);
    final match = ref.watch(epgChannelMatchesProvider)[channelDbId];
    return match?.matchStatus ?? EpgMatchStatus.noMatch;
  },
);

/// Currently airing EPG programme for a playlist channel, or null.
final currentProgramForChannelProvider = FutureProvider.autoDispose
    .family<EpgEntry?, int>((ref, channelDbId) async {
      ref.watch(epgSyncNotifierProvider);

      final match = ref.watch(epgChannelMatchesProvider)[channelDbId];
      if (match == null || match.matchStatus != EpgMatchStatus.matched) {
        return null;
      }

      final resolvedId = match.resolvedEpgChannelId;
      if (resolvedId == null) return null;

      return ref
          .read(epgRepositoryProvider)
          .getCurrentProgram(resolvedId, DateTime.now());
    });
