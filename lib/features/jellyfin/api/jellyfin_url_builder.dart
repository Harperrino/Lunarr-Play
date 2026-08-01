import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';

/// Normalizes user-entered server addresses and builds Jellyfin endpoints.
class JellyfinUrlBuilder {
  const JellyfinUrlBuilder();

  static final RegExp _trailingSlashes = RegExp(r'/+$');

  /// Normalizes a user-entered server address.
  ///
  /// Accepts `http` and `https`, prepends `http://` when no scheme is given,
  /// strips trailing slashes and rejects malformed or credentialed input.
  String normalizeBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Server address is empty.',
      );
    }

    if (!value.contains('://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.isEmpty ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        value.contains(RegExp(r'\s'))) {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Server address could not be parsed.',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Only http and https server addresses are supported.',
      );
    }

    final builder = Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
    final normalized = builder.toString().replaceAll(_trailingSlashes, '');
    if (normalized.isEmpty || normalized == '$scheme:') {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Server address could not be parsed.',
      );
    }
    return normalized;
  }

  Uri systemInfoPublic(String baseUrl) => Uri.parse('$baseUrl/System/Info/Public');

  Uri authenticateByName(String baseUrl) =>
      Uri.parse('$baseUrl/Users/AuthenticateByName');

  Uri sessionsLogout(String baseUrl) => Uri.parse('$baseUrl/Sessions/Logout');
}
