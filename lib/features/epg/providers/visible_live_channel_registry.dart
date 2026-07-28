import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight immutable projection of one built Live row. The registry and
/// the EPG matchers work on this projection only — never on full channel rows.
class VisibleLiveChannelCandidate {
  const VisibleLiveChannelCandidate({
    required this.channelId,
    required this.playlistId,
    required this.name,
    required this.tvgId,
  });

  final int channelId;
  final int playlistId;
  final String name;
  final String? tvgId;

  @override
  bool operator ==(Object other) =>
      other is VisibleLiveChannelCandidate &&
      other.channelId == channelId &&
      other.playlistId == playlistId &&
      other.name == name &&
      other.tvgId == tvgId;

  @override
  int get hashCode => Object.hash(channelId, playlistId, name, tvgId);

  @override
  String toString() => 'VisibleLiveChannelCandidate($channelId, $name)';
}

/// Tracks which Live channel rows are actually built — the visible viewport
/// plus the prerendered cache extent of the list.
///
/// The Live EPG pipeline is bounded to this registry instead of the whole
/// filtered catalogue, so a 100k-channel catalogue never triggers an EPG
/// lookup for more than [maxPublishedIds] channels. Mutations are bundled
/// over [publishDelay]; identical sets are never republished, which keeps
/// exactly one bulk EPG subscription per distinct visible set.
class VisibleLiveChannelRegistry {
  VisibleLiveChannelRegistry({
    this.publishDelay = const Duration(milliseconds: 75),
    this.maxPublishedIds = 64,
  });

  final Duration publishDelay;
  final int maxPublishedIds;

  /// Insertion-ordered candidates by channel ID; re-registering refreshes
  /// recency and replaces the projection.
  final LinkedHashMap<int, VisibleLiveChannelCandidate> _candidates =
      LinkedHashMap<int, VisibleLiveChannelCandidate>();
  Timer? _publishTimer;
  List<VisibleLiveChannelCandidate>? _lastPublished;
  final StreamController<List<VisibleLiveChannelCandidate>> _changes =
      StreamController<List<VisibleLiveChannelCandidate>>.broadcast();
  bool _disposed = false;

  /// Bundled bounded visible sets, newest registration last.
  Stream<List<VisibleLiveChannelCandidate>> get changes => _changes.stream;

  /// The most recently published bounded set (empty before the first one).
  List<VisibleLiveChannelCandidate> get current =>
      List<VisibleLiveChannelCandidate>.unmodifiable(
        _lastPublished ?? const <VisibleLiveChannelCandidate>[],
      );

  void register(VisibleLiveChannelCandidate candidate) {
    if (_disposed) return;
    _candidates.remove(candidate.channelId);
    _candidates[candidate.channelId] = candidate;
    _schedulePublish();
  }

  void unregister(int channelId) {
    if (_disposed) return;
    if (_candidates.remove(channelId) != null) _schedulePublish();
  }

  void _schedulePublish() {
    _publishTimer ??= Timer(publishDelay, _publish);
  }

  void _publish() {
    _publishTimer = null;
    if (_disposed) return;

    final values = _candidates.values.toList(growable: false);
    final bounded = values.length <= maxPublishedIds
        ? values
        : values.sublist(values.length - maxPublishedIds);
    final previous = _lastPublished;
    if (previous != null &&
        previous.length == bounded.length &&
        _sameSet(previous, bounded)) {
      return;
    }
    _lastPublished = bounded;
    if (!_changes.isClosed) {
      _changes.add(List<VisibleLiveChannelCandidate>.unmodifiable(bounded));
    }
  }

  static bool _sameSet(
    List<VisibleLiveChannelCandidate> a,
    List<VisibleLiveChannelCandidate> b,
  ) {
    final byId = {for (final candidate in a) candidate.channelId: candidate};
    for (final candidate in b) {
      if (byId[candidate.channelId] != candidate) return false;
    }
    return true;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _publishTimer?.cancel();
    unawaited(_changes.close());
  }
}

/// Process-wide registry boundary. Rows register on mount and unregister on
/// dispose; the provider owns the registry lifetime.
final visibleLiveChannelRegistryProvider = Provider<VisibleLiveChannelRegistry>(
  (ref) {
    final registry = VisibleLiveChannelRegistry();
    ref.onDispose(registry.dispose);
    return registry;
  },
);

/// Latest bundled visible Live channel candidates. Emits only on real set
/// changes, never on scrolls that keep the same rows mounted.
final visibleLiveChannelCandidatesProvider =
    StreamProvider<List<VisibleLiveChannelCandidate>>((ref) {
      return ref.watch(visibleLiveChannelRegistryProvider).changes;
    });
