import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/xtream/providers/media_library_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_screen.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_screen.dart';
import 'package:m3uxtream_player/features/xtream/widgets/watch_later_screen.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:m3uxtream_player/shared/widgets/m3_tab_shelf.dart';

/// Shared catalogue hub for movies, series and the manual Watch Later list.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(mediaLibraryTabProvider).clamp(0, 2).toInt();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    )..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(mediaLibraryTabProvider, (_, next) {
      final target = next.clamp(0, 2).toInt();
      if (_tabController.index != target && !_tabController.indexIsChanging) {
        _tabController.animateTo(target);
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            M3TabShelf(
              child: TabBar(
                controller: _tabController,
                isScrollable: compact,
                tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
                tabs: [
                  Tab(
                    icon: M3TabIconPair(
                      controller: _tabController,
                      index: 0,
                      icon: Icons.movie_creation_outlined,
                      selectedIcon: Icons.movie_rounded,
                    ),
                    text: 'Filme',
                  ),
                  Tab(
                    icon: M3TabIconPair(
                      controller: _tabController,
                      index: 1,
                      icon: Icons.live_tv_outlined,
                      selectedIcon: Icons.live_tv_rounded,
                    ),
                    text: 'Serien',
                  ),
                  Tab(
                    icon: M3TabIconPair(
                      controller: _tabController,
                      index: 2,
                      icon: Icons.bookmark_border_rounded,
                      selectedIcon: Icons.bookmark_rounded,
                    ),
                    text: 'Später ansehen',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  VodScreen(),
                  SeriesScreen(),
                  WatchLaterScreen(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (ref.read(mediaLibraryTabProvider) != _tabController.index) {
      ref.read(mediaLibraryTabProvider.notifier).state = _tabController.index;
    }
  }
}
