import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';

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
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final motion = AppMotion.of(context);
    final style =
        IconButton.styleFrom(
          fixedSize: Size.square(size),
          minimumSize: Size.square(size),
          maximumSize: Size.square(size),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: emphasized
              ? colors.primary
              : colors.secondaryContainer,
          foregroundColor: emphasized
              ? colors.onPrimary
              : colors.onSecondaryContainer,
        ).copyWith(
          animationDuration: motion.state,
          shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
            final active =
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed);
            final radius = active
                ? (emphasized ? shapes.large : shapes.medium)
                : shapes.full;
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            );
          }),
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
