import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/providers/app_shell_state_providers.dart';
import 'package:m3uxtream_player/shared/providers/shell_tab_visibility_providers.dart';
import 'package:m3uxtream_player/app/providers/app_shutdown_providers.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/app/bootstrap/desktop_window_bootstrap.dart';
import 'package:m3uxtream_player/app/shell/shell_tab_labels.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';
import 'package:m3uxtream_player/app/shell/standard_app_shell.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/channel_navigation.dart';
import 'package:m3uxtream_player/core/services/database_health_controller.dart';
import 'package:m3uxtream_player/core/services/fullscreen_toggle.dart';
import 'package:m3uxtream_player/shared/shortcuts/global_shortcuts.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/core/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_command_providers.dart';
import 'package:m3uxtream_player/features/player/services/player_ui_command_runner.dart';
import 'package:m3uxtream_player/features/player/vod/vod_playback_video_overlay.dart';
import 'package:m3uxtream_player/app/widgets/live_tab_shell.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/app/widgets/top_bar_playlist_menu.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_connection_menu.dart';
import 'package:m3uxtream_player/app/widgets/global_search_field.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/media_library_providers.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_navigation_provider.dart';
import 'package:m3uxtream_player/app/shell/app_ambient_layer.dart';
import 'package:m3uxtream_player/app/services/app_maintenance_coordinator.dart';
import 'package:m3uxtream_player/app/providers/tab_transition_probe_provider.dart';
import 'package:m3uxtream_player/shared/widgets/custom_app_bar.dart';
import 'package:window_manager/window_manager.dart';

typedef PlayerShortcutScopePolicy = ({
  bool enabled,
  bool channelNavigationEnabled,
});

@visibleForTesting
PlayerShortcutScopePolicy playerShortcutScopePolicy({
  required bool playerSurfaceVisible,
  required bool seekablePlayback,
}) => (
  enabled: playerSurfaceVisible,
  channelNavigationEnabled: playerSurfaceVisible && !seekablePlayback,
);

