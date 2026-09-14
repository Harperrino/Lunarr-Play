import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/shared/widgets/m3_transport_icon_button.dart';

class JellyfinPlayerTrackMenuEntry {
  const JellyfinPlayerTrackMenuEntry({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;
}

/// Provider-free Material 3 menu trigger used by Jellyfin's player chrome.
///
/// The transport button is the real interactive anchor. This avoids wrapping
/// a disabled icon button in another gesture target, which both looked disabled
/// and was unreliable for pointer and keyboard input on Windows.
class JellyfinPlayerTrackMenuButton extends StatelessWidget {
  const JellyfinPlayerTrackMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.size,
    required this.iconSize,
    required this.selectedValue,
    required this.entries,
    required this.onSelected,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final double size;
  final double iconSize;
  final int selectedValue;
  final List<JellyfinPlayerTrackMenuEntry> entries;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: false,
      menuChildren: [
        for (final entry in entries)
          Semantics(
            selected: entry.value == selectedValue,
            child: MenuItemButton(
              leadingIcon: Icon(
                entry.value == selectedValue
                    ? Icons.check_rounded
                    : Icons.circle_outlined,
                size: 18,
              ),
              onPressed: enabled ? () => onSelected(entry.value) : null,
              child: Text(entry.label),
            ),
          ),
      ],
      builder: (context, controller, _) => M3TransportIconButton(
        icon: icon,
        tooltip: tooltip,
        size: size,
        iconSize: iconSize,
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
    );
  }
}
