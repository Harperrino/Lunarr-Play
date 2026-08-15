import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_state.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_playback_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_controls.dart';
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
  bool _episodePickerExpanded = false;
  bool _switchingEpisode = false;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _fullscreenOverlayController = OverlayPortalController()..show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(jellyfinPlayerControllerProvider).play(_currentItem);
        if (ref.read(isFullscreenProvider)) {
          _scheduleFullscreenControlsHide();
        }
      }
    });
  }

  @override
  void dispose() {
    _cancelFullscreenControlsHide();
    super.dispose();
  }

  @override
  void didUpdateWidget(JellyfinPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _currentItem = widget.item;
      _episodePickerExpanded = false;
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
    });
    try {
      await ref.read(jellyfinPlayerControllerProvider).play(episode);
    } finally {
      if (mounted) setState(() => _switchingEpisode = false);
    }
  }

  Future<void> _leavePlayer() async {
    if (_leavingPlayer) return;
    _leavingPlayer = true;

    try {
      await ref.read(jellyfinPlayerControllerProvider).stop();
      await _exitFullscreen();
    } finally {
      if (mounted) {
        jellyfinGoBack(ref);
      }
    }
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
    if (!ref.read(isFullscreenProvider) || _episodePickerExpanded) return;
    _cancelFullscreenControlsHide();
    _fullscreenControlsHideTimer = Timer(_fullscreenControlsHideDelay, () {
      if (!mounted ||
          !ref.read(isFullscreenProvider) ||
          _episodePickerExpanded) {
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

  void _toggleEpisodePicker() {
    final expanded = !_episodePickerExpanded;
    setState(() {
      _episodePickerExpanded = expanded;
      if (expanded) _fullscreenControlsVisible = true;
    });
    if (!ref.read(isFullscreenProvider)) return;
    if (expanded) {
      _cancelFullscreenControlsHide();
    } else {
      _scheduleFullscreenControlsHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(jellyfinPlayerControllerProvider);
    final fullscreen = ref.watch(isFullscreenProvider);
    final seriesId = _currentItem.seriesId;
    final episodesAsync = seriesId == null
        ? null
        : ref.watch(jellyfinSeriesEpisodesProvider(seriesId));
    final episodes = [...?episodesAsync?.valueOrNull]..sort(_compareEpisodes);
    final currentIndex = episodes.indexWhere(
      (episode) => episode.id == _currentItem.id,
    );
    final hasEpisodeNavigation = _currentItem.isEpisode && seriesId != null;
    final previousEpisode = currentIndex > 0
        ? episodes[currentIndex - 1]
        : null;
    final nextEpisode = currentIndex >= 0 && currentIndex + 1 < episodes.length
        ? episodes[currentIndex + 1]
        : null;

    final videoSurface = _buildVideoSurface(controller, fullscreen: fullscreen);
    final episodePicker = AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: _episodePickerExpanded && hasEpisodeNavigation
          ? _EpisodePicker(
              episodes: episodes,
              currentItemId: _currentItem.id,
              loading: episodesAsync?.isLoading ?? false,
              onSelect: (episode) => unawaited(_playEpisode(episode)),
            )
          : const SizedBox.shrink(),
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
      onToggleEpisodePicker: hasEpisodeNavigation ? _toggleEpisodePicker : null,
      episodePickerExpanded: _episodePickerExpanded,
      onToggleFullscreen: () => unawaited(_toggleFullscreen()),
      isFullscreen: fullscreen,
    );

    final windowedPlayer = _withShortcuts(
      controller,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlayerHeader(
            controller: controller,
            onBack: () => unawaited(_leavePlayer()),
          ),
          Expanded(child: videoSurface),
          episodePicker,
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
        child: _withShortcuts(
          controller,
          Stack(
            fit: StackFit.expand,
            children: [
              videoSurface,
              Positioned.fill(
                child: MouseRegion(
                  onEnter: (_) => _onFullscreenUserActivity(),
                  onHover: (_) => _onFullscreenUserActivity(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onFullscreenUserActivity,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
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
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [episodePicker, controls],
                      ),
                    ),
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

  Widget _withShortcuts(JellyfinPlayerController controller, Widget child) {
    void runWithActivity(Future<void> Function() action) {
      _onFullscreenUserActivity();
      unawaited(action());
    }

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          SingleActivator(LogicalKeyboardKey.space): () =>
              runWithActivity(controller.togglePlayPause),
          SingleActivator(LogicalKeyboardKey.keyM): () =>
              runWithActivity(controller.toggleMute),
          SingleActivator(LogicalKeyboardKey.arrowLeft): () => runWithActivity(
            () => controller.seekRelative(const Duration(seconds: -10)),
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              runWithActivity(
                () => controller.seekRelative(const Duration(seconds: 10)),
              ),
        },
        child: child,
      ),
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
              ],
            );
          },
        ),
      ),
    );
  }
}

int _compareEpisodes(JellyfinItem left, JellyfinItem right) {
  final season = (left.seasonNumber ?? 0).compareTo(right.seasonNumber ?? 0);
  if (season != 0) return season;
  final episode = (left.episodeNumber ?? 0).compareTo(right.episodeNumber ?? 0);
  if (episode != 0) return episode;
  return left.name.compareTo(right.name);
}

class _EpisodePicker extends StatelessWidget {
  const _EpisodePicker({
    required this.episodes,
    required this.currentItemId,
    required this.loading,
    required this.onSelect,
  });

  final List<JellyfinItem> episodes;
  final String currentItemId;
  final bool loading;
  final ValueChanged<JellyfinItem> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      key: const ValueKey('jellyfin-episode-picker'),
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.jellyfinEpisodesTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: loading && episodes.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: episodes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      final selected = episode.id == currentItemId;
                      return SizedBox(
                        width: 210,
                        child: Material(
                          color: selected
                              ? colors.secondaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            key: ValueKey(
                              'jellyfin-player-episode-${episode.id}',
                            ),
                            borderRadius: BorderRadius.circular(14),
                            onTap: selected ? null : () => onSelect(episode),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    jellyfinSeasonEpisodeLabel(
                                      context.l10n,
                                      season: episode.seasonNumber,
                                      episode: episode.episodeNumber,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    episode.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
