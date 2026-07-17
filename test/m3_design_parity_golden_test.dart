@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_test;
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/favorites/widgets/favorite_channel_list.dart';
import 'package:m3uxtream_player/features/channels/widgets/live_category_sidebar.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_status_pill.dart';
import 'package:m3uxtream_player/shared/widgets/m3_tab_shelf.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';
import 'package:m3uxtream_player/shared/widgets/status_snack_bar.dart';

const _navigationBoundaryKey = ValueKey('m3-navigation-boundary');
const _catalogBoundaryKey = ValueKey('m3-catalog-boundary');
const _settingsBoundaryKey = ValueKey('m3-settings-boundary');
const _overlayBoundaryKey = ValueKey('m3-overlay-boundary');
const _overlayHostKey = ValueKey('m3-overlay-host');
const _d10RealConsumersBoundaryKey = ValueKey('d10-real-consumers-boundary');

const _d10FavoriteChannel = Channel(
  id: 301,
  playlistId: 1,
  name: 'Aurora Documentary',
  groupName: 'Documentary',
  streamUrl: 'https://example.invalid/aurora.m3u8',
  isFavorite: true,
  isWatchLater: false,
  channelType: 'live',
);

class _InterTestAssetManifest implements AssetManifest {
  static const assets = <String>[
    'test_fonts/Inter-Regular.ttf',
    'test_fonts/Inter-ExtraBold.ttf',
  ];

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;

  @override
  List<String> listAssets() => assets;
}

String _flutterRoot() {
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null && configuredRoot.isNotEmpty) {
    return configuredRoot;
  }

  var directory = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 4; level++) {
    directory = directory.parent;
  }
  return directory.path;
}

Widget _themedApp({required Widget home}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.darkTheme,
  home: home,
);

Widget _leadingIcon(BuildContext context, IconData icon) {
  final colors = Theme.of(context).colorScheme;
  return CircleAvatar(
    radius: 22,
    backgroundColor: colors.primaryContainer,
    foregroundColor: colors.onPrimaryContainer,
    child: Icon(icon, size: 20),
  );
}

