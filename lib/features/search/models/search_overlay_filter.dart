enum SearchOverlayFilter { all, channels, categories }

extension SearchOverlayFilterLabels on SearchOverlayFilter {
  String get label => switch (this) {
    SearchOverlayFilter.all => 'Alle',
    SearchOverlayFilter.channels => 'Channel',
    SearchOverlayFilter.categories => 'Kategorien',
  };
}
