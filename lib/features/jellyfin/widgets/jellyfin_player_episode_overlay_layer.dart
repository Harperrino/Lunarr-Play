import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';

/// Provider-free mount, animation, focus and semantics boundary for the panel.
class JellyfinPlayerEpisodeOverlayLayer extends StatelessWidget {
  const JellyfinPlayerEpisodeOverlayLayer({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    return IgnorePointer(
      key: const ValueKey('jellyfin-episode-overlay-layer'),
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedSwitcher(
            duration: motion.content,
            reverseDuration: motion.content,
            switchInCurve: motion.emphasizedCurve,
            switchOutCurve: motion.standardCurve,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              alignment: Alignment.centerRight,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: motion.emphasizedCurve,
                reverseCurve: motion.standardCurve,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.08, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            child: visible
                ? KeyedSubtree(
                    key: const ValueKey('jellyfin-episode-overlay-mounted'),
                    child: child,
                  )
                : const SizedBox.shrink(
                    key: ValueKey('jellyfin-episode-overlay-unmounted'),
                  ),
          ),
        ),
      ),
    );
  }
}
