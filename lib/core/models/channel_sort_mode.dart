/// Ordering modes for the live channel catalogue.
enum ChannelSortMode { providerDefault, alphabetical, numeric }

ChannelSortMode channelSortModeFromStorage(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'alphabetical' => ChannelSortMode.alphabetical,
    'numeric' => ChannelSortMode.numeric,
    _ => ChannelSortMode.providerDefault,
  };
}

extension ChannelSortModeStorage on ChannelSortMode {
  String get storageValue => name;
}
