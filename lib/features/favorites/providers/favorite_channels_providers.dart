import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';

/// Read-only M9a derivation. Only live channels have an existing, safe
/// activation path from this screen; VOD and series remain out of scope.
List<Channel> filterFavoriteLiveChannels(List<Channel> channels) {
  return channels
      .where((channel) => channel.channelType == 'live' && channel.isFavorite)
      .toList(growable: false);
}

/// Existing selected-playlist stream, narrowed without persistence or effects.
final favoriteLiveChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channels = ref.watch(channelsStreamProvider).valueOrNull ?? const [];
  return filterFavoriteLiveChannels(channels);
});