/// Root layout: shortcuts, fullscreen, live vs. standard shell, VOD video overlay.
class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen>
    with WindowListener, WidgetsBindingObserver {
  final GlobalKey _playerPanelKey = GlobalKey();
  late final DesktopWindowPlacementController _windowPlacementController;
  bool _fullscreenBusy = false;
  bool _sidebarExpanded = false;
  bool _startupDestinationApplied = false;
  int _navigationGeneration = 0;
  final AppMaintenanceCoordinator _maintenanceCoordinator =
      AppMaintenanceCoordinator();

  @override
  void initState() {
    super.initState();
    _windowPlacementController = DesktopWindowPlacementController();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(isDesktopPlatformProvider)) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_prepareDesktopWindow());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFullscreenState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_applyStartupDestination());
      _maintenanceCoordinator.deferFor(const Duration(milliseconds: 350));
      unawaited(
        _maintenanceCoordinator.schedule(
          _startSearchIndexBootstrap,
          key: 'search-index-bootstrap',
        ),
      );
      unawaited(_scheduleEpgMaintenance());
    });
  }

  Future<void> _applyStartupDestination() async {
    if (_startupDestinationApplied) return;
    final generation = _navigationGeneration;
    final initialIndex = ref.read(activeSidebarIndexProvider);
    try {
      final values = await Future.wait<Object>(<Future<Object>>[
        ref.read(discoveryPreferencesProvider.future),
        ref.read(hiddenShellTabKindsProvider.future),
        ref.read(debugModeProvider.future),
      ]);
      if (!mounted ||
          generation != _navigationGeneration ||
          ref.read(activeSidebarIndexProvider) != initialIndex) {
        return;
      }
      final preferences = values[0] as DiscoveryPreferences;
      final hidden = values[1] as Set<ShellTabKind>;
      final debugEnabled = values[2] as bool;
      final target = shellStartupTabIndex(
        preferHome:
            preferences.startupDestination == AppStartupDestination.home,
        debugModeEnabled: debugEnabled,
        hiddenKinds: hidden,
      );
      ref.read(activeSidebarIndexProvider.notifier).state = target;
    } catch (error, stackTrace) {
      AppLogger.error(
        'MainLayout: Failed to resolve startup destination.',
        error,
        stackTrace,
      );
    } finally {
      _startupDestinationApplied = true;
    }
  }

  void _selectSidebar(int index) {
    _navigationGeneration++;
    _maintenanceCoordinator.deferFor(const Duration(milliseconds: 250));
    ref
        .read(tabTransitionProbeProvider)
        .begin(
          fromIndex: shellNavigationIndexFor(
            ref.read(activeSidebarIndexProvider),
          ),
          toIndex: shellNavigationIndexFor(index),
        );
    ref.read(activeSidebarIndexProvider.notifier).state = index;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (ref.read(isDesktopPlatformProvider)) {
      windowManager.removeListener(this);
    }
    _windowPlacementController.dispose();
    _maintenanceCoordinator.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_scheduleEpgMaintenance());
    }
  }

  Future<void> _scheduleEpgMaintenance() {
    return _maintenanceCoordinator.schedule(
      () => ref.read(epgAutoRefreshCoordinatorProvider).refreshNow(),
      key: 'epg-refresh',
    );
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

  Future<void> _startSearchIndexBootstrap() async {
    try {
      await ref
          .read(searchIndexRepositoryProvider)
          .ensureExistingIndexes(
            betweenPlaylists: _maintenanceCoordinator.waitUntilIdle,
          );
    } catch (e, stackTrace) {
      AppLogger.error(
        'MainLayout: Search index bootstrap failed.',
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
    await _windowPlacementController.flush();
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
      if (previous != next) {
        _maintenanceCoordinator.deferFor(const Duration(milliseconds: 250));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(tabTransitionProbeProvider)
                .markContentMounted(shellNavigationIndexFor(next));
          }
        });
      }
      final navigationIndex = shellNavigationIndexFor(next);
      final previousNavigation = previous == null
          ? null
          : shellNavigationIndexFor(previous);
      if (previousNavigation == shellHomeTabIndex &&
          navigationIndex != shellHomeTabIndex) {
        ref.read(discoverySearchProvider.notifier).clear();
        ref.read(discoveryNavigationProvider.notifier).resetSession();
        ref.invalidate(discoveryHomeProvider);
        ref.invalidate(discoveryCategoryProvider);
        ref.invalidate(discoveryDetailsProvider);
        ref.invalidate(discoveryRequestProvider);
      }
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

    ref.listen<int?>(selectedChannelProvider.select((channel) => channel?.id), (
      previous,
      next,
    ) {
      if (previous != next) {
        _maintenanceCoordinator.deferFor(const Duration(milliseconds: 600));
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

    ref.listen<AsyncValue<Set<ShellTabKind>>>(hiddenShellTabKindsProvider, (
      _,
      next,
    ) {
      final hidden = next.valueOrNull;
      if (hidden == null) return;
      final active = shellNavigationIndexFor(
        ref.read(activeSidebarIndexProvider),
      );
      final debug = ref.read(debugModeProvider).valueOrNull ?? false;
      if (!shellTabVisible(
        active,
        debugModeEnabled: debug,
        hiddenKinds: hidden,
      )) {
        ref.read(activeSidebarIndexProvider.notifier).state =
            shellSettingsTabIndex;
      }
    });

    ref.listen<AsyncValue<List<Playlist>>>(playlistsStreamProvider, (_, _) {
      _syncSelectedPlaylist();
      unawaited(_scheduleEpgMaintenance());
    });
    ref.listen<AsyncValue<Set<int>>>(inactivePlaylistIdsProvider, (_, _) {
      _syncSelectedPlaylist();
      unawaited(_scheduleEpgMaintenance());
    });

    final debugModeEnabled = ref.watch(debugModeProvider).valueOrNull ?? false;
    final hiddenTabKinds =
        ref.watch(hiddenShellTabKindsProvider).valueOrNull ??
        const <ShellTabKind>{};
    final databaseHealth = ref.watch(databaseHealthProvider);
    final windowFullscreen = ref.watch(isFullscreenProvider);
    final immersive = ref.watch(immersiveLayoutProvider);
    final activeIndex = shellNavigationIndexFor(
      ref.watch(activeSidebarIndexProvider),
    );
    final onLiveTab = activeIndex == shellLiveTabIndex;
    final seekablePlayback = ref.watch(
      selectedChannelProvider.select(isSeekableChannel),
    );
    // Player A is mounted only in the Live shell. VOD and series catalogue
    // tabs must leave keyboard input to their controls; starting playback
    // navigates back to this shell before the video surface opens.
    final shortcutPolicy = playerShortcutScopePolicy(
      playerSurfaceVisible: onLiveTab,
      seekablePlayback: seekablePlayback,
    );

    return GlobalShortcutsWrapper(
      enabled: shortcutPolicy.enabled,
      requestFocusTrigger: immersive,
      channelNavigationEnabled: shortcutPolicy.channelNavigationEnabled,
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppAmbientLayer(animationEnabled: !windowFullscreen),
          Scaffold(
            backgroundColor: Colors.transparent,
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
                SafeArea(
                  bottom: false,
                  child: onLiveTab
                      ? LiveTabShell(
                          immersive: immersive,
                          playerPanelKey: _playerPanelKey,
                          activeSidebarIndex: activeIndex,
                          debugModeEnabled: debugModeEnabled,
                          hiddenTabKinds: hiddenTabKinds,
                          sidebarExpanded: _sidebarExpanded,
                          onSidebarTap: _selectSidebar,
                          onSidebarToggle: _toggleSidebarExpanded,
                          headerTitle: shellHeaderTitle(
                            activeIndex,
                            debugModeEnabled: debugModeEnabled,
                            l10n: context.l10n,
                          ),
                          headerSubtitle: shellHeaderSubtitle(
                            activeIndex,
                            debugModeEnabled: debugModeEnabled,
                            l10n: context.l10n,
                          ),
                          headerExtras: null,
                          onToggleFullscreen: _toggleFullscreen,
                        )
                      : StandardAppShell(
                          activeIndex: activeIndex,
                          debugModeEnabled: debugModeEnabled,
                          hiddenTabKinds: hiddenTabKinds,
                          sidebarExpanded: _sidebarExpanded,
                          onSidebarToggle: _toggleSidebarExpanded,
                          onSidebarTap: _selectSidebar,
                        ),
                ),
                const VodPlaybackVideoOverlay(),
                if (databaseHealth.isFatal)
                  const Positioned(
                    left: 16,
                    right: 16,
                    top: 12,
                    child: _DatabaseFatalStatus(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void onWindowClose() {
    unawaited(_requestShutdown(reason: 'window close'));
  }

  @override
  void onWindowResize() {
    _windowPlacementController.onWindowResize(
      immersive: ref.read(isFullscreenProvider),
    );
  }

  @override
  void onWindowResized() {
    _windowPlacementController.onWindowResize(
      immersive: ref.read(isFullscreenProvider),
    );
  }
}

class _DatabaseFatalStatus extends StatelessWidget {
  const _DatabaseFatalStatus();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: context.l10n.databaseFatalSemanticLabel,
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.databaseFatalMessage,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Isolates the custom title bar from broad [MainLayoutScreen] rebuilds.
/// It watches only title-bar state; the close callback preserves the existing
/// shutdown path.
class _AppBarWrapper extends ConsumerWidget {
  const _AppBarWrapper({required this.onCloseRequested});

  final VoidCallback onCloseRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final immersive = ref.watch(immersiveLayoutProvider);
    final activeIndex = shellNavigationIndexFor(
      ref.watch(activeSidebarIndexProvider),
    );

    return IgnorePointer(
      ignoring: immersive,
      child: AnimatedOpacity(
        duration: LiveTabShell.layoutTransitionDuration,
        opacity: immersive ? 0 : 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final jellyfinActive = activeIndex == shellJellyfinTabIndex;
            final homeActive = activeIndex == shellHomeTabIndex;
            final leadingWidth = homeActive
                ? 0.0
                : jellyfinActive
                ? JellyfinConnectionMenu.widthFor(constraints.maxWidth)
                : TopBarPlaylistMenu.widthFor(constraints.maxWidth);
            return CustomAppBar(
              onCloseRequested: onCloseRequested,
              leadingCommand: homeActive
                  ? null
                  : jellyfinActive
                  ? JellyfinConnectionMenu(availableWidth: constraints.maxWidth)
                  : TopBarPlaylistMenu(availableWidth: constraints.maxWidth),
              leadingCommandWidth: leadingWidth,
              search: homeActive ? null : const GlobalSearchField(),
              searchHeight: GlobalSearchField.fieldHeight,
            );
          },
        ),
      ),
    );
  }
}
