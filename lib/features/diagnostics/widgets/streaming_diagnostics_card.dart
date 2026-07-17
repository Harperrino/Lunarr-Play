import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/stream_diagnostics_service.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/streaming_diagnostics_providers.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_status_pill.dart';
import 'package:m3uxtream_player/shared/widgets/status_snack_bar.dart';

final _streamingDiagnosticsPlaybackUriProvider = Provider<String?>((ref) {
  return ref.watch(
    playerNotifierProvider.select((state) => state.valueOrNull?.playbackUri),
  );
});

final _streamingDiagnosticsHasPlayerLogsProvider = Provider<bool>((ref) {
  return ref.watch(uiLogsProvider.select((logs) => logs.isNotEmpty));
});

class StreamingDiagnosticsCard extends ConsumerWidget {
  const StreamingDiagnosticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(streamingDiagnosticsSettingsProvider);
    final probeBusy = ref.watch(streamingDiagnosticsProbeBusyProvider);
    final lastFailure = ref.watch(latestStreamingFailureProvider);
    final playbackUri = ref.watch(_streamingDiagnosticsPlaybackUriProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final hasPlayerLogs = ref.watch(_streamingDiagnosticsHasPlayerLogsProvider);

    return settingsAsync.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) =>
          Text('Failed to load streaming diagnostics settings: $err'),
      data: (settings) {
        final targetUrl = selectedChannel?.streamUrl ?? playbackUri;
        final canProbe = targetUrl != null && targetUrl.isNotEmpty;
        final probeUrl = targetUrl;

        return AppSurface(
          level: AppSurfaceLevel.high,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppSurface(
                    level: AppSurfaceLevel.low,
                    width: 34,
                    height: 34,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 16,
                      color: colors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLAYER & STREAMING',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Erweiterte Diagnose',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  M3StatusPill(
                    label: settings.autoFallbackEnabled
                        ? 'Fallback on'
                        : 'Fallback off',
                    accent: settings.autoFallbackEnabled
                        ? colors.secondary
                        : colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                title: 'Fallback automatisch verwenden',
                subtitle:
                    'Nutze die Live-Fallback-Matrix automatisch, bevor ein Fehler angezeigt wird.',
                value: settings.autoFallbackEnabled,
                onChanged: (value) => ref
                    .read(streamingDiagnosticsSettingsProvider.notifier)
                    .setAutoFallbackEnabled(value),
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                title: 'Bei Fehler Diagnose anzeigen',
                subtitle:
                    'Schreibt eine kurze Diagnose in die UI-Logs, wenn ein Live-Start scheitert.',
                value: settings.showOnErrorEnabled,
                onChanged: (value) => ref
                    .read(streamingDiagnosticsSettingsProvider.notifier)
                    .setShowOnErrorEnabled(value),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.content_copy_rounded,
                    label: 'Letzten Fehler kopieren',
                    enabled: lastFailure != null,
                    onTap: lastFailure == null
                        ? null
                        : () => _copyText(
                            context,
                            ref,
                            lastFailure.summaryLine,
                            'Letzten Streaming-Fehler kopiert.',
                          ),
                  ),
                  _ActionButton(
                    icon: Icons.description_rounded,
                    label: 'Player-Log kopieren',
                    enabled: hasPlayerLogs,
                    onTap: hasPlayerLogs
                        ? () => _copyPlayerLogs(context, ref)
                        : null,
                  ),
                  _ActionButton(
                    icon: Icons.wifi_rounded,
                    label: 'Stream testen',
                    enabled: canProbe && !probeBusy,
                    onTap: canProbe && !probeBusy
                        ? () async {
                            await ref
                                .read(
                                  streamingDiagnosticsProbeBusyProvider
                                      .notifier,
                                )
                                .runExclusive(
                                  () => _testStream(
                                    context,
                                    ref,
                                    probeUrl!,
                                    selectedChannel?.name,
                                    selectedChannel?.id.toString(),
                                  ),
                                );
                          }
                        : null,
                  ),
                ],
              ),
              if (lastFailure != null) ...[
                const SizedBox(height: 14),
                _LastFailureCard(failure: lastFailure),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyText(
    BuildContext context,
    WidgetRef ref,
    String text,
    String message,
  ) async {
    final redactedText = redactStreamText(text);
    await Clipboard.setData(ClipboardData(text: redactedText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        appStatusSnackBar(
          context,
          message: message,
          tone: AppStatusSnackBarTone.success,
        ),
      );
    }
    ref
        .read(uiLogsProvider.notifier)
        .addLog(redactStreamText('Diagnostics: $message'));
  }

  Future<void> _copyPlayerLogs(BuildContext context, WidgetRef ref) async {
    final playerLogs = ref.read(uiLogsProvider);
    if (playerLogs.isEmpty) return;

    await _copyText(context, ref, playerLogs.join('\n'), 'Player-Log kopiert.');
  }

  Future<void> _testStream(
    BuildContext context,
    WidgetRef ref,
    String url,
    String? channelName,
    String? channelId,
  ) async {
    try {
      final result = await StreamDiagnosticsService.probeStreamUrl(url);
      final classification = StreamDiagnosticsService.classifyFailure(
        probe: result,
        error: result.success ? null : 'probe failed',
      );
      final hintSuffix = result.hlsHintSummary == null
          ? ''
          : ' · ${result.hlsHintSummary}';
      final message = result.success
          ? 'Stream check OK: ${result.httpStatus ?? 'no status'} ${result.contentType ?? ''}$hintSuffix'
                .trim()
          : 'Stream check ${classification.label}: ${result.httpStatus ?? 'no status'}$hintSuffix';
      ref
          .read(uiLogsProvider.notifier)
          .addLog(redactStreamText('Diagnostics: $message'));
      ref
          .read(streamingDiagnosticsProvider.notifier)
          .record(
            StreamingDiagnosticEvent(
              timestamp: DateTime.now(),
              phase: result.success
                  ? StreamingDiagnosticPhase.success
                  : StreamingDiagnosticPhase.failure,
              channelName: channelName,
              channelId: channelId,
              sourceUrlRedacted: redactStreamUrl(url),
              playbackUrlRedacted: redactStreamUrl(
                result.resolvedUri.toString(),
              ),
              fallbackLabel: 'Probe',
              headerProfile: LiveStreamHeaderProfile.appMpv,
              deliveryType: result.looksLikeHls ? 'hls' : 'continuous',
              httpStatus: result.httpStatus,
              contentType: result.contentType,
              failureKind: result.success ? null : classification.kind,
              duration: result.duration,
              diagnosisNote: result.success
                  ? 'probe successful$hintSuffix'
                  : '${classification.label}$hintSuffix',
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appStatusSnackBar(
            context,
            message: message,
            tone: result.success
                ? AppStatusSnackBarTone.success
                : AppStatusSnackBarTone.warning,
          ),
        );
      }
    } catch (e) {
      ref
          .read(uiLogsProvider.notifier)
          .addLog(redactStreamText('Diagnostics: Stream check failed: $e'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appStatusSnackBar(
            context,
            message: 'Stream check failed.',
            tone: AppStatusSnackBarTone.error,
          ),
        );
      }
    }
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _LastFailureCard extends StatelessWidget {
  const _LastFailureCard({required this.failure});

  final StreamingDiagnosticEvent failure;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.base,
      padding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: colors.tertiary,
              ),
              SizedBox(width: 8),
              Text(
                'Last streaming failure',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            failure.summaryLine,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
            ).copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
