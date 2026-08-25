import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';

enum SettingsSectionId { general, playback, discovery, navigation, appearance }

@immutable
class SettingsSectionDescriptor {
  const SettingsSectionDescriptor({
    required this.id,
    required this.icon,
    required this.label,
    required this.child,
  });

  final SettingsSectionId id;
  final IconData icon;
  final String label;
  final Widget child;
}

/// Provider-free navigation shared by the desktop rail and compact menu.
class SettingsSectionNavigation extends StatelessWidget {
  const SettingsSectionNavigation({
    required this.sections,
    required this.selectedSection,
    required this.onSelected,
    this.compact = false,
    super.key,
  });

  final List<SettingsSectionDescriptor> sections;
  final SettingsSectionId selectedSection;
  final ValueChanged<SettingsSectionId> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      final selected = sections.firstWhere(
        (section) => section.id == selectedSection,
        orElse: () => sections.first,
      );
      return LayoutBuilder(
        builder: (context, constraints) => M3DropdownField<SettingsSectionId>(
          key: ValueKey('settings-section-menu-${selected.id.name}'),
          value: selected.id,
          width: constraints.maxWidth,
          compact: true,
          label: Text(context.l10n.settingsSectionsTitle),
          leadingIcon: Icon(selected.icon),
          entries: [
            for (final section in sections)
              DropdownMenuEntry<SettingsSectionId>(
                value: section.id,
                label: section.label,
                leadingIcon: Icon(section.icon),
              ),
          ],
          onSelected: (value) {
            if (value != null) onSelected(value);
          },
        ),
      );
    }

    return AppSurface(
      level: AppSurfaceLevel.low,
      elevation: AppElevation.level1,
      padding: const EdgeInsets.all(12),
      child: M3NavigationSection(
        title: context.l10n.settingsSectionsTitle,
        padding: EdgeInsets.zero,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final section in sections)
            M3NavigationItem(
              key: ValueKey('settings-section-${section.id.name}'),
              label: section.label,
              icon: section.icon,
              selected: selectedSection == section.id,
              visualRole: M3NavigationItemVisualRole.settingsNavigation,
              onPressed: () => onSelected(section.id),
            ),
        ],
      ),
    );
  }
}
