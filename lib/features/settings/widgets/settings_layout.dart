import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/services/settings_layout_geometry.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_section_navigation.dart';

export 'package:m3uxtream_player/features/settings/widgets/settings_section_navigation.dart'
    show SettingsSectionDescriptor, SettingsSectionId;

/// Presents Settings as a responsive, section-addressable scrolling view.
class SettingsLayout extends StatefulWidget {
  const SettingsLayout({required this.sections, super.key});

  final List<SettingsSectionDescriptor> sections;

  @override
  State<SettingsLayout> createState() => _SettingsLayoutState();
}

class _SettingsLayoutState extends State<SettingsLayout> {
  final _scrollController = ScrollController();
  final Map<SettingsSectionId, GlobalKey> _sectionKeys = {};
  late SettingsSectionId _selectedSection;
  bool _sectionSyncScheduled = false;
  SettingsSectionId? _programmaticSelection;

  @override
  void initState() {
    super.initState();
    _syncSectionKeys();
    _selectedSection = widget.sections.first.id;
  }

  @override
  void didUpdateWidget(SettingsLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSectionKeys();
    if (!widget.sections.any((section) => section.id == _selectedSection)) {
      _selectedSection = widget.sections.first.id;
      _programmaticSelection = null;
    }
  }

  void _syncSectionKeys() {
    final ids = widget.sections.map((section) => section.id).toSet();
    _sectionKeys.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _sectionKeys.putIfAbsent(id, GlobalKey.new);
    }
  }

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
        final hasDesktopNavigation =
            widget.sections.length > 1 &&
            SettingsLayoutMetrics.hasSectionNavigation(
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
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('settings-scroll'),
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var index = 0;
                    index < widget.sections.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(height: 16),
                    KeyedSubtree(
                      key: _sectionKeys[widget.sections[index].id],
                      child: widget.sections[index].child,
                    ),
                  ],
                ],
              ),
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

        if (!hasDesktopNavigation) {
          return Column(
            children: [
              if (widget.sections.length > 1)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: SettingsLayoutMetrics.contentMaxWidth,
                    ),
                    child: SettingsSectionNavigation(
                      key: const ValueKey('settings-compact-navigation'),
                      sections: widget.sections,
                      selectedSection: _selectedSection,
                      onSelected: _selectSection,
                      compact: true,
                    ),
                  ),
                ),
              Expanded(child: boundedContent),
            ],
          );
        }

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
                        child: SettingsSectionNavigation(
                          sections: widget.sections,
                          selectedSection: _selectedSection,
                          onSelected: _selectSection,
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
      if (_programmaticSelection == null) _scheduleSectionSync();
    }
    return false;
  }

  void _selectSection(SettingsSectionId section) {
    final key = _sectionKeys[section];
    if (key == null) return;
    _programmaticSelection = section;
    if (_selectedSection != section && mounted) {
      setState(() => _selectedSection = section);
    }
    _scrollTo(key, section);
  }

  void _scrollTo(GlobalKey key, SettingsSectionId section) {
    final targetContext = key.currentContext;
    if (targetContext == null) {
      if (_programmaticSelection == section) _programmaticSelection = null;
      return;
    }

    Scrollable.ensureVisible(
      targetContext,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    ).whenComplete(() {
      if (mounted && _programmaticSelection == section) {
        _programmaticSelection = null;
        _scheduleSectionSync();
      }
    });
  }

  void _syncSelectedSection() {
    if (!_scrollController.hasClients || widget.sections.isEmpty) return;
    final viewport = _scrollController.position.context.storageContext
        .findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;

    final position = _scrollController.position;
    var visibleSection = widget.sections.first.id;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 1) {
      visibleSection = widget.sections.last.id;
    } else {
      final threshold =
          viewport.localToGlobal(Offset.zero).dy + viewport.size.height * 0.2;
      for (final section in widget.sections) {
        final renderObject = _sectionKeys[section.id]?.currentContext
            ?.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.hasSize &&
            renderObject.localToGlobal(Offset.zero).dy <= threshold) {
          visibleSection = section.id;
        }
      }
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
