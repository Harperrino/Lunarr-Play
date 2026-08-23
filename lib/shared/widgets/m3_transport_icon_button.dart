import 'package:material_ui/material_ui.dart';

/// Canonical circular Material 3 transport action used by every player.
class M3TransportIconButton extends StatelessWidget {
  const M3TransportIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.size,
    required this.iconSize,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = IconButton.styleFrom(
      fixedSize: Size.square(size),
      minimumSize: Size.square(size),
      maximumSize: Size.square(size),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: const CircleBorder(),
      backgroundColor: emphasized ? colors.primary : colors.secondaryContainer,
      foregroundColor: emphasized
          ? colors.onPrimary
          : colors.onSecondaryContainer,
    );

    return emphasized
        ? IconButton.filled(
            tooltip: tooltip,
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: iconSize),
          )
        : IconButton.filledTonal(
            tooltip: tooltip,
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: iconSize),
          );
  }
}
