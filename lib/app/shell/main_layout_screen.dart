import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/providers/app_shutdown_providers.dart';
import 'package:m3uxtream_player/app/bootstrap/desktop_window_bootstrap.dart';
import 'package:m3uxtream_player/app/shell/shell_tab_labels.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/app/shell/standard_app_shell.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/channel_navigation.dart';
import 'package:m3uxtream_player/core/services/fullscreen_toggle.dart';
import 'package:m3uxtream_player/core/shortcuts/global_shortcuts.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_command_providers.dart';
import 'package:m3uxtream_player/features/player/services/player_ui_command_runner.dart';
import 'package:m3uxtream_player/features/player/vod/vod_playback_video_overlay.dart';
import 'package:m3uxtream_player/features/player/widgets/live_tab_shell.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/media_library_providers.dart';
import 'package:m3uxtream_player/shared/widgets/custom_app_bar.dart';
import 'package:m3uxtream_player/shared/widgets/neural_background.dart';
import 'package:window_manager/window_manager.dart';

/// Root layout: shortcuts, fullscreen, live vs. standard shell, VOD video overlay.
class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen>
    with WindowListener {
  final GlobalKey _playerPanelKey = GlobalKey();
  bool _fullscreenBusy = false;
  bool _sidebarExpanded = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(isDesktopPlatformProvider)) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_prepareDesktopWindow());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFullscreenState());
  }

  @override
  void dispose() {
    if (ref.read(isDesktopPlatformProvider)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _syncFullscreenState() async {
    if (!ref.read(isDesktopPlatformProvider)) return;

    try {
      final isFs = await windowManager.isFullScreen();
      if (mounted) {
        ref.read(isFullscreenProvider.notifier).state = isFs;
        AppLogger.info(
          'MainLayout: Synced fullscreen state from window manager → $isFs',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'MainLayout: Failed to read window fullscreen state',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _prepareDesktopWindow() async {
    if (!mounted || !ref.read(isDesktopPlatformProvider)) return;

    try {
      await windowManager.setPreventClose(true);
      await windowManager.waitUntilReadyToShow(desktopWindowOptions, () async {
        if (!mounted) return;
        await windowManager.show();
        await windowManager.focus();
        AppLogger.info('App Startup: Immersive Window successfully drawn.');
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'MainLayout: Failed to prepare desktop window',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _setFullscreen(bool enabled) async {
    if (_fullscreenBusy || !ref.read(isDesktopPlatformProvider)) return;

    _fullscreenBusy = true;
    try {
      // Layout first — immersive shell before OS window resize keeps the video surface alive.
      ref.read(isFullscreenProvider.notifier).state = enabled;
      await SchedulerBinding.instance.endOfFrame;
      if (enabled && isSeekableChannel(ref.read(selectedChannelProvider))) {
        // VOD layout + surface resize needs an extra frame before OS fullscreen.
        await SchedulerBinding.instance.endOfFrame;
      }

      await windowManager.setFullScreen(enabled);
      if (!mounted) return;

      final actual = await windowManager.isFullScreen();
      if (actual != enabled) {
        ref.read(isFullscreenProvider.notifier).state = actual;
        AppLogger.warning(
          'MainLayout: Fullscreen OS state ($actual) differed from target ($enabled).',
        );
      }

      AppLogger.info('MainLayout: Fullscreen set to $actual');

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ref
            .read(uiLogsProvider.notifier)
            .addLog('Shortcut: Fullscreen ${actual ? 'ON' : 'OFF'}.');
        try {
          await windowManager.focus();
        } catch (e, stackTrace) {
          AppLogger.error(
            'MainLayout: Failed to focus window after fullscreen',
            e,
            stackTrace,
          );
        }
      });
    } catch (e, stackTrace) {
      AppLogger.error('MainLayout: Failed to set fullscreen', e, stackTrace);
    } finally {
      _fullscreenBusy = false;
    }
  }

  Future<void> _toggleFullscreen() async {
    if (!ref.read(isDesktopPlatformProvider)) return;

    try {
      final actual = await windowManager.isFullScreen();
      final target = resolveFullscreenToggleTarget(actualOsFullscreen: actual);
      await _setFullscreen(target);
    } catch (e, stackTrace) {
      AppLogger.error('MainLayout: Failed to toggle fullscreen', e, stackTrace);
    }
  }

  Future<void> _exitFullscreen() async {
    if (!ref.read(isDesktopPlatformProvider)) return;

    try {
      final actual = await windowManager.isFullScreen();
      if (!actual) {
        ref.read(isFullscreenProvider.notifier).state = false;
        return;
      }
      await _setFullscreen(false);
    } catch (e, stackTrace) {
      AppLogger.error('MainLayout: Failed to exit fullscreen', e, stackTrace);
    }
  }

  Future<void> _requestShutdown({required String reason}) async {
    await ref
        .read(appShutdownControllerProvider)
        .requestShutdown(reason: reason);
  }

  void _wakeImmersiveControls() {
    if (ref.read(immersiveLayoutProvider)) {
      ref.read(immersiveUserActivityTickProvider.notifier).state++;
    }
  }

  void _toggleSidebarExpanded() {
    setState(() {
      _sidebarExpanded = !_sidebarExpanded;
    });
  }

  void _switchChannel(int direction) {
    final channels = ref.read(filteredChannelsProvider);
    if (channels.isEmpty) {
      ref
          .read(uiLogsProvider.notifier)
          .addLog('Shortcut: No channels available.');
      return;
    }

    final selected = ref.read(selectedChannelProvider);
    final channel = navigateChannel(
      channels: channels,
      selected: selected,
      direction: direction,
    );

    if (channel == null) {
      if (selected != null) {
        ref
            .read(uiLogsProvider.notifier)
            .addLog('Shortcut: Selected channel not in filtered list.');
      }
      return;
    }

    ref.read(selectedChannelProvider.notifier).state = channel;
    ref.read(playerNotifierProvider.notifier).openStream(channel.streamUrl);
    ref
        .read(uiLogsProvider.notifier)
        .addLog(
          'Shortcut: Switched to "${channel.name}" (${direction > 0 ? 'next' : 'prev'}).',
        );
    _wakeImmersiveControls();
  }

  void _syncSelectedPlaylist() {
    final playlists = ref.read(playlistsStreamProvider).valueOrNull;
    final inactiveIds = ref.read(inactivePlaylistIdsProvider).valueOrNull;
    if (playlists == null || inactiveIds == null) return;
    normalizeSelectedPlaylist(ref, playlists, inactiveIds);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activeSidebarIndexProvider, (previous, next) {
      final navigationIndex = shellNavigationIndexFor(next);
      if (navigationIndex != next) {
        ref.read(mediaLibraryTabProvider.notifier).state =
            shellLibrarySubtabFor(next);
        ref.read(activeSidebarIndexProvider.notifier).state = navigationIndex;
        return;
      }
      if (previous == shellLiveTabIndex &&
          next != shellLiveTabIndex &&
          ref.read(isFullscreenProvider)) {
        _exitFullscreen();
      }
    });

    ref.listen<AsyncValue<bool>>(debugModeProvider, (previous, next) {
      final wasEnabled = previous?.valueOrNull ?? false;
      final isEnabled = next.valueOrNull ?? false;
      if (wasEnabled == isEnabled) return;

      if (!isEnabled &&
          ref.read(activeSidebarIndexProvider) == shellDiagnosticsTabIndex) {
        ref.read(activeSidebarIndexProvider.notifier).state =
            shellSettingsTabIndex;
        ref
            .read(uiLogsProvider.notifier)
            .addLog('Debug mode disabled. Returned to Settings.');
      }
    });

    ref.listen<AsyncValue<List<Playlist>>>(
      playlistsStreamProvider,
      (_, _) => _syncSelectedPlaylist(),
    );
    ref.listen<AsyncValue<Set<int>>>(
      inactivePlaylistIdsProvider,
      (_, _) => _syncSelectedPlaylist(),
    );

    final debugModeEnabled = ref.watch(debugModeProvider).valueOrNull ?? false;
    final immersive = ref.watch(immersiveLayoutProvider);
    final activeIndex = shellNavigationIndexFor(
      ref.watch(activeSidebarIndexProvider),
    );
    final onLiveTab = activeIndex == shellLiveTabIndex;

    return GlobalShortcutsWrapper(
      requestFocusTrigger: immersive,
      channelNavigationEnabled: onLiveTab,
      onPlayPause: () {
        unawaited(
          ref
              .read(playerUiCommandRunnerProvider)
              .togglePlay(origin: PlayerUiCommandOrigin.shortcut),
        );
        _wakeImmersiveControls();
      },
      onToggleFullscreen: _toggleFullscreen,
      onExitFullscreen: _exitFullscreen,
      onToggleMute: () async {
        await ref.read(playerNotifierProvider.notifier).toggleMute();
        final volume =
            ref.read(playerNotifierProvider).valueOrNull?.volume ?? 0.0;
        ref
            .read(uiLogsProvider.notifier)
            .addLog(
              'Shortcut: Mute toggled. Volume: ${volume.toStringAsFixed(1)}',
            );
        _wakeImmersiveControls();
      },
      onVolumeAdjust: (delta) {
        unawaited(
          ref
              .read(playerUiCommandRunnerProvider)
              .adjustVolume(delta, origin: PlayerUiCommandOrigin.shortcut),
        );
        _wakeImmersiveControls();
      },
      onNextChannel: () => _switchChannel(1),
      onPrevChannel: () => _switchChannel(-1),
      child: Scaffold(
        extendBodyBehindAppBar: false,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            immersive ? 0 : CustomAppBar.toolbarHeight,
          ),
          child: _AppBarWrapper(
            onCloseRequested: () {
              unawaited(_requestShutdown(reason: 'titlebar close'));
            },
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            NeuralBackground(
              child: SafeArea(
                bottom: false,
                child: onLiveTab
                    ? LiveTabShell(
                        immersive: immersive,
                        playerPanelKey: _playerPanelKey,
                        activeSidebarIndex: activeIndex,
                        debugModeEnabled: debugModeEnabled,
                        sidebarExpanded: _sidebarExpanded,
                        onSidebarTap: (index) =>
                            ref
                                    .read(activeSidebarIndexProvider.notifier)
                                    .state =
                                index,
                        onSidebarToggle: _toggleSidebarExpanded,
                        headerTitle: shellHeaderTitle(
                          activeIndex,
                          debugModeEnabled: debugModeEnabled,
                        ),
                        headerSubtitle: shellHeaderSubtitle(
                          activeIndex,
                          debugModeEnabled: debugModeEnabled,
                        ),
                        headerExtras: null,
                        onToggleFullscreen: _toggleFullscreen,
                      )
                    : StandardAppShell(
                        activeIndex: activeIndex,
                        debugModeEnabled: debugModeEnabled,
                        sidebarExpanded: _sidebarExpanded,
                        onSidebarToggle: _toggleSidebarExpanded,
                        onSidebarTap: (index) =>
                            ref
                                    .read(activeSidebarIndexProvider.notifier)
                                    .state =
                                index,
                      ),
              ),
            ),
            const VodPlaybackVideoOverlay(),
          ],
        ),
      ),
    );
  }

  @override
  void onWindowClose() {
    unawaited(_requestShutdown(reason: 'window close'));
  }
}

/// Isolates the custom title bar from broad [MainLayoutScreen] rebuilds.
/// It only watches [immersiveLayoutProvider]; the close callback is supplied
/// by [MainLayoutScreen] so the existing shutdown path is preserved.
class _AppBarWrapper extends ConsumerWidget {
  const _AppBarWrapper({required this.onCloseRequested});

  final VoidCallback onCloseRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final immersive = ref.watch(immersiveLayoutProvider);

    return IgnorePointer(
      ignoring: immersive,
      child: AnimatedOpacity(
        duration: LiveTabShell.layoutTransitionDuration,
        opacity: immersive ? 0 : 1,
        child: CustomAppBar(
          onCloseRequested: onCloseRequested,
          search: const GlobalSearchField(),
          searchHeight: GlobalSearchField.fieldHeight,
        ),
      ),
    );
  }
}
