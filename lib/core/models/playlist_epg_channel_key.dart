/// Stable identity of an XMLTV channel inside one playlist-owned EPG cache.
class PlaylistEpgChannelKey {
  const PlaylistEpgChannelKey({
    required this.playlistId,
    required this.channelId,
  });

  final int playlistId;
  final String channelId;

  PlaylistEpgChannelKey normalized() => PlaylistEpgChannelKey(
    playlistId: playlistId,
    channelId: channelId.toLowerCase(),
  );

  @override
  bool operator ==(Object other) =>
      other is PlaylistEpgChannelKey &&
      other.playlistId == playlistId &&
      other.channelId == channelId;

  @override
  int get hashCode => Object.hash(playlistId, channelId);

  @override
  String toString() => 'PlaylistEpgChannelKey($playlistId, $channelId)';
}
