import 'package:m3uxtream_player/core/models/search_catalog_entry.dart';

class ChannelSearchResult {
  const ChannelSearchResult({
    required this.entry,
    required this.playlistId,
    required this.playlistName,
    required this.categoryName,
    this.resolvedEpgChannelId,
  });

  final SearchCatalogEntry entry;
  final int playlistId;
  final String playlistName;
  final String categoryName;
  final String? resolvedEpgChannelId;

  int get channelId => entry.channelId;
  String get visibleLabel => entry.name;
  String get metadataLabel => '$categoryName · $playlistName';
}
