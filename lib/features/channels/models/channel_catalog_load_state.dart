/// Presentation state of the Live channel catalogue. The catalogue renders
/// progressively: existing rows are never replaced by a loading state.
enum ChannelCatalogLoadState {
  /// No rows available yet, first query running (shimmer area).
  initialLoading,

  /// Rows visible while a refresh runs (slim header indicator).
  refreshing,

  /// Rows visible, nothing loading.
  ready,

  /// First value still missing after the slow threshold (escalated hint).
  slow,

  /// Refresh failed while previous rows remain visible (non-blocking note).
  errorWithData,
}

/// Pure resolution used by the panel and widget tests.
ChannelCatalogLoadState resolveChannelCatalogLoadState({
  required bool hasRows,
  required bool isLoading,
  required bool hasError,
  required bool slowElapsed,
}) {
  if (hasError && hasRows) return ChannelCatalogLoadState.errorWithData;
  if (hasRows) {
    return isLoading
        ? ChannelCatalogLoadState.refreshing
        : ChannelCatalogLoadState.ready;
  }
  if (isLoading) {
    return slowElapsed
        ? ChannelCatalogLoadState.slow
        : ChannelCatalogLoadState.initialLoading;
  }
  return ChannelCatalogLoadState.ready;
}
