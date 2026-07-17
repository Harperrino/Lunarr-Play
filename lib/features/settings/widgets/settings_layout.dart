import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/services/settings_layout_geometry.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_section_navigation.dart';

/// Presents Settings as one bounded, scrolling column at every viewport size.
class SettingsLayout extends StatefulWidget {
  const SettingsLayout({
    required this.topSection,
    required this.playlistForm,
    required this.playlistSection,
    super.key,
  });

  final Widget topSection;
  final Widget playlistForm;
  final Widget playlistSection;

  @override
  State<SettingsLayout> createState() => _SettingsLayoutState();
}

class _SettingsLayoutState extends State<SettingsLayout> {
  final _scrollController = ScrollController();
  final _generalKey = GlobalKey();
  final _playlistFormKey = GlobalKey();
  final _playlistListKey = GlobalKey();
  SettingsSection _selectedSection = SettingsSection.general;
  bool _sectionSyncScheduled = false;
  SettingsSection? _programmaticSelection;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaleFactor = MediaQuery.textScalerOf(context).scale(1);
        final usesFullContentWidth = SettingsLayoutMetrics.usesFullContentWidth(
          textScaleFactor,
        );
        final hasSectionNavigation = SettingsLayoutMetrics.hasSectionNavigation(
          availableWidth: constraints.maxWidth,
          textScaleFactor: textScaleFactor,
        );
        final narrowWidth =
            constraints.maxWidth < SettingsLayoutMetrics.compactWidth;
        final shortHeight = constraints.maxHeight < 640;
        final horizontalPadding = narrowWidth ? 12.0 : 24.0;
        final verticalPadding = shortHeight ? 12.0 : 24.0;

        final content = NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Scrollbar(
            controller: _scrollController,
            child: ListView(
              key: const ValueKey('settings-scroll'),
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              children: [
                KeyedSubtree(key: _generalKey, child: widget.topSection),
                const SizedBox(height: 16),
                KeyedSubtree(key: _playlistFormKey, child: widget.playlistForm),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: _playlistListKey,
                  child: widget.playlistSection,
                ),
              ],
            ),
          ),
        );

        final boundedContent = Center(
          child: ConstrainedBox(
            key: const ValueKey('settings-content'),
            constraints: BoxConstraints(
              maxWidth: usesFullContentWidth
                  ? double.infinity
                  : SettingsLayoutMetrics.contentMaxWidth,
            ),
            child: content,
          ),
        );

        if (!hasSectionNavigation) return boundedContent;

        return Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            key: const ValueKey('settings-wide-group'),
            constraints: const BoxConstraints(
              maxWidth: SettingsLayoutMetrics.desktopGroupMaxWidth,
            ),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: SettingsLayoutMetrics.sectionNavigationWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: verticalPadding),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(
                            width: SettingsLayoutMetrics.sectionNavigationWidth,
                          ),
                          child: SettingsSectionNavigation(
                            selectedSection: _selectedSection,
                            onGeneralSelected: () => _selectSection(
                              SettingsSection.general,
                              _generalKey,
                            ),
                            onPlaylistSetupSelected: () => _selectSection(
                              SettingsSection.playlistSetup,
                              _playlistFormKey,
                            ),
                            onSavedPlaylistsSelected: () => _selectSection(
                              SettingsSection.savedPlaylists,
                              _playlistListKey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: SettingsLayoutMetrics.navigationContentGap,
                  ),
                  Expanded(child: boundedContent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      if (_programmaticSelection != null) {
        return false;
      }
      _scheduleSectionSync();
    }
    return false;
  }

  void _selectSection(SettingsSection section, GlobalKey key) {
    _programmaticSelection = section;
    if (_selectedSection != section && mounted) {
      setState(() => _selectedSection = section);
    }
    _scrollTo(key, section);
  }

  void _scrollTo(GlobalKey key, SettingsSection section) {
    final targetContext = key.currentContext;
    if (targetContext == null) {
      if (_programmaticSelection == section) _programmaticSelection = null;
      return;
    }

    final scrollFuture = Scrollable.ensureVisible(
      targetContext,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    scrollFuture.whenComplete(() {
      if (mounted && _programmaticSelection == section) {
        _programmaticSelection = null;
      }
    });
  }

  void _syncSelectedSection() {
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.context.storageContext
        .findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;

    var visibleSection = SettingsSection.general;
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 1) {
      visibleSection = SettingsSection.savedPlaylists;
    }
    final threshold =
        viewport.localToGlobal(Offset.zero).dy + viewport.size.height * 0.2;
    double? savedPlaylistsTop;
    for (final entry in [
      (SettingsSection.general, _generalKey),
      (SettingsSection.playlistSetup, _playlistFormKey),
      (SettingsSection.savedPlaylists, _playlistListKey),
    ]) {
      final renderObject = entry.$2.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final top = renderObject.localToGlobal(Offset.zero).dy;
        if (entry.$1 == SettingsSection.savedPlaylists) {
          savedPlaylistsTop = top;
        }
        if (top <= threshold &&
            position.pixels < position.maxScrollExtent - 1) {
          visibleSection = entry.$1;
        }
      }
    }
    if (savedPlaylistsTop != null &&
        position.pixels > 0 &&
        savedPlaylistsTop <=
            viewport.localToGlobal(Offset.zero).dy + viewport.size.height) {
      visibleSection = SettingsSection.savedPlaylists;
    }
    if (visibleSection != _selectedSection && mounted) {
      setState(() => _selectedSection = visibleSection);
    }
  }

  void _scheduleSectionSync() {
    if (_sectionSyncScheduled) return;
    _sectionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sectionSyncScheduled = false;
      if (mounted) _syncSelectedSection();
    });
  }
}
