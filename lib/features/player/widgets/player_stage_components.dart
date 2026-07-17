import 'package:flutter/material.dart';

import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

class PlayerStageLoading extends StatelessWidget {
  const PlayerStageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
  }
}

class PlayerStageError extends StatelessWidget {
  const PlayerStageError({
    super.key,
    required this.message,
    required this.immersive,
  });

  final String message;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = immersive ? Colors.redAccent : colors.onErrorContainer;
    final background = immersive ? Colors.transparent : colors.errorContainer;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: background,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerStageFrame extends StatelessWidget {
  const PlayerStageFrame({
    super.key,
    required this.child,
    required this.immersive,
  });

  final Widget child;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderRadius = immersive
        ? BorderRadius.zero
        : BorderRadius.circular(18);
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        key: const ValueKey<String>('windowed-player-stage'),
        decoration: BoxDecoration(
          color: immersive ? Colors.black : colors.surfaceContainerLowest,
          borderRadius: borderRadius,
        ),
        child: child,
      ),
    );
  }
}

class WindowedPlayerEmptyState extends StatelessWidget {
  const WindowedPlayerEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('windowed-player-empty-state'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceContainerLow, colors.surfaceContainerLowest],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSurface(
                  level: AppSurfaceLevel.low,
                  elevation: AppElevation.level1,
                  surfaceColor: colors.secondaryContainer,
                  width: 64,
                  height: 64,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 32,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select a channel to play',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap a channel in the list or use the arrow keys.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerMessage extends StatelessWidget {
  const PlayerMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.immersive,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final bool immersive;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleColor = immersive
        ? Colors.white.withValues(alpha: 0.7)
        : error
        ? colors.onErrorContainer
        : colors.onSurface;
    final subtitleColor = immersive
        ? Colors.white.withValues(alpha: 0.4)
        : error
        ? colors.onErrorContainer
        : colors.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 36),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subtitleColor, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
