import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';

String discoveryFailureText(AppLocalizations l10n, Object error) {
  final kind = error is DiscoveryApiException
      ? error.kind
      : DiscoveryFailureKind.network;
  return switch (kind) {
    DiscoveryFailureKind.missingConfiguration =>
      l10n.discoveryFailureMissingConfiguration,
    DiscoveryFailureKind.invalidEndpoint =>
      l10n.discoveryFailureInvalidEndpoint,
    DiscoveryFailureKind.unauthorized => l10n.discoveryFailureUnauthorized,
    DiscoveryFailureKind.forbidden => l10n.discoveryFailureForbidden,
    DiscoveryFailureKind.conflict => l10n.discoveryFailureConflict,
    DiscoveryFailureKind.unsupportedVersion =>
      l10n.discoveryFailureUnsupportedVersion,
    DiscoveryFailureKind.timeout => l10n.discoveryFailureTimeout,
    DiscoveryFailureKind.responseTooLarge =>
      l10n.discoveryFailureResponseTooLarge,
    DiscoveryFailureKind.invalidResponse =>
      l10n.discoveryFailureInvalidResponse,
    DiscoveryFailureKind.network => l10n.discoveryFailureNetwork,
  };
}

String discoveryShelfTitle(AppLocalizations l10n, DiscoveryShelfKind kind) =>
    switch (kind) {
      DiscoveryShelfKind.popularMovies => l10n.discoveryPopularMovies,
      DiscoveryShelfKind.popularTv => l10n.discoveryPopularSeries,
      DiscoveryShelfKind.upcomingMovies => l10n.discoveryUpcomingMovies,
      DiscoveryShelfKind.onTheAir => l10n.discoveryOnTheAir,
      DiscoveryShelfKind.topRated => l10n.discoveryTopRated,
    };

String discoveryMediaTypeText(AppLocalizations l10n, DiscoveryMediaType type) =>
    switch (type) {
      DiscoveryMediaType.movie => l10n.discoveryMovie,
      DiscoveryMediaType.tv => l10n.discoverySeries,
    };

String? discoveryStatusText(AppLocalizations l10n, DiscoveryMediaItem item) {
  if (item.requestStatus != DiscoveryRequestStatus.none) {
    return switch (item.requestStatus) {
      DiscoveryRequestStatus.pending => l10n.discoveryRequestPending,
      DiscoveryRequestStatus.approved => l10n.discoveryRequestApproved,
      DiscoveryRequestStatus.declined => l10n.discoveryRequestDeclined,
      DiscoveryRequestStatus.none => null,
    };
  }
  return switch (item.availability) {
    DiscoveryAvailability.available => l10n.discoveryAvailabilityAvailable,
    DiscoveryAvailability.pending => l10n.discoveryAvailabilityPending,
    DiscoveryAvailability.processing => l10n.discoveryAvailabilityProcessing,
    DiscoveryAvailability.partiallyAvailable =>
      l10n.discoveryAvailabilityPartiallyAvailable,
    DiscoveryAvailability.deleted => l10n.discoveryAvailabilityDeleted,
    DiscoveryAvailability.unknown => null,
  };
}
