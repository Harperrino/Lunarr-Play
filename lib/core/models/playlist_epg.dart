import 'package:m3uxtream_player/core/database/app_database.dart';

/// EPG URLs are split into provider metadata and an explicit user override.
///
/// M3U headers update [Playlist.epgUrl] during sync. User input is stored in
/// [Playlist.epgUrlOverride] and therefore survives future source refreshes.
extension PlaylistEpgSource on Playlist {
  String? get effectiveEpgUrl {
    final override = epgUrlOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    final automatic = epgUrl?.trim();
    return automatic == null || automatic.isEmpty ? null : automatic;
  }

  bool get hasEpgUrlOverride {
    final value = epgUrlOverride?.trim();
    return value != null && value.isNotEmpty;
  }
}
