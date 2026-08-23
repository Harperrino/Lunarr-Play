import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_episode_catalog.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/providers/playback_preferences_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_assist.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_image_service.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_episode_navigation.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_state.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_playback_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_controls.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_episode_overlay.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_episode_overlay_layer.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_shortcut_region.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/providers/app_shell_state_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:window_manager/window_manager.dart';

/// Full-screen Jellyfin playback surface with its own media_kit instance.
///
/// Keyboard: a local shortcut scope handles Space (play/pause), M (mute) and
/// the arrow keys (seek). The global Lunarr shortcut wrapper is deliberately
/// untouched; if it intercepts those keys at runtime, the UI controls remain
/// the primary interaction path.
class JellyfinPlayerView extends ConsumerStatefulWidget {
  const JellyfinPlayerView({
    super.key,
    required this.connection,
    required this.item,
  });

  final JellyfinConnection connection;
  final JellyfinItem item;

  @override
  ConsumerState<JellyfinPlayerView> createState() => _JellyfinPlayerViewState();
}

class _JellyfinPlayerViewState extends ConsumerState<JellyfinPlayerView> {
  static const _fullscreenControlsHideDelay = Duration(seconds: 3);
  static const _fullscreenControlsAnimDuration = Duration(milliseconds: 280);

  late JellyfinItem _currentItem;
  late final OverlayPortalController _fullscreenOverlayController;
  Timer? _fullscreenControlsHideTimer;
  bool _leavingPlayer = false;
  bool _fullscreenBusy = false;
  bool _fullscreenControlsVisible = true;
  bool _episodeOverlayVisible = false;
  int? _episodeOverlaySeason;
  final FocusNode _episodeOverlayButtonFocusNode = FocusNode();
  final FocusNode _episodeOverlayCloseFocusNode = FocusNode();
  bool _switchingEpisode = false;
  List<JellyfinMediaSegment> _segments = const [];
  JellyfinTrickplayManifest? _trickplayManifest;
  JellyfinMediaSegment? _activeSkipSegment;
  final Set<String> _consumedSegments = {};
  JellyfinItem? _nextEpisode;
  Timer? _endcardTimer;
  int? _endcardRemaining;
  bool _endcardVisible = false;
  bool _endcardCancelled = false;
  int _assistGeneration = 0;
  String? _loadedTrickplayKey;
  JellyfinPlayerController? _listenedController;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _fullscreenOverlayController = OverlayPortalController()..show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = ref.read(jellyfinPlayerControllerProvider);
        _listenToController(controller);
        _resetAssistForItem();
        controller.play(_currentItem);
        if (ref.read(isFullscreenProvider)) {
          _scheduleFullscreenControlsHide();
        }
      }
    });
  }

  @override
  void dispose() {
    _cancelFullscreenControlsHide();
    _endcardTimer?.cancel();
    _listenedController?.state.removeListener(_onPlayerStateChanged);
    _episodeOverlayButtonFocusNode.dispose();
    _episodeOverlayCloseFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(JellyfinPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.connection.credentialId != widget.connection.credentialId) {
      _currentItem = widget.item;
      _episodeOverlayVisible = false;
      _episodeOverlaySeason = null;
      _resetAssistForItem();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(jellyfinPlayerControllerProvider).play(_currentItem);
        }
      });
    }
  }

  Future<void> _playEpisode(JellyfinItem episode) async {
    if (_switchingEpisode || episode.id == _currentItem.id) return;
    setState(() {
      _switchingEpisode = true;
      _currentItem = episode;
      _episodeOverlayVisible = false;
      _episodeOverlaySeason = null;
    });
    _resetAssistForItem();
    try {
      await ref.read(jellyfinPlayerControllerProvider).play(episode);
    } finally {
      if (mounted) setState(() => _switchingEpisode = false);
    }
  }

  Future<void> _leavePlayer() async {
    if (_leavingPlayer) return;
    _leavingPlayer = true;
    _endcardTimer?.cancel();

    try {
      await ref.read(jellyfinPlayerControllerProvider).stop();
      await _exitFullscreen();
    } finally {
      if (mounted) {
        jellyfinGoBack(ref);
      }
    }
  }

  void _listenToController(JellyfinPlayerController controller) {
    if (identical(_listenedController, controller)) return;
    _listenedController?.state.removeListener(_onPlayerStateChanged);
    _listenedController = controller;
    controller.state.addListener(_onPlayerStateChanged);
  }

  void _resetAssistForItem() {
    final generation = ++_assistGeneration;
    _endcardTimer?.cancel();
    _segments = const [];
    _trickplayManifest = null;
    _loadedTrickplayKey = null;
    _activeSkipSegment = null;
    _consumedSegments.clear();
    _endcardVisible = false;
    _endcardCancelled = false;
    _endcardRemaining = null;
    unawaited(_loadSegments(_currentItem, generation));
  }

  Future<void> _loadSegments(JellyfinItem item, int generation) async {
    final segments = await ref
        .read(jellyfinApiClientProvider)
        .fetchMediaSegments(widget.connection, itemId: item.id);
    if (!mounted ||
        generation != _assistGeneration ||
        item.id != _currentItem.id) {
      return;
    }
    setState(() => _segments = segments);
    _onPlayerStateChanged();
  }

  Future<void> _loadTrickplay(String mediaSourceId, int generation) async {
    final key = '${_currentItem.id}:$mediaSourceId';
    if (_loadedTrickplayKey == key) return;
    _loadedTrickplayKey = key;
    final manifest = await ref
        .read(jellyfinApiClientProvider)
        .fetchTrickplayManifest(
          widget.connection,
          itemId: _currentItem.id,
          mediaSourceId: mediaSourceId,
        );
    if (!mounted ||
        generation != _assistGeneration ||
        key != _loadedTrickplayKey) {
      return;
    }
    setState(() => _trickplayManifest = manifest);
  }

  void _onPlayerStateChanged() {
    if (!mounted || _listenedController == null) return;
    final state = _listenedController!.state.value;
    final preferences =
        ref.read(playbackPreferencesProvider).valueOrNull ??
        const PlaybackPreferences();
    final sourceId = state.mediaSourceId;
    if (preferences.trickplayEnabled && sourceId != null) {
      unawaited(_loadTrickplay(sourceId, _assistGeneration));
    }

    JellyfinMediaSegment? active;
    for (final segment in _segments) {
      if (segment.contains(state.position) &&
          (segment.type == JellyfinMediaSegmentType.intro ||
              segment.type == JellyfinMediaSegmentType.recap)) {
        active = segment;
        break;
      }
    }
    if (active != null &&
        preferences.mediaSegmentSkipMode == MediaSegmentSkipMode.automatic &&
        _consumedSegments.add(active.id)) {
      unawaited(_listenedController!.seek(active.end));
      active = null;
    }
    if (preferences.mediaSegmentSkipMode != MediaSegmentSkipMode.button) {
      active = null;
    }
    if (_activeSkipSegment?.id != active?.id) {
      setState(() => _activeSkipSegment = active);
    }

    final inOutro = _segments.any(
      (segment) =>
          segment.type == JellyfinMediaSegmentType.outro &&
          segment.contains(state.position),
    );
    if (inOutro || state.completed) _showEndcard();
  }

  void _showEndcard() {
    if (_endcardVisible ||
        _endcardCancelled ||
        !_currentItem.isEpisode ||
        _nextEpisode == null) {
      return;
    }
    final preferences =
        ref.read(playbackPreferencesProvider).valueOrNull ??
        const PlaybackPreferences();
    setState(() {
      _endcardVisible = true;
      _episodeOverlayVisible = false;
      _endcardRemaining = preferences.nextEpisodeAutoplayEnabled
          ? preferences.endcardCountdownSeconds
          : null;
    });
    if (preferences.nextEpisodeAutoplayEnabled) {
      _endcardTimer?.cancel();
      _endcardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_endcardVisible || _nextEpisode == null) {
          timer.cancel();
          return;
        }
        final state = _listenedController!.state.value;
        final inUnfinishedPlayback = !state.completed;
        if (inUnfinishedPlayback && !state.playing) return;
        final remaining = (_endcardRemaining ?? 1) - 1;
        if (remaining <= 0) {
          timer.cancel();
          unawaited(_playEpisode(_nextEpisode!));
        } else {
          setState(() => _endcardRemaining = remaining);
        }
      });
    }
  }

  void _cancelEndcard() {
    _endcardTimer?.cancel();
    setState(() {
      _endcardVisible = false;
      _endcardCancelled = true;
      _endcardRemaining = null;
    });
  }

  Future<void> _toggleFullscreen() async {
    if (_fullscreenBusy || !ref.read(isDesktopPlatformProvider)) return;
    _fullscreenBusy = true;
    try {
      final current = await windowManager.isFullScreen();
      final target = !current;
      ref.read(isFullscreenProvider.notifier).state = target;
      _syncFullscreenControls(target);
      await windowManager.setFullScreen(target);
      final actual = await windowManager.isFullScreen();
      if (mounted) {
        ref.read(isFullscreenProvider.notifier).state = actual;
        _syncFullscreenControls(actual);
      }
    } finally {
      _fullscreenBusy = false;
    }
  }

  Future<void> _exitFullscreen() async {
    if (!ref.read(isDesktopPlatformProvider)) return;
    if (!await windowManager.isFullScreen()) return;
    await windowManager.setFullScreen(false);
    if (mounted) {
      ref.read(isFullscreenProvider.notifier).state = false;
      _syncFullscreenControls(false);
    }
  }

  void _cancelFullscreenControlsHide() {
    _fullscreenControlsHideTimer?.cancel();
    _fullscreenControlsHideTimer = null;
  }

  void _scheduleFullscreenControlsHide() {
    if (!ref.read(isFullscreenProvider) || _episodeOverlayVisible) return;
    _cancelFullscreenControlsHide();
    _fullscreenControlsHideTimer = Timer(_fullscreenControlsHideDelay, () {
      if (!mounted ||
          !ref.read(isFullscreenProvider) ||
          _episodeOverlayVisible) {
        return;
      }
      setState(() => _fullscreenControlsVisible = false);
    });
  }

  void _syncFullscreenControls(bool fullscreen) {
    _cancelFullscreenControlsHide();
    if (!_fullscreenControlsVisible && mounted) {
      setState(() => _fullscreenControlsVisible = true);
    }
    if (fullscreen) _scheduleFullscreenControlsHide();
  }

  void _onFullscreenUserActivity() {
    if (!ref.read(isFullscreenProvider)) return;
    if (!_fullscreenControlsVisible) {
      setState(() => _fullscreenControlsVisible = true);
    }
    _scheduleFullscreenControlsHide();
  }

  void _toggleEpisodeOverlay(JellyfinEpisodeCatalog catalog) {
    if (_episodeOverlayVisible) {
      _closeEpisodeOverlay();
      return;
    }
    final initialSeason =
        catalog.seasonForItem(_currentItem.id) ??
        catalog.normalizedSeason(_currentItem.seasonNumber);
    setState(() {
      _episodeOverlayVisible = true;
      _episodeOverlaySeason = initialSeason;
      _fullscreenControlsVisible = true;
    });
    _cancelFullscreenControlsHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _episodeOverlayVisible) {
        _episodeOverlayCloseFocusNode.requestFocus();
      }
    });
  }

  void _closeEpisodeOverlay({bool restoreFocus = true}) {
    if (!_episodeOverlayVisible) return;
    setState(() => _episodeOverlayVisible = false);
    if (restoreFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _episodeOverlayButtonFocusNode.requestFocus();
      });
    }
    _scheduleFullscreenControlsHide();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(jellyfinPlayerControllerProvider);
    final fullscreen = ref.watch(isFullscreenProvider);
    final seriesId = _currentItem.seriesId;
    final episodesAsync = seriesId == null
        ? null
        : ref.watch(jellyfinSeriesEpisodesProvider(seriesId));
    final catalog = JellyfinEpisodeCatalog.fromEpisodes(
      episodesAsync?.valueOrNull ?? const <JellyfinItem>[],
    );
    final episodes = catalog.episodes;
    final currentIndex = episodes.indexWhere(
      (episode) => episode.id == _currentItem.id,
    );
    final hasEpisodeNavigation =
        _currentItem.isEpisode && seriesId != null && seriesId.isNotEmpty;
    final previousEpisode = currentIndex > 0
        ? episodes[currentIndex - 1]
        : null;
    final nextEpisode = currentIndex >= 0 && currentIndex + 1 < episodes.length
        ? episodes[currentIndex + 1]
        : null;
    _nextEpisode = jellyfinUnambiguousNextEpisode(episodes, _currentItem);
    if (controller.state.value.completed &&
        _nextEpisode != null &&
        !_endcardVisible &&
        !_endcardCancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showEndcard());
    }
    final preferences =
        ref.watch(playbackPreferencesProvider).valueOrNull ??
        const PlaybackPreferences();
    final overlaySeason = catalog.normalizedSeason(
      _episodeOverlaySeason ??
          catalog.seasonForItem(_currentItem.id) ??
          _currentItem.seasonNumber,
    );

    final controls = JellyfinPlayerControls(
      controller: controller,
      onStop: () => unawaited(_leavePlayer()),
      onPreviousEpisode: previousEpisode == null || _switchingEpisode
          ? null
          : () => unawaited(_playEpisode(previousEpisode)),
      onNextEpisode: nextEpisode == null || _switchingEpisode
          ? null
          : () => unawaited(_playEpisode(nextEpisode)),
      onToggleEpisodeOverlay: hasEpisodeNavigation
          ? () => _toggleEpisodeOverlay(catalog)
          : null,
      episodeOverlayVisible: _episodeOverlayVisible,
      episodeOverlayButtonFocusNode: _episodeOverlayButtonFocusNode,
      onToggleFullscreen: () => unawaited(_toggleFullscreen()),
      isFullscreen: fullscreen,
      seekIntervalSeconds: preferences.seekIntervalSeconds,
      trickplayManifest: preferences.trickplayEnabled
          ? _trickplayManifest
          : null,
      apiClient: ref.watch(jellyfinApiClientProvider),
      connection: widget.connection,
      itemId: _currentItem.id,
    );
    final playerStage = _buildPlayerStage(
      controller,
      fullscreen: fullscreen,
      hasEpisodeNavigation: hasEpisodeNavigation,
      catalog: catalog,
      selectedSeason: overlaySeason,
      loading: episodesAsync?.isLoading ?? false,
      hasError: episodesAsync?.hasError ?? false,
      seriesId: seriesId,
    );

    final windowedPlayer = _withShortcuts(
      controller,
      preferences.seekIntervalSeconds,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlayerHeader(
            controller: controller,
            onBack: () => unawaited(_leavePlayer()),
          ),
          Expanded(child: playerStage),
          controls,
        ],
      ),
    );
    final fullscreenPlayer = Material(
      key: const ValueKey('jellyfin-fullscreen-overlay'),
      color: Colors.black,
      child: Listener(
        onPointerDown: (_) => _onFullscreenUserActivity(),
        onPointerMove: (_) => _onFullscreenUserActivity(),
        onPointerHover: (_) => _onFullscreenUserActivity(),
        child: _withShortcuts(
          controller,
          preferences.seekIntervalSeconds,
          Stack(
            fit: StackFit.expand,
            children: [
              playerStage,
              Positioned(
                left: 12,
                right: 12,
                top: 8,
                child: AnimatedOpacity(
                  key: const ValueKey('jellyfin-fullscreen-header-layer'),
                  opacity: _fullscreenControlsVisible ? 1 : 0,
                  duration: _fullscreenControlsAnimDuration,
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !_fullscreenControlsVisible,
                    child: SafeArea(
                      bottom: false,
                      child: _PlayerHeader(
                        controller: controller,
                        onBack: () => unawaited(_leavePlayer()),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: AnimatedOpacity(
                  key: const ValueKey('jellyfin-fullscreen-controls-layer'),
                  opacity: _fullscreenControlsVisible ? 1 : 0,
                  duration: _fullscreenControlsAnimDuration,
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !_fullscreenControlsVisible,
                    child: SafeArea(top: false, child: controls),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return OverlayPortal(
      controller: _fullscreenOverlayController,
      overlayChildBuilder: (_) => fullscreen
          ? Positioned.fill(child: fullscreenPlayer)
          : const SizedBox.shrink(),
      child: fullscreen
          ? const SizedBox.expand(
              key: ValueKey('jellyfin-fullscreen-placeholder'),
            )
          : windowedPlayer,
    );
  }

  Widget _buildPlayerStage(
    JellyfinPlayerController controller, {
    required bool fullscreen,
    required bool hasEpisodeNavigation,
    required JellyfinEpisodeCatalog catalog,
    required int? selectedSeason,
    required bool loading,
    required bool hasError,
    required String? seriesId,
  }) {
    final videoSurface = _buildVideoSurface(controller, fullscreen: fullscreen);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 24).clamp(0.0, 440.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            videoSurface,
            if (hasEpisodeNavigation)
              Positioned(
                top: fullscreen ? 76 : 12,
                right: 12,
                bottom: fullscreen ? 116 : 12,
                width: width,
                child: JellyfinPlayerEpisodeOverlayLayer(
                  visible: _episodeOverlayVisible && !_endcardVisible,
                  child: JellyfinPlayerEpisodeOverlay(
                    connection: widget.connection,
                    imageService: ref.watch(jellyfinImageServiceProvider),
                    catalog: catalog,
                    selectedSeason: selectedSeason,
                    currentItemId: _currentItem.id,
                    loading: loading,
                    switchingEpisode: _switchingEpisode,
                    hasError: hasError,
                    onSeasonSelected: (season) {
                      setState(() => _episodeOverlaySeason = season);
                    },
                    onSelect: (episode) => unawaited(_playEpisode(episode)),
                    onRetry: seriesId == null
                        ? () {}
                        : () => ref
                              .read(
                                jellyfinSeriesEpisodesProvider(seriesId)
                                    .notifier,
                              )
                              .refresh(),
                    onClose: _closeEpisodeOverlay,
                    closeFocusNode: _episodeOverlayCloseFocusNode,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _withShortcuts(
    JellyfinPlayerController controller,
    int seekIntervalSeconds,
    Widget child,
  ) {
    void runWithActivity(Future<void> Function() action) {
      _onFullscreenUserActivity();
      unawaited(action());
    }

    return JellyfinPlayerShortcutRegion(
      episodeOverlayVisible: _episodeOverlayVisible,
      onTogglePlayPause: () => runWithActivity(controller.togglePlayPause),
      onToggleMute: () => runWithActivity(controller.toggleMute),
      onSeekBackward: () => runWithActivity(
        () => controller.seekRelative(Duration(seconds: -seekIntervalSeconds)),
      ),
      onSeekForward: () => runWithActivity(
        () => controller.seekRelative(Duration(seconds: seekIntervalSeconds)),
      ),
      onEscape: () {
        if (_episodeOverlayVisible) _closeEpisodeOverlay();
      },
      child: child,
    );
  }

  Widget _buildVideoSurface(
    JellyfinPlayerController controller, {
    required bool fullscreen,
  }) {
    return ClipRRect(
      borderRadius: fullscreen ? BorderRadius.zero : BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: ValueListenableBuilder<JellyfinPlayerState>(
          valueListenable: controller.state,
          builder: (context, state, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                if (state.initialized)
                  Video(
                    key: ValueKey(state.playerGeneration),
                    controller: controller.videoController,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                  )
                else
                  const SizedBox.expand(),
                if (state.error)
                  _PlayerError(onBack: () => unawaited(_leavePlayer()))
                else if (state.buffering || !state.initialized)
                  const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                if (_activeSkipSegment != null && !_endcardVisible)
                  Positioned(
                    right: 24,
                    bottom: 24,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        final segment = _activeSkipSegment!;
                        _consumedSegments.add(segment.id);
                        setState(() => _activeSkipSegment = null);
                        unawaited(controller.seek(segment.end));
                      },
                      icon: const Icon(Icons.fast_forward_rounded),
                      label: Text(
                        _activeSkipSegment!.type ==
                                JellyfinMediaSegmentType.recap
                            ? context.l10n.jellyfinSkipRecap
                            : context.l10n.jellyfinSkipIntro,
                      ),
                    ),
                  ),
                if (_endcardVisible && _nextEpisode != null)
                  _JellyfinEndcard(
                    connection: widget.connection,
                    episode: _nextEpisode!,
                    remaining: _endcardRemaining,
                    onPlayNow: () => unawaited(_playEpisode(_nextEpisode!)),
                    onCancel: _cancelEndcard,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _JellyfinEndcard extends StatelessWidget {
  const _JellyfinEndcard({
    required this.connection,
    required this.episode,
    required this.remaining,
    required this.onPlayNow,
    required this.onCancel,
  });

  final JellyfinConnection connection;
  final JellyfinItem episode;
  final int? remaining;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = const JellyfinImageService().posterUrl(
      connection,
      itemId: episode.id,
      imageTag: episode.primaryImageTag,
      maxWidth: 640,
    );
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppSurface(
                level: AppSurfaceLevel.high,
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 520;
                    final artwork = ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: narrow ? double.infinity : 260,
                        height: narrow ? 150 : 146,
                        child: imageUrl == null
                            ? ColoredBox(
                                color: colors.secondaryContainer,
                                child: Icon(
                                  Icons.movie_filter_rounded,
                                  size: 48,
                                  color: colors.onSecondaryContainer,
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => ColoredBox(
                                  color: colors.secondaryContainer,
                                  child: Icon(
                                    Icons.movie_filter_rounded,
                                    size: 48,
                                    color: colors.onSecondaryContainer,
                                  ),
                                ),
                              ),
                      ),
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.jellyfinUpNext,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.secondary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          jellyfinSeasonEpisodeLabel(
                            context.l10n,
                            season: episode.seasonNumber,
                            episode: episode.episodeNumber,
                          ),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          episode.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: onPlayNow,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                remaining == null
                                    ? context.l10n.jellyfinPlayNow
                                    : context.l10n.jellyfinPlayNowCountdown(
                                        remaining!,
                                      ),
                              ),
                            ),
                            TextButton(
                              onPressed: onCancel,
                              child: Text(context.l10n.jellyfinEndcardCancel),
                            ),
                          ],
                        ),
                      ],
                    );
                    if (narrow) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          artwork,
                          const SizedBox(height: 14),
                          details,
                        ],
                      );
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        artwork,
                        const SizedBox(width: 18),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.controller, required this.onBack});

  final JellyfinPlayerController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ValueListenableBuilder<JellyfinPlayerState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.commonBackTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  state.title.isEmpty ? l10n.jellyfinConnected : state.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (state.method != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    switch (state.method!) {
                      JellyfinPlaybackMethod.directPlay =>
                        l10n.jellyfinPlayerDirectPlay,
                      JellyfinPlaybackMethod.directStream =>
                        l10n.jellyfinPlayerDirectStream,
                      JellyfinPlaybackMethod.transcode =>
                        l10n.jellyfinPlayerTranscode,
                    },
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
          const SizedBox(height: 12),
          Text(
            context.l10n.jellyfinPlayerFailed,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onBack,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: Text(context.l10n.jellyfinStopTooltip),
          ),
        ],
      ),
    );
  }
}
