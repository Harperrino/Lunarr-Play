import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:m3uxtream_player/core/services/live_audio_track_service.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/player_chrome_tokens.dart';

class AudioTrackMenuButton extends ConsumerWidget {
  const AudioTrackMenuButton({
    super.key,
    required this.audioTracks,
    required this.selectedAudioTrackId,
    this.compact = false,
    this.onUserActivity,
  });

  final List<AudioTrack> audioTracks;
  final String? selectedAudioTrackId;
  final bool compact;
  final VoidCallback? onUserActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = audioTracks;
    final hasTracks = tracks.isNotEmpty;
    final selectedTrackId = selectedAudioTrackId;
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;

    return PopupMenuButton<String>(
      tooltip: hasTracks
          ? context.l10n.audioTrackChooseTooltip
          : context.l10n.audioTrackNoneDetectedTooltip,
      enabled: hasTracks,
      offset: const Offset(0, 12),
      color: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapes.large),
      ),
      padding: EdgeInsets.zero,
      onSelected: (trackId) {
        onUserActivity?.call();
        ref.read(playerNotifierProvider.notifier).selectAudioTrack(trackId);
      },
      itemBuilder: (context) => [
        _menuItem(
          context: context,
          value: AudioTrack.auto().id,
          label: context.l10n.audioTrackAutomatic,
          selected: selectedTrackId == null,
        ),
        for (var index = 0; index < tracks.length; index++)
          _menuItem(
            context: context,
            value: tracks[index].id,
            label: LiveAudioTrackService.labelFor(
              tracks[index],
              fallbackIndex: index + 1,
            ),
            selected: selectedTrackId == tracks[index].id,
          ),
      ],
      child: _AudioTrackButtonVisual(compact: compact, enabled: hasTracks),
    );
  }

  PopupMenuItem<String> _menuItem({
    required BuildContext context,
    required String value,
    required String label,
    required bool selected,
  }) {
    final colors = Theme.of(context).colorScheme;

    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_rounded : Icons.circle_rounded,
            size: 16,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioTrackButtonVisual extends StatelessWidget {
  const _AudioTrackButtonVisual({required this.compact, required this.enabled});

  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = PlayerChromeTokens.of(context);
    final size = compact ? tokens.compactControlExtent : tokens.controlExtent;
    final colors = Theme.of(context).colorScheme;
    const shape = CircleBorder();

    return Material(
      color: enabled
          ? colors.secondaryContainer
          : colors.surfaceContainerHighest,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            Icons.audiotrack_rounded,
            size: 18,
            color: enabled
                ? colors.onSecondaryContainer
                : colors.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}