Widget _navigationAndMediaScene() => _themedApp(
  home: Scaffold(
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final status =
            Theme.of(context).extension<AppStatusColors>() ??
            AppStatusColors.dark;
        return RepaintBoundary(
          key: _navigationBoundaryKey,
          child: SizedBox(
            width: 900,
            height: 780,
            child: ColoredBox(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 224,
                      child: AppSurface(
                        level: AppSurfaceLevel.high,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Text(
                                'M3 navigation',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            M3NavigationSection(
                              title: 'Workspace',
                              children: [
                                M3NavigationItem(
                                  label: 'Live TV',
                                  icon: Icons.live_tv_rounded,
                                  selected: true,
                                  onPressed: _noop,
                                ),
                                M3NavigationItem(
                                  label: 'Mediathek',
                                  icon: Icons.video_library_rounded,
                                  onPressed: _noop,
                                ),
                                M3NavigationItem(
                                  label: 'Favorites',
                                  icon: Icons.favorite_rounded,
                                  onPressed: _noop,
                                ),
                                M3NavigationItem(
                                  label: 'Unavailable',
                                  icon: Icons.cloud_off_rounded,
                                  enabled: false,
                                  onPressed: _noop,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Center(
                              child: M3NavigationItem(
                                label: 'Settings',
                                icon: Icons.settings_rounded,
                                expanded: false,
                                width: 56,
                                onPressed: _noop,
                                tooltip: 'Settings',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Channels & favorites',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Shared media-list states',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 18),
                          AppSurface(
                            level: AppSurfaceLevel.low,
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                M3MediaListItem(
                                  title: 'Aurora News',
                                  subtitle: Text(
                                    'Live now',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  metadata: Text(
                                    'HD  ·  News',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  leading: _leadingIcon(
                                    context,
                                    Icons.tv_rounded,
                                  ),
                                  badge: M3StatusPill(
                                    label: 'LIVE',
                                    accent: status.live,
                                    foreground: status.onLiveContainer,
                                  ),
                                  trailing: IconButton(
                                    onPressed: _noop,
                                    tooltip: 'Favorite',
                                    icon: const Icon(
                                      Icons.favorite_border_rounded,
                                    ),
                                  ),
                                  onActivate: _noop,
                                ),
                                M3MediaListItem(
                                  title: 'Selected Cinema',
                                  subtitle: Text(
                                    'Selected item',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onPrimaryContainer,
                                        ),
                                  ),
                                  leading: _leadingIcon(
                                    context,
                                    Icons.movie_rounded,
                                  ),
                                  selected: true,
                                  compact: true,
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onActivate: _noop,
                                ),
                                M3MediaListItem(
                                  title: 'Offline channel',
                                  subtitle: Text(
                                    'Unavailable',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  leading: _leadingIcon(
                                    context,
                                    Icons
                                        .signal_wifi_statusbar_connected_no_internet_4_rounded,
                                  ),
                                  enabled: false,
                                  onActivate: _noop,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              M3StatusPill(
                                label: 'Synced',
                                accent: status.success,
                                foreground: status.onSuccessContainer,
                              ),
                              const SizedBox(width: 8),
                              M3StatusPill(
                                label: '3 favorites',
                                accent: colors.secondary,
                              ),
                            ],
                          ),
                        ],
                      ),
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
);

Widget _catalogScene() => _themedApp(
  home: DefaultTabController(
    length: 3,
    child: Scaffold(
      body: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          final status =
              Theme.of(context).extension<AppStatusColors>() ??
              AppStatusColors.dark;
          return RepaintBoundary(
            key: _catalogBoundaryKey,
            child: SizedBox(
              width: 900,
              height: 720,
              child: ColoredBox(
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mediathek',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Movies, series and watch later',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _noop,
                            icon: const Icon(Icons.filter_list_rounded),
                            label: const Text('Filter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const M3TabShelf(
                        child: TabBar(
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'Movies'),
                            Tab(text: 'Series'),
                            Tab(text: 'Watch later'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: AppSurface(
                          level: AppSurfaceLevel.low,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _catalogCard(
                                  context,
                                  title: 'The Silent Horizon',
                                  subtitle: '2024  ·  2h 04m',
                                  accent: colors.primary,
                                  icon: Icons.movie_rounded,
                                  badge: 'HD',
                                  selected: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _catalogCard(
                                  context,
                                  title: 'Selected Story',
                                  subtitle: 'Season 2  ·  Episode 4',
                                  accent: colors.secondary,
                                  icon: Icons.local_movies_rounded,
                                  badge: 'NEW',
                                  selected: true,
                                  progress: 0.58,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _catalogCard(
                                  context,
                                  title: 'Saved for later',
                                  subtitle: 'Drama  ·  1h 46m',
                                  accent: status.warning,
                                  icon: Icons.bookmark_rounded,
                                  badge: 'LATER',
                                  selected: false,
                                ),
                              ),
                            ],
                          ),
                        ),
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
  ),
);

Widget _catalogCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Color accent,
  required IconData icon,
  required String badge,
  required bool selected,
  double? progress,
}) {
  final colors = Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MediaPosterFrame(
        semanticLabel: title,
        isSelected: selected,
        onActivate: _noop,
        poster: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 52,
                  color: accent.withValues(alpha: 0.82),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: M3StatusPill(
                  label: badge,
                  accent: accent,
                  foreground: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      MediaMetadataRow(
        title: title,
        subtitle: subtitle,
        badges: [
          MediaMetadataBadge(
            label: selected ? 'Selected' : 'Browse',
            icon: selected ? Icons.check_rounded : Icons.play_arrow_rounded,
          ),
        ],
      ),
      if (progress != null) ...[
        const SizedBox(height: 10),
        LinearProgressIndicator(value: progress),
      ],
    ],
  );
}

Widget _settingsScene() => _themedApp(
  home: DefaultTabController(
    length: 2,
    child: Scaffold(
      body: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          final status =
              Theme.of(context).extension<AppStatusColors>() ??
              AppStatusColors.dark;
          return RepaintBoundary(
            key: _settingsBoundaryKey,
            child: SizedBox(
              width: 900,
              height: 640,
              child: ColoredBox(
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      const TabBar(
                        isScrollable: true,
                        tabs: [
                          Tab(text: 'General'),
                          Tab(text: 'Playback'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppSurface(
                                level: AppSurfaceLevel.low,
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Playlist connection',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 18),
                                    TextField(
                                      decoration: const InputDecoration(
                                        labelText: 'Playlist name',
                                        hintText: 'Home playlist',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        M3DropdownField<String>(
                                          value: 'Automatic',
                                          width: 180,
                                          entries: const [
                                            DropdownMenuEntry(
                                              value: 'Automatic',
                                              label: 'Automatic',
                                            ),
                                            DropdownMenuEntry(
                                              value: 'Manual',
                                              label: 'Manual',
                                            ),
                                          ],
                                          onSelected: (_) {},
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: SegmentedButton<String>(
                                            segments: const [
                                              ButtonSegment(
                                                value: 'm3u',
                                                label: Text('M3U'),
                                              ),
                                              ButtonSegment(
                                                value: 'xtream',
                                                label: Text('Xtream'),
                                              ),
                                            ],
                                            selected: const {'m3u'},
                                            showSelectedIcon: false,
                                            onSelectionChanged: (_) {},
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 270,
                              child: AppSurface(
                                level: AppSurfaceLevel.high,
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Appearance',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Use expressive controls'),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Animations'),
                                        Switch(
                                          value: true,
                                          onChanged: _noopBool,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    M3StatusPill(
                                      label: 'Saved',
                                      accent: status.success,
                                      foreground: status.onSuccessContainer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
  ),
);

Widget _overlayHost() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.darkTheme,
  builder: (context, child) =>
      RepaintBoundary(key: _overlayBoundaryKey, child: child!),
  home: Scaffold(
    key: _overlayHostKey,
    body: const Center(child: Text('Overlay host')),
  ),
);

Widget _d10RealConsumersScene() => _themedApp(
  home: Scaffold(
    body: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return RepaintBoundary(
          key: _d10RealConsumersBoundaryKey,
          child: SizedBox(
            width: 900,
            height: 640,
            child: ColoredBox(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProviderScope(
                      overrides: [
                        channelGroupsProvider.overrideWithValue(const [
                          'News',
                          'Documentary',
                          'Sports',
                        ]),
                        selectedGroupFilterProvider.overrideWith(
                          (ref) => 'Documentary',
                        ),
                        pinnedGroupsProvider.overrideWith(
                          _D10PinnedGroupsNotifier.new,
                        ),
                      ],
                      child: const LiveCategorySidebar(width: 240),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppSurface(
                        level: AppSurfaceLevel.low,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Favorite channels',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: FavoriteChannelList(
                                channels: const [_d10FavoriteChannel],
                                selectedChannelId: _d10FavoriteChannel.id,
                                onActivate: _noopChannel,
                                onToggleFavorite: _noopChannel,
                              ),
                            ),
                          ],
                        ),
                      ),
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
);

void _noop() {}

void _noopBool(bool _) {}

void _noopChannel(Channel _) {}

class _D10PinnedGroupsNotifier extends PinnedGroupsNotifier {
  @override
  Future<List<String>> build() async => const ['Sports'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontDirectory = Directory(
      '${_flutterRoot()}${Platform.pathSeparator}bin${Platform.pathSeparator}'
      'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
      'material_fonts',
    );
    final regularBytes = await File(
      '${fontDirectory.path}${Platform.pathSeparator}roboto-regular.ttf',
    ).readAsBytes();
    final extraBoldBytes = await File(
      '${fontDirectory.path}${Platform.pathSeparator}roboto-bold.ttf',
    ).readAsBytes();
    final materialIconsBytes = await File(
      '${fontDirectory.path}${Platform.pathSeparator}materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(materialIconsBytes)))).load();

    google_fonts_test.assetManifest = _InterTestAssetManifest();
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          if (message == null) return null;
          final key = utf8.decode(
            message.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          final normalizedKey = key.toLowerCase();
          final bytes = key.endsWith('Inter-ExtraBold.ttf')
              ? extraBoldBytes
              : key.endsWith('Inter-Regular.ttf')
              ? regularBytes
              : normalizedKey.endsWith('materialicons-regular.otf')
              ? materialIconsBytes
              : null;
          return bytes == null ? null : ByteData.sublistView(bytes);
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    google_fonts_test.assetManifest = null;
    google_fonts_test.clearCache();
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  testWidgets(
    'M3 navigation, media and status states match the visual contract',
    (tester) async {
      await tester.pumpWidget(_navigationAndMediaScene());
      await GoogleFonts.pendingFonts();
      await tester.pump();
      await expectLater(
        find.byKey(_navigationBoundaryKey),
        matchesGoldenFile('goldens/m3_design_parity_navigation_lists.png'),
      );
    },
  );

  testWidgets('M3 catalogue cards and media tabs match the visual contract', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_catalogScene());
    await GoogleFonts.pendingFonts();
    await tester.pump();
    await expectLater(
      find.byKey(_catalogBoundaryKey),
      matchesGoldenFile('goldens/m3_design_parity_catalog.png'),
    );
  });

  testWidgets('M3 settings controls match the visual contract', (tester) async {
    await tester.pumpWidget(_settingsScene());
    await GoogleFonts.pendingFonts();
    await tester.pump();
    await expectLater(
      find.byKey(_settingsBoundaryKey),
      matchesGoldenFile('goldens/m3_design_parity_settings.png'),
    );
  });

  testWidgets(
    'D10 real category and favorite consumers match the geometry contract',
    (tester) async {
      await tester.pumpWidget(_d10RealConsumersScene());
      await GoogleFonts.pendingFonts();
      await tester.pump();
      await expectLater(
        find.byKey(_d10RealConsumersBoundaryKey),
        matchesGoldenFile('goldens/d10_design_parity_real_consumers.png'),
      );
    },
  );

  testWidgets('M3 dialog matches the visual contract', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_overlayHost());
    await tester.pump();
    await GoogleFonts.pendingFonts();
    await tester.pump();
    final context = tester.element(find.byKey(_overlayHostKey));
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove playlist?'),
        content: const Text(
          'This action removes the local playlist configuration.',
        ),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Cancel')),
          FilledButton(onPressed: () {}, child: const Text('Remove')),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_overlayBoundaryKey),
      matchesGoldenFile('goldens/m3_design_parity_dialog.png'),
    );
  });

  testWidgets('M3 status snackbar matches the visual contract', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_overlayHost());
    await tester.pump();
    await GoogleFonts.pendingFonts();
    await tester.pump();
    final context = tester.element(find.byKey(_overlayHostKey));
    ScaffoldMessenger.of(context).showSnackBar(
      appStatusSnackBar(
        context,
        message: 'Playlist saved',
        tone: AppStatusSnackBarTone.success,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_overlayBoundaryKey),
      matchesGoldenFile('goldens/m3_design_parity_snackbar.png'),
    );
  });
}
