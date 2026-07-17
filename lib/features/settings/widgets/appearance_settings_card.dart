import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/settings/providers/appearance_providers.dart';
import 'package:m3uxtream_player/shared/theme/appearance_preferences.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_expressive_slider.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';

/// Settings-owned adapter for the user accent and neutral surface controls.
class AppearanceSettingsCard extends ConsumerWidget {
  const AppearanceSettingsCard({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearancePreferencesProvider);
    final controller = ref.read(appearancePreferencesProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return AppSurface(
      key: const ValueKey('appearance-settings-card'),
      level: AppSurfaceLevel.standard,
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3SettingsSectionHeader(
            icon: Icons.palette_outlined,
            iconColor: colors.primary,
            title: 'Darstellung',
            description: 'Akzent und neutrale Flächen getrennt anpassen.',
            compact: compact,
            trailing: TextButton.icon(
              onPressed: appearance == AppearancePreferences.defaults
                  ? null
                  : controller.reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 17),
              label: const Text('Standard wiederherstellen'),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackPreview = constraints.maxWidth < 600;
              final controls = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AppearanceExpressiveSlider(
                    label: 'Akzentfarbe',
                    valueLabel: '${appearance.accentHue.round()}°',
                    value: appearance.accentHue,
                    min: 0,
                    max: 360,
                    onChanged: controller.setAccentHue,
                  ),
                  const SizedBox(height: 10),
                  _AppearanceExpressiveSlider(
                    label: 'Neutralgrau / Flächenton',
                    valueLabel: '${(appearance.surfaceTone * 100).round()}%',
                    value: appearance.surfaceTone,
                    min: 0,
                    max: 1,
                    onChanged: controller.setSurfaceTone,
                  ),
                ],
              );
              final preview = const _AppearancePreview();
              if (stackPreview) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [controls, const SizedBox(height: 14), preview],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: controls),
                  const SizedBox(width: 20),
                  SizedBox(width: 220, child: preview),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppearanceExpressiveSlider extends StatelessWidget {
  const _AppearanceExpressiveSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(valueLabel, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        M3ExpressiveSlider(
          size: M3ExpressiveSliderSize.m,
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
          semanticFormatter: (nextValue) => '$label ${_formatValue(nextValue)}',
        ),
      ],
    );
  }

  String _formatValue(double nextValue) {
    if (max == 360) return '${nextValue.round()} Grad';
    return '${(nextValue * 100).round()} Prozent';
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.live_tv_rounded, color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live TV',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Icon(Icons.check_circle_rounded, color: colors.primary, size: 17),
            ],
          ),
          const SizedBox(height: 10),
          AppSurface(
            level: AppSurfaceLevel.standard,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.movie_creation_outlined, color: colors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mediathek',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: () {}, child: const Text('Auswaehlen')),
        ],
      ),
    );
  }
}
