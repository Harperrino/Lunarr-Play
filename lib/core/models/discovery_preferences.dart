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
    this.startupDestination = AppStartupDestination.home,
  });

  final DiscoverySource source;
  final String seerrEndpoint;
  final AppStartupDestination startupDestination;

  DiscoveryPreferences copyWith({
    DiscoverySource? source,
    String? seerrEndpoint,
    AppStartupDestination? startupDestination,
  }) => DiscoveryPreferences(
    source: source ?? this.source,
    seerrEndpoint: seerrEndpoint ?? this.seerrEndpoint,
    startupDestination: startupDestination ?? this.startupDestination,
  );
}
