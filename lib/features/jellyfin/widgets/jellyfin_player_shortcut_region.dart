import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Provider-free keyboard policy for Jellyfin playback and its episode panel.
class JellyfinPlayerShortcutRegion extends StatelessWidget {
  const JellyfinPlayerShortcutRegion({
    super.key,
    required this.episodeOverlayVisible,
    required this.onTogglePlayPause,
    required this.onToggleMute,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onEscape,
    required this.child,
  });

  final bool episodeOverlayVisible;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleMute;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onEscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (!episodeOverlayVisible) ...{
          const SingleActivator(LogicalKeyboardKey.space): onTogglePlayPause,
          const SingleActivator(LogicalKeyboardKey.keyM): onToggleMute,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): onSeekBackward,
          const SingleActivator(LogicalKeyboardKey.arrowRight): onSeekForward,
        },
        const SingleActivator(LogicalKeyboardKey.escape): onEscape,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
