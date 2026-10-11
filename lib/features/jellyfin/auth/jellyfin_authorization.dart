/// Jellyfin's current authentication contract, also supported by older servers.
/// Legacy X-Emby headers and api_key query parameters can be disabled in 12.1.
String jellyfinAuthorization({String? deviceId, String? token}) {
  String quoted(String value) => '"${Uri.encodeComponent(value)}"';
  return 'MediaBrowser Client="Lunarr Player", Device="Lunarr Player", '
      '${deviceId == null ? '' : 'DeviceId=${quoted(deviceId)}, '}'
      'Version="1.0.3", Token=${quoted(token ?? '')}';
}
