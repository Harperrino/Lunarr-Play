import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_scrollbar.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';

/// Feature-local library navigation for Jellyfin browse surfaces.
///
/// It intentionally depends only on Jellyfin's library model and shared M3
/// presentation primitives. It does not know about Live TV, Xtream or Drift.
class JellyfinLibrarySidebar extends StatefulWidget {
  const JellyfinLibrarySidebar({
    super.key,
    required this.libraries,
    required this.selectedLibraryId,
    required this.onOverviewSelected,
    required this.onLibrarySelected,
  });

  final List<JellyfinLibrary> libraries;
  final String? selectedLibraryId;
  final VoidCallback onOverviewSelected;
  final ValueChanged<JellyfinLibrary> onLibrarySelected;

  @override
  State<JellyfinLibrarySidebar> createState() => _JellyfinLibrarySidebarState();
}

class _JellyfinLibrarySidebarState extends State<JellyfinLibrarySidebar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      child: AppSurface(
        level: AppSurfaceLevel.low,
        elevation: AppElevation.level1,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AppScrollbar(
                controller: _scrollController,
                axis: Axis.vertical,
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _navigationItem(
                      key: const ValueKey('jellyfin-library-overview'),
                      label: context.l10n.jellyfinOverview,
                      icon: Icons.home_rounded,
                      selected: widget.selectedLibraryId == null,
                      onPressed: widget.onOverviewSelected,
                    ),
                    for (final library in widget.libraries)
                      _navigationItem(
                        key: ValueKey('jellyfin-library-${library.id}'),
                        label: library.name,
                        icon: jellyfinLibraryIcon(library),
                        selected: widget.selectedLibraryId == library.id,
                        onPressed: () => widget.onLibrarySelected(library),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationItem({
    required Key key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return M3NavigationItem(
      key: key,
      label: label,
      icon: icon,
      selected: selected,
      onPressed: onPressed,
      visualRole: M3NavigationItemVisualRole.categoryNavigation,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      focusOutlineKey: const ValueKey('jellyfin-library-sidebar-focus-ring'),
    );
  }
}

/// Compact M3 menu used when the available width cannot fit the sidebar.
class JellyfinLibraryPicker extends StatelessWidget {
  const JellyfinLibraryPicker({
    super.key,
    required this.libraries,
    required this.selectedLibraryId,
    required this.onOverviewSelected,
    required this.onLibrarySelected,
  });

  final List<JellyfinLibrary> libraries;
  final String? selectedLibraryId;
  final VoidCallback onOverviewSelected;
  final ValueChanged<JellyfinLibrary> onLibrarySelected;

  JellyfinLibrary? get _selectedLibrary {
    for (final library in libraries) {
      if (library.id == selectedLibraryId) return library;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedLibrary = _selectedLibrary;
    final selectedLabel =
        selectedLibrary?.name ?? context.l10n.jellyfinOverview;
    final selectedIcon = selectedLibrary == null
        ? Icons.home_rounded
        : jellyfinLibraryIcon(selectedLibrary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MenuAnchor(
        menuChildren: [
          MenuItemButton(
            key: const ValueKey('jellyfin-library-menu-overview'),
            leadingIcon: const Icon(Icons.home_rounded),
            onPressed: onOverviewSelected,
            child: Text(context.l10n.jellyfinOverview),
          ),
          for (final library in libraries)
            MenuItemButton(
              key: ValueKey('jellyfin-library-menu-${library.id}'),
              leadingIcon: Icon(jellyfinLibraryIcon(library)),
              onPressed: () => onLibrarySelected(library),
              child: Text(library.name),
            ),
        ],
        builder: (context, controller, _) => SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const ValueKey('jellyfin-library-picker-button'),
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(selectedIcon),
            label: Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }
}

IconData jellyfinLibraryIcon(JellyfinLibrary library) {
  return switch (library.collectionType) {
    'movies' => Icons.movie_rounded,
    'tvshows' => Icons.tv_rounded,
    _ => Icons.video_library_rounded,
  };
}
