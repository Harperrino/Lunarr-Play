import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/providers/playback_preferences_providers.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_ambient_background.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_control_row.dart';

class AppAmbientSettingsSection extends ConsumerStatefulWidget {
  const AppAmbientSettingsSection({
    super.key,
    required this.preferences,
    required this.compact,
  });

  final PlaybackPreferences preferences;
  final bool compact;

  @override
  ConsumerState<AppAmbientSettingsSection> createState() =>
      _AppAmbientSettingsSectionState();
}

class _AppAmbientSettingsSectionState
    extends ConsumerState<AppAmbientSettingsSection> {
  late double _hueA = widget.preferences.ambientCustomHueA;
  late double _hueB = widget.preferences.ambientCustomHueB;
  late double _intensity = widget.preferences.ambientIntensity;

  @override
  void didUpdateWidget(covariant AppAmbientSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.ambientCustomHueA !=
        widget.preferences.ambientCustomHueA) {
      _hueA = widget.preferences.ambientCustomHueA;
    }
    if (oldWidget.preferences.ambientCustomHueB !=
        widget.preferences.ambientCustomHueB) {
      _hueB = widget.preferences.ambientCustomHueB;
    }
    if (oldWidget.preferences.ambientIntensity !=
        widget.preferences.ambientIntensity) {
      _intensity = widget.preferences.ambientIntensity;
    }
  }

  PlaybackPreferences get _previewPreferences => widget.preferences.copyWith(
    ambientCustomHueA: _hueA,
    ambientCustomHueB: _hueB,
    ambientIntensity: _intensity,
  );

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playbackPreferencesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: widget.compact ? 24 : 32),
        Text(
          context.l10n.appearanceAmbientTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.appearanceAmbientDescription,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: widget.compact ? 10 : 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            key: const ValueKey('app-ambient-settings-preview'),
            height: widget.compact ? 112 : 148,
            child: AppAmbientBackground(preferences: _previewPreferences),
          ),
        ),
        SizedBox(height: widget.compact ? 10 : 14),
        M3SettingsControlRow(
          label: context.l10n.appearanceAmbientEnabled,
          compact: widget.compact,
          control: Switch(
            value: widget.preferences.ambientBackgroundEnabled,
            onChanged: notifier.setAmbientBackgroundEnabled,
          ),
        ),
        SizedBox(height: widget.compact ? 8 : 10),
        M3SettingsControlRow(
          label: context.l10n.appearanceAmbientPreset,
          compact: widget.compact,
          control: M3DropdownField<PlayerAmbientPreset>(
            value: widget.preferences.ambientPreset,
            compact: widget.compact,
            entries: PlayerAmbientPreset.values
                .map(
                  (preset) => DropdownMenuEntry<PlayerAmbientPreset>(
                    value: preset,
                    label: _presetLabel(context, preset),
                  ),
                )
                .toList(growable: false),
            onSelected: (value) {
              if (value != null) notifier.setAmbientPreset(value);
            },
          ),
        ),
        if (widget.preferences.ambientPreset == PlayerAmbientPreset.custom) ...[
          _AmbientSlider(
            label: context.l10n.appearanceAmbientHueA,
            value: _hueA,
            max: 360,
            displayValue: '${_hueA.round()}°',
            onChanged: (value) {
              setState(() => _hueA = value);
              notifier.previewAmbientCustomHueA(value);
            },
            onChangeEnd: notifier.setAmbientCustomHueA,
          ),
          _AmbientSlider(
            label: context.l10n.appearanceAmbientHueB,
            value: _hueB,
            max: 360,
            displayValue: '${_hueB.round()}°',
            onChanged: (value) {
              setState(() => _hueB = value);
              notifier.previewAmbientCustomHueB(value);
            },
            onChangeEnd: notifier.setAmbientCustomHueB,
          ),
        ],
        _AmbientSlider(
          label: context.l10n.appearanceAmbientIntensity,
          value: _intensity,
          max: 1,
          divisions: 20,
          displayValue: context.l10n.appearanceAmbientPercent(
            (_intensity * 100).round(),
          ),
          onChanged: (value) {
            setState(() => _intensity = value);
            notifier.previewAmbientIntensity(value);
          },
          onChangeEnd: notifier.setAmbientIntensity,
        ),
        M3SettingsControlRow(
          label: context.l10n.appearanceAmbientMotion,
          compact: widget.compact,
          control: M3DropdownField<PlayerAmbientMotion>(
            value: widget.preferences.ambientMotion,
            compact: widget.compact,
            entries: PlayerAmbientMotion.values
                .map(
                  (motion) => DropdownMenuEntry<PlayerAmbientMotion>(
                    value: motion,
                    label: _motionLabel(context, motion),
                  ),
                )
                .toList(growable: false),
            onSelected: (value) {
              if (value != null) notifier.setAmbientMotion(value);
            },
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: notifier.resetAmbientBackground,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(context.l10n.appearanceAmbientReset),
          ),
        ),
      ],
    );
  }
}

class _AmbientSlider extends StatelessWidget {
  const _AmbientSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.displayValue,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
  });

  final String label;
  final double value;
  final double max;
  final int? divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: displayValue,
    slider: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(displayValue),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          max: max,
          divisions: divisions,
          label: displayValue,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    ),
  );
}

String _presetLabel(BuildContext context, PlayerAmbientPreset preset) =>
    switch (preset) {
      PlayerAmbientPreset.lunarr => context.l10n.appearanceAmbientPresetLunarr,
      PlayerAmbientPreset.aurora => context.l10n.appearanceAmbientPresetAurora,
      PlayerAmbientPreset.ember => context.l10n.appearanceAmbientPresetEmber,
      PlayerAmbientPreset.custom => context.l10n.appearanceAmbientPresetCustom,
    };

String _motionLabel(BuildContext context, PlayerAmbientMotion motion) =>
    switch (motion) {
      PlayerAmbientMotion.slow => context.l10n.appearanceAmbientMotionSlow,
      PlayerAmbientMotion.normal => context.l10n.appearanceAmbientMotionNormal,
      PlayerAmbientMotion.fast => context.l10n.appearanceAmbientMotionFast,
    };
