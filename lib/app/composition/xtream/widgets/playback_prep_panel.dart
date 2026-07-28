import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/app/composition/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_card.dart';
import 'package:m3uxtream_player/shared/theme/catalogue_surface_roles.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Pre-buffer prep UI for VOD movies and series episodes.
class PlaybackPrepPanel extends ConsumerWidget {
  const PlaybackPrepPanel({super.key, required this.target});

  final PlaybackPrepTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final roles = CatalogueSurfaceRoles.of(context);
    final prep = ref.watch(playbackPrepControllerProvider);
    final preBufferAsync = ref.watch(vodPreBufferEnabledProvider);
    final preBufferEnabled = preBufferAsync.valueOrNull ?? true;
    final preBufferTargetSecs =
        ref.watch(vodPreBufferTargetSecondsProvider).valueOrNull ??
        VodPreBufferTargetSecondsNotifier.defaultSeconds;
    final progress = ref.watch(playbackPrepBufferProgressProvider);
    final mediaInfo = ref.watch(playbackPrepMediaInfoProvider);
    final channel = target.playbackChannel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSurface(
                level: AppSurfaceLevel.standard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _IconButtonShell(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.l10n.commonBackTooltip,
                      onPressed: prep.isBusy
                          ? null
                          : () => ref
                                .read(playbackPrepControllerProvider.notifier)
                                .cancel(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target.isSeries
                                ? context.l10n.playbackPrepEpisodeTitle
                                : context.l10n.playbackPrepMovieTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            target.isSeries
                                ? context.l10n.playbackPrepEpisodeSubtitle
                                : context.l10n.playbackPrepMovieSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: roles.subtitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSurface(
                level: AppSurfaceLevel.standard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PrepPoster(
                            logoUrl: target.posterUrl ?? channel.logo,
                            groupName: channel.groupName,
                            isSeries: target.isSeries,
                            width: 132,
                          ),
                          const SizedBox(height: 16),
                          _PrepDetails(
                            target: target,
                            channel: channel,
                            preBufferEnabled: preBufferEnabled,
                            preBufferTargetSecs: preBufferTargetSecs,
                            progress: progress,
                            prep: prep,
                            mediaInfo: mediaInfo,
                            onTogglePreBuffer: preBufferAsync.isLoading
                                ? null
                                : (value) => ref
                                      .read(
                                        vodPreBufferEnabledProvider.notifier,
                                      )
                                      .setEnabled(value),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PrepPoster(
                            logoUrl: target.posterUrl ?? channel.logo,
                            groupName: channel.groupName,
                            isSeries: target.isSeries,
                            width: 140,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _PrepDetails(
                              target: target,
                              channel: channel,
                              preBufferEnabled: preBufferEnabled,
                              preBufferTargetSecs: preBufferTargetSecs,
                              progress: progress,
                              prep: prep,
                              mediaInfo: mediaInfo,
                              onTogglePreBuffer: preBufferAsync.isLoading
                                  ? null
                                  : (value) => ref
                                        .read(
                                          vodPreBufferEnabledProvider.notifier,
                                        )
                                        .setEnabled(value),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              AppSurface(
                level: AppSurfaceLevel.standard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (prep.phase == PlaybackPrepPhase.preparing) ...[
                      LinearProgressIndicator(
                        value: preBufferEnabled ? progress : null,
                        backgroundColor: roles.shimmerBase,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        preBufferEnabled
                            ? context.l10n.playbackPrepBufferingProgress(
                                (progress * 100).round(),
                              )
                            : context.l10n.playbackPrepOpeningStream,
                        style: TextStyle(fontSize: 11, color: roles.subtitle),
                      ),
                    ] else if (prep.phase == PlaybackPrepPhase.ready) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            preBufferEnabled
                                ? context.l10n.playbackPrepCompleted
                                : context.l10n.playbackPrepReady,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (mediaInfo.resolutionLabel != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.playbackPrepDetectedMedia(
                            mediaInfo.resolutionLabel!,
                            mediaInfo.containerLabel != null
                                ? ' — ${mediaInfo.containerLabel}'
                                : '',
                          ),
                          style: TextStyle(fontSize: 11, color: roles.subtitle),
                        ),
                      ],
                    ] else if (prep.phase == PlaybackPrepPhase.error &&
                        prep.errorMessage != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: colors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              prep.errorMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        target.isSeries
                            ? context.l10n.playbackPrepEpisodeExplanation
                            : context.l10n.playbackPrepMovieExplanation,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: roles.subtitle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (prep.phase != PlaybackPrepPhase.ready)
                    _ActionButton(
                      label: prep.isBusy
                          ? context.l10n.playbackPrepLoadingAction
                          : context.l10n.playbackPrepPrepareAction,
                      icon: prep.isBusy
                          ? Icons.hourglass_top_rounded
                          : Icons.download_rounded,
                      filled: true,
                      onPressed: prep.isBusy
                          ? null
                          : () => ref
                                .read(playbackPrepControllerProvider.notifier)
                                .prepareSelected(),
                    ),
                  if (prep.phase == PlaybackPrepPhase.ready)
                    _ActionButton(
                      label: context.l10n.playbackPrepStartAction,
                      icon: Icons.play_arrow_rounded,
                      filled: true,
                      onPressed: () => ref
                          .read(playbackPrepControllerProvider.notifier)
                          .startPlayback(),
                    ),
                  _ActionButton(
                    label: context.l10n.playbackPrepStartImmediatelyAction,
                    icon: Icons.bolt_rounded,
                    filled: false,
                    onPressed: prep.isBusy
                        ? null
                        : () async {
                            if (prep.phase != PlaybackPrepPhase.ready) {
                              await ref
                                  .read(playbackPrepControllerProvider.notifier)
                                  .prepareSelected();
                            }
                            if (ref
                                    .read(playbackPrepControllerProvider)
                                    .phase ==
                                PlaybackPrepPhase.ready) {
                              await ref
                                  .read(playbackPrepControllerProvider.notifier)
                                  .startPlayback();
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrepDetails extends StatelessWidget {
  const _PrepDetails({
    required this.target,
    required this.channel,
    required this.preBufferEnabled,
    required this.preBufferTargetSecs,
    required this.progress,
    required this.prep,
    required this.mediaInfo,
    required this.onTogglePreBuffer,
  });

  final PlaybackPrepTarget target;
  final Channel channel;
  final bool preBufferEnabled;
  final int preBufferTargetSecs;
  final double progress;
  final PlaybackPrepState prep;
  final PlaybackMediaInfo mediaInfo;
  final ValueChanged<bool>? onTogglePreBuffer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final roles = CatalogueSurfaceRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          channel.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        if (target.subtitle != null && target.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            target.subtitle!,
            style: TextStyle(fontSize: 12, color: roles.subtitle),
          ),
        ],
        if (channel.groupName != null && channel.groupName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            channel.groupName!,
            style: TextStyle(fontSize: 11, color: roles.subtitle),
          ),
        ],
        if (target.startPosition > Duration.zero) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.playbackPrepStartPosition(
              _formatDuration(target.startPosition),
            ),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colors.secondary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          target.isSeries
              ? context.l10n.playbackPrepEpisodeDetail
              : context.l10n.playbackPrepMovieDetail,
          style: TextStyle(fontSize: 12, height: 1.45, color: roles.subtitle),
        ),
        const SizedBox(height: 18),
        AppSurface(
          level: AppSurfaceLevel.low,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              context.l10n.playbackPrepToggleTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              context.l10n.playbackPrepToggleSubtitle(preBufferTargetSecs),
              style: TextStyle(fontSize: 11, color: roles.subtitle),
            ),
            value: preBufferEnabled,
            onChanged: onTogglePreBuffer,
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

class _PrepPoster extends StatelessWidget {
  const _PrepPoster({
    this.logoUrl,
    this.groupName,
    this.isSeries = false,
    this.width = 140,
  });

  final String? logoUrl;
  final String? groupName;
  final bool isSeries;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = GroupAccent.forGroup(
      groupName ?? (isSeries ? 'Series' : 'Movies'),
    );
    final height = width / vodPosterAspectRatio;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: _cachePixels(width, dpr),
                memCacheHeight: _cachePixels(height, dpr),
                errorWidget: (_, _, _) => _placeholder(accent),
              )
            : _placeholder(accent),
      ),
    );
  }

  Widget _placeholder(Color accent) {
    return ColoredBox(
      color: accent.withValues(alpha: 0.24),
      child: Center(
        child: Icon(
          isSeries ? Icons.tv_rounded : Icons.movie_rounded,
          size: 36,
          color: accent.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

int _cachePixels(double logicalSize, double dpr) {
  return (logicalSize * dpr).ceil().clamp(1, 4096);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    final iconWidget = Icon(icon);
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: labelWidget,
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: iconWidget,
      label: labelWidget,
    );
  }
}

class _IconButtonShell extends StatelessWidget {
  const _IconButtonShell({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
    );
  }
}
