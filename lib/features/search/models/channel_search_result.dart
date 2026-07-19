import 'package:m3uxtream_player/core/database/app_database.dart';

class ChannelSearchResult {
  const ChannelSearchResult({
    required this.channel,
    required this.playlistId,
    required this.playlistName,
    required this.categoryName,
    this.resolvedEpgChannelId,
  });

  final Channel channel;
  final int playlistId;
  final String playlistName;
  final String categoryName;
  final String? resolvedEpgChannelId;

  int get channelId => channel.id;
  String get visibleLabel => channel.name;
  String get metadataLabel => '$categoryName · $playlistName';
}
