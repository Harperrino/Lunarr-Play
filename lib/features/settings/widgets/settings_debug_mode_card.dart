import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_status_pill.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';

class SettingsDebugModeCard extends StatelessWidget {
  const SettingsDebugModeCard({
    required this.isEnabled,
    required this.isLoading,
    required this.compact,
    required this.onChanged,
    super.key,
  });

  final bool isEnabled;
  final bool isLoading;
  final bool compact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackControls = constraints.maxWidth < 520;
          final dense = compact || stackControls;
          final controls = _DebugModeControls(
            isEnabled: isEnabled,
            isLoading: isLoading,
            compact: dense,
            onChanged: onChanged,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              M3SettingsSectionHeader(
                icon: Icons.terminal_rounded,
                iconColor: colors.tertiary,
                title: 'DEBUG MODE',
                description:
                    'Shows the Diagnostics / Logs tab and keeps collecting logs even when hidden.',
                titleSuffix: M3StatusPill(
                  label: isEnabled ? 'Diagnostics on' : 'Hidden',
                  accent: isEnabled
                      ? colors.secondary
                      : colors.onSurfaceVariant,
                ),
                trailing: stackControls ? null : controls,
                compact: dense,
              ),
              if (stackControls) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DebugModeControls extends StatelessWidget {
  const _DebugModeControls({
    required this.isEnabled,
    required this.isLoading,
    required this.compact,
    required this.onChanged,
  });

  final bool isEnabled;
  final bool isLoading;
  final bool compact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: const StadiumBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Switch(value: isEnabled, onChanged: isLoading ? null : onChanged),
          Text(
            isEnabled ? 'Enabled' : 'Disabled',
            style: TextStyle(
              fontSize: compact ? 10.5 : 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
