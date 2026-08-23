import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tab_labels.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';
import 'package:m3uxtream_player/shared/providers/shell_tab_visibility_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';

/// Lets users declutter the shell while keeping Settings as the safe fallback.
class ShellTabVisibilitySettingsCard extends ConsumerWidget {
  const ShellTabVisibilitySettingsCard({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenAsync = ref.watch(hiddenShellTabKindsProvider);
    final hidden = hiddenAsync.valueOrNull ?? const <ShellTabKind>{};
    final debugEnabled = ref.watch(debugModeProvider).valueOrNull ?? false;
    final tabs = shellVisibleTabs(debugModeEnabled: debugEnabled)
        .where((tab) => tab.kind != ShellTabKind.settings)
        .toList(growable: false);
    final controller = ref.read(hiddenShellTabKindsProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return AppSurface(
      key: const ValueKey('shell-tab-visibility-settings-card'),
      level: AppSurfaceLevel.standard,
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3SettingsSectionHeader(
            icon: Icons.tab_rounded,
            iconColor: colors.secondary,
            title: context.l10n.shellTabVisibilityTitle,
            description: context.l10n.shellTabVisibilityDescription,
            compact: compact,
            trailing: TextButton.icon(
              onPressed: hidden.isEmpty || hiddenAsync.isLoading
                  ? null
                  : controller.reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 17),
              label: Text(context.l10n.shellTabVisibilityReset),
            ),
          ),
          const SizedBox(height: 12),
          for (final tab in tabs)
            SwitchListTile(
              key: ValueKey('shell-tab-visibility-${tab.kind.name}'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(tab.icon, color: colors.onSurfaceVariant),
              title: Text(shellTabTitle(tab, context.l10n)),
              value: !hidden.contains(tab.kind),
              onChanged: hiddenAsync.isLoading
                  ? null
                  : (visible) => controller.setVisible(tab.kind, visible),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.l10n.shellTabVisibilitySettingsAlwaysVisible,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
