import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/player_chrome_tokens.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Canonical tonal frame for Xtream and Jellyfin transport controls.
class PlayerChromeSurface extends StatelessWidget {
  const PlayerChromeSurface({
    super.key,
    required this.child,
    this.compact = false,
    this.translucent = false,
  });

  final Widget child;
  final bool compact;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = PlayerChromeTokens.of(context);
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    return AppSurface(
      key: const ValueKey('player-chrome-tonal-surface'),
      level: AppSurfaceLevel.high,
      surfaceColor: translucent
          ? colors.surfaceContainerHigh.withValues(alpha: tokens.scrimOpacity)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          tokens.surfaceRadius.clamp(shapes.large, shapes.extraLarge),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        compact
            ? tokens.compactSurfaceHorizontalPadding
            : tokens.surfaceHorizontalPadding,
        compact
            ? tokens.compactSurfaceVerticalPadding
            : tokens.surfaceVerticalPadding,
        compact
            ? tokens.compactSurfaceHorizontalPadding
            : tokens.surfaceHorizontalPadding,
        compact
            ? tokens.compactSurfaceVerticalPadding
            : tokens.surfaceVerticalPadding,
      ),
      child: child,
    );
  }
}

/// Shared responsive arrangement for volume, primary and trailing controls.
class PlayerChromeControlLayout extends StatelessWidget {
  const PlayerChromeControlLayout({
    super.key,
    required this.primary,
    required this.leading,
    required this.trailing,
    this.compactMetrics = false,
  });

  final Widget primary;
  final Widget leading;
  final Widget trailing;
  final bool compactMetrics;

  @override
  Widget build(BuildContext context) {
    final tokens = PlayerChromeTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthClass = playerChromeWidthClassFor(
          constraints.maxWidth,
          tokens,
        );
        if (widthClass != PlayerChromeWidthClass.wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: primary),
              SizedBox(
                height: widthClass == PlayerChromeWidthClass.compact
                    ? compactMetrics
                          ? 8
                          : 10
                    : compactMetrics
                    ? 10
                    : 12,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: leading),
                  SizedBox(width: tokens.controlGap),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return SizedBox(
          height: compactMetrics ? 48 : 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(alignment: Alignment.centerLeft, child: leading),
              Center(child: primary),
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          ),
        );
      },
    );
  }
}

/// Expressive containment for the high-frequency transport actions.
class PlayerPrimaryControlGroup extends StatelessWidget {
  const PlayerPrimaryControlGroup({
    super.key,
    required this.children,
    this.compact = false,
  });

  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = PlayerChromeTokens.of(context);
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    return AppSurface(
      level: AppSurfaceLevel.low,
      shape: RoundedRectangleBorder(borderRadius: shapes.pill),
      padding: EdgeInsets.all(compact ? 3 : 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(width: tokens.groupGap),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Shared semantic and geometry wrapper for each player's volume mechanics.
class PlayerVolumeCluster extends StatelessWidget {
  const PlayerVolumeCluster({
    super.key,
    required this.semanticLabel,
    required this.muteButton,
    required this.slider,
    required this.valueLabel,
    this.gap = 6,
  });

  final String semanticLabel;
  final Widget muteButton;
  final Widget slider;
  final Widget valueLabel;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          muteButton,
          slider,
          SizedBox(width: gap),
          valueLabel,
        ],
      ),
    );
  }
}

/// Shared transition policy for player chrome layers and status panels.
class PlayerChromeTransition extends StatelessWidget {
  const PlayerChromeTransition({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: motion.content,
      curve: motion.standardCurve,
      child: AnimatedSlide(
        offset: visible || motion.content == Duration.zero
            ? Offset.zero
            : const Offset(0, 0.04),
        duration: motion.content,
        curve: motion.emphasizedCurve,
        child: child,
      ),
    );
  }
}
