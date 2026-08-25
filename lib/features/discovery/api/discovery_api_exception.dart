enum DiscoveryFailureKind {
  missingConfiguration,
  invalidEndpoint,
  unauthorized,
  forbidden,
  conflict,
  unsupportedVersion,
  timeout,
  responseTooLarge,
  invalidResponse,
  network,
}

class DiscoveryApiException implements Exception {
  const DiscoveryApiException(this.kind, {this.statusCode});

  final DiscoveryFailureKind kind;
  final int? statusCode;

  @override
  String toString() => 'DiscoveryApiException(${kind.name})';
}
