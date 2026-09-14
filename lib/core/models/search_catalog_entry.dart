/// The small row shape used by the global search catalogue.
///
/// Search never needs playback URLs, resume state or favorite flags while it
/// is building the dropdown. The complete [Channel] is loaded only after a
/// user selects a channel result.
class SearchCatalogEntry {
  const SearchCatalogEntry({
    required this.channelId,
    required this.playlistId,
    required this.type,
    required this.name,
    this.logo,
    this.category,
    this.epgChannelId,
    this.channelNumber,
    this.streamId,
  });

  final int channelId;
  final int playlistId;
  final String type;
  final String name;
  final String? logo;
  final String? category;
  final String? epgChannelId;
  final String? channelNumber;
  final String? streamId;

  // Aliases keep the database vocabulary available at the feature boundary
  // without making the catalog carry a full database row.
  String get channelType => type;
  String? get groupName => category;
  String? get tvgId => epgChannelId;
}
