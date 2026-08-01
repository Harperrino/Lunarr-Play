import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_state.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_playback_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_controls.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Full-screen Jellyfin playback surface with its own media_kit instance.
///
/// Keyboard: a local shortcut scope handles Space (play/pause), M (mute) and
/// the arrow keys (seek). The global Lunarr shortcut wrapper is deliberately
/// untouched; if it intercepts those keys at runtime, the UI controls remain
/// the primary interaction path.
class JellyfinPlayerView extends ConsumerStatefulWidget {
  const JellyfinPlayerView({
    super.key,
    required this.connection,
    required this.item,
  });

  final JellyfinConnection connection;
  final JellyfinItem item;

  @override
  ConsumerState<JellyfinPlayerView> createState() => _JellyfinPlayerViewState();
}

class _JellyfinPlayerViewState extends ConsumerState<JellyfinPlayerView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(jellyfinPlayerControllerProvider)
            .play(widget.item);
      }
    });
  }

  @override
  void didUpdateWidget(JellyfinPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(jellyfinPlayerControllerProvider).play(widget.item);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(jellyfinPlayerControllerProvider);

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          SingleActivator(LogicalKeyboardKey.space): () =>
              unawaited(controller.togglePlayPause()),
          SingleActivator(LogicalKeyboardKey.keyM): () =>
              unawaited(controller.toggleMute()),
          SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              unawaited(
                controller.seekRelative(const Duration(seconds: -10)),
              ),
          SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              unawaited(controller.seekRelative(const Duration(seconds: 10))),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlayerHeader(controller: controller),
            Expanded(
              child: ValueListenableBuilder<JellyfinPlayerState>(
                valueListenable: controller.state,
                builder: (context, state, _) {
                  final l10n = context.l10n;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (state.initialized)
                        Video(
                          controller: controller.videoController,
                          fit: BoxFit.contain,
                        )
                      else
                        const SizedBox.expand(),
                      if (state.error)
                        _PlayerError(onBack: () => jellyfinGoBack(ref))
                      else if (state.buffering || !state.initialized)
                        const Center(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        )
                      else
                        Center(child: Text(l10n.playerLoading)),
                    ],
                  );
                },
              ),
            ),
            JellyfinPlayerControls(
              controller: controller,
              onStop: () => jellyfinGoBack(ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.controller});

  final JellyfinPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ValueListenableBuilder<JellyfinPlayerState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.title.isEmpty
                      ? l10n.jellyfinConnected
                      : state.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (state.method != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    switch (state.method!) {
                      JellyfinPlaybackMethod.directPlay =>
                        l10n.jellyfinPlayerDirectPlay,
                      JellyfinPlaybackMethod.directStream =>
                        l10n.jellyfinPlayerDirectStream,
                      JellyfinPlaybackMethod.transcode =>
                        l10n.jellyfinPlayerTranscode,
                    },
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
          const SizedBox(height: 12),
          Text(
            context.l10n.jellyfinPlayerFailed,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onBack,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: Text(context.l10n.jellyfinStopTooltip),
          ),
        ],
      ),
    );
  }
}
