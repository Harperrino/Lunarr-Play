enum DiscoverySource {
  tmdb,
  seerr;

  static DiscoverySource fromStorage(String? value) => switch (value) {
    'seerr' => DiscoverySource.seerr,
    _ => DiscoverySource.tmdb,
  };
}

enum AppStartupDestination {
  home,
  live;

  static AppStartupDestination fromStorage(String? value) => switch (value) {
    'home' => AppStartupDestination.home,
    _ => AppStartupDestination.live,
  };
}

class DiscoveryPreferences {
  const DiscoveryPreferences({
    this.source = DiscoverySource.tmdb,
    this.seerrEndpoint = '',
    this.seerrHttpConfirmedEndpoint = '',
    this.startupDestination = AppStartupDestination.home,
  });

  final DiscoverySource source;
  final String seerrEndpoint;
  final String seerrHttpConfirmedEndpoint;
  final AppStartupDestination startupDestination;

  DiscoveryPreferences copyWith({
    DiscoverySource? source,
    String? seerrEndpoint,
    String? seerrHttpConfirmedEndpoint,
    AppStartupDestination? startupDestination,
  }) => DiscoveryPreferences(
    source: source ?? this.source,
    seerrEndpoint: seerrEndpoint ?? this.seerrEndpoint,
    seerrHttpConfirmedEndpoint:
        seerrHttpConfirmedEndpoint ?? this.seerrHttpConfirmedEndpoint,
    startupDestination: startupDestination ?? this.startupDestination,
  );
}
