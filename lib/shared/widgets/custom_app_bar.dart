import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/constants/app_identity.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_brand_mark.dart';
import 'package:window_manager/window_manager.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double toolbarHeight = 72.0;
  static const double defaultSearchHeight = 56.0;
  static const double _brandWidth = 216.0;
  static const double _windowButtonExtent = 48.0;

  final String title;
  final VoidCallback onCloseRequested;
  final Widget? search;
  final double searchHeight;

  const CustomAppBar({
    super.key,
    required this.onCloseRequested,
    this.title = AppIdentity.displayName,
    this.search,
    this.searchHeight = defaultSearchHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Only wrap window movements in DragToMoveArea when running on a real desktop platform
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    final colors = Theme.of(context).colorScheme;
    final titleContent = Row(
      children: [
        const AppBrandMark(key: ValueKey('window-bar-brand-mark'), size: 40),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );

    final titleAreaContent = SizedBox(
      width: _brandWidth,
      height: toolbarHeight,
      child: Align(alignment: Alignment.centerLeft, child: titleContent),
    );

    final titleArea = isDesktop
        ? DragToMoveArea(child: titleAreaContent)
        : titleAreaContent;

    final trailingControls = isDesktop
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWindowButton(
                icon: Icons.remove_rounded,
                tooltip: 'Minimieren',
                onPressed: () => windowManager.minimize(),
              ),
              _buildWindowButton(
                icon: Icons.crop_square_rounded,
                tooltip: 'Maximieren / Wiederherstellen',
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
              ),
              _buildWindowButton(
                icon: Icons.close_rounded,
                tooltip: 'Schließen',
                isClose: true,
                onPressed: onCloseRequested,
              ),
            ],
          )
        : const SizedBox.shrink();

    return Material(
      color: colors.surfaceContainerLow,
      elevation: AppElevation.level1,
      shadowColor: colors.shadow,
      child: SizedBox(
        height: preferredSize.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const sideCorridor = _brandWidth + 16;
              final centeredSearchWidth =
                  (constraints.maxWidth - sideCorridor * 2)
                      .clamp(0.0, 520.0)
                      .toDouble();

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (isDesktop) DragToMoveArea(child: const SizedBox.expand()),
                  Align(alignment: Alignment.centerLeft, child: titleArea),
                  if (search != null)
                    Center(
                      child: SizedBox(
                        width: centeredSearchWidth,
                        height: searchHeight,
                        child: search,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: trailingControls,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isClose = false,
  }) {
    return HoverWindowButton(
      icon: icon,
      tooltip: tooltip,
      isClose: isClose,
      onPressed: onPressed,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);
}

class HoverWindowButton extends StatelessWidget {
  final IconData icon;
  final bool isClose;
  final String tooltip;
  final VoidCallback onPressed;

  const HoverWindowButton({
    super.key,
    required this.icon,
    required this.isClose,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      style:
          IconButton.styleFrom(
            fixedSize: const Size.square(CustomAppBar._windowButtonExtent),
            minimumSize: const Size.square(CustomAppBar._windowButtonExtent),
            padding: EdgeInsets.zero,
            foregroundColor: colors.onSurfaceVariant,
            shape: const CircleBorder(),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return isClose
                    ? colors.errorContainer.withValues(alpha: 0.72)
                    : colors.onSurface.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return isClose
                    ? colors.errorContainer.withValues(alpha: 0.52)
                    : colors.onSurface.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return colors.primary.withValues(alpha: 0.16);
              }
              return null;
            }),
          ),
    );
  }
}
