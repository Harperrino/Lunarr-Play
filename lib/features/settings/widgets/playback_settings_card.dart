import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_control_row.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';
import 'package:m3uxtream_player/shared/widgets/stepper_control.dart';

/// Playback tuning for live startup buffering and VOD preparation.
class PlaybackSettingsCard extends ConsumerWidget {
  const PlaybackSettingsCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final liveStartupBufferAsync = ref.watch(playerBufferSecondsProvider);
    final liveStartupBufferSeconds =
        liveStartupBufferAsync.valueOrNull ??
        PlayerBufferSecondsNotifier.defaultSeconds;
    final vodPreBufferAsync = ref.watch(vodPreBufferTargetSecondsProvider);
    final vodPreBufferSeconds =
        vodPreBufferAsync.valueOrNull ??
        VodPreBufferTargetSecondsNotifier.defaultSeconds;
    final forceStereoAsync = ref.watch(forceStereoEnabledProvider);
    final forceStereoEnabled = forceStereoAsync.valueOrNull ?? false;
    final preferredLanguageAsync = ref.watch(preferredAudioLanguageProvider);
    final preferredLanguage =
        preferredLanguageAsync.valueOrNull ?? preferredAudioLanguageAutoValue;

    return AppSurface(
      level: AppSurfaceLevel.high,
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3SettingsSectionHeader(
            icon: Icons.speed_rounded,
            iconColor: colors.secondary,
            title: 'PLAYBACK',
            description:
                'Wie viel Puffer vor dem Live-Start aufgebaut werden soll. Höhere Werte verzögern den Start, mindern aber Ruckler bei instabilen Streams.',
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 12),
          M3SettingsControlRow(
            label: 'Live-Startpuffer',
            compact: compact,
            control: _LiveStartupBufferDropdown(
              value: liveStartupBufferSeconds,
              compact: compact,
              onChanged: (value) async {
                if (value == null) return;
                await ref
                    .read(playerBufferSecondsProvider.notifier)
                    .setSeconds(value);
                final playerState = ref
                    .read(playerNotifierProvider)
                    .valueOrNull;
                if (playerState != null) {
                  final isLive = !isSeekableChannel(
                    ref.read(selectedChannelProvider),
                  );
                  await PlayerBufferService.applyPlaybackProfile(
                    playerState.player,
                    isLive: isLive,
                    preloadSeconds: value,
                    liveStartupBuffer: false,
                  );
                }
              },
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          if (!compact) ...[
            Text(
              'VOD pre-buffer loads media before playback so scrubbing is smoother. '
              'Higher values need more time and bandwidth.',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
          ],
          M3SettingsControlRow(
            label: 'VOD pre-buffer',
            compact: compact,
            control: StepperControl(
              value: vodPreBufferSeconds,
              min: 15,
              max: 300,
              suffix: 's',
              longPressStep: 15,
              onChanged: (value) async {
                await ref
                    .read(vodPreBufferTargetSecondsProvider.notifier)
                    .setSeconds(value);
              },
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          AppSurface(
            level: AppSurfaceLevel.low,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 12 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.headphones_rounded,
                  color: colors.secondary,
                  size: compact ? 16 : 18,
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stereo erzwingen',
                        style: TextStyle(
                          fontSize: compact ? 12 : 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Hilft bei externen Soundkarten, Mischpulten oder Sendern mit Mehrkanalton.',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                Switch(
                  value: forceStereoEnabled,
                  onChanged: (value) async {
                    await ref
                        .read(forceStereoEnabledProvider.notifier)
                        .setEnabled(value);
                    final playerState = ref
                        .read(playerNotifierProvider)
                        .valueOrNull;
                    if (playerState != null) {
                      await PlayerBufferService.applyAudioCompatibility(
                        playerState.player,
                        forceStereo: value,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          AppSurface(
            level: AppSurfaceLevel.low,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 12 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language_rounded,
                  color: colors.secondary,
                  size: compact ? 16 : 18,
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bevorzugte Audiosprache',
                        style: TextStyle(
                          fontSize: compact ? 12 : 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Bei mehreren Audiospuren wird diese Sprache bevorzugt.',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                _PreferredLanguageDropdown(
                  value: preferredLanguage,
                  compact: compact,
                  onChanged: (value) async {
                    await ref
                        .read(preferredAudioLanguageProvider.notifier)
                        .setLanguage(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStartupBufferDropdown extends StatelessWidget {
  const _LiveStartupBufferDropdown({
    required this.value,
    required this.compact,
    required this.onChanged,
  });

  final int value;
  final bool compact;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return M3DropdownField<int>(
      value: normalizeLiveStartupBufferSeconds(value),
      compact: compact,
      entries: liveStartupBufferSecondsOptions
          .map(
            (seconds) => DropdownMenuEntry<int>(
              value: seconds,
              label: labelForLiveStartupBufferSeconds(seconds),
            ),
          )
          .toList(growable: false),
      onSelected: onChanged,
    );
  }
}

class _PreferredLanguageDropdown extends StatelessWidget {
  const _PreferredLanguageDropdown({
    required this.value,
    required this.compact,
    required this.onChanged,
  });

  final String value;
  final bool compact;
  final ValueChanged<String?> onChanged;

  static const _options = <({String code, String label})>[
    (code: preferredAudioLanguageAutoValue, label: 'Automatisch'),
    (code: 'de', label: 'Deutsch'),
    (code: 'en', label: 'English'),
    (code: 'fr', label: 'Français'),
    (code: 'es', label: 'Español'),
    (code: 'it', label: 'Italiano'),
    (code: 'pt', label: 'Português'),
    (code: 'tr', label: 'Türkçe'),
    (code: 'ru', label: 'Русский'),
  ];

  @override
  Widget build(BuildContext context) {
    return M3DropdownField<String>(
      value: value,
      compact: compact,
      entries: _options
          .map(
            (option) => DropdownMenuEntry<String>(
              value: option.code,
              label: option.label,
            ),
          )
          .toList(growable: false),
      onSelected: onChanged,
    );
  }
}
