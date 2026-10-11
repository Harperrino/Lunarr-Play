import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:m3uxtream_player/features/updates/providers/update_providers.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

class UpdateAvailableButton extends ConsumerWidget {
  const UpdateAvailableButton({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(startupUpdateProvider).valueOrNull;
    if (release == null) return const SizedBox.shrink();
    Future<void> openRelease() async {
      var opened = false;
      try {
        opened = await launchUrl(
          release.url,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        // The user receives a message if no browser can open the release page.
      }
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.playerUpdateOpenFailed)),
        );
      }
    }

    final tooltip = context.l10n.playerUpdateVersion(release.version);
    if (compact) {
      return IconButton(
        key: const ValueKey('player-update-available'),
        tooltip: tooltip,
        color: Theme.of(context).colorScheme.primary,
        onPressed: openRelease,
        icon: const Icon(Icons.system_update_alt_rounded),
      );
    }
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        key: const ValueKey('player-update-available'),
        icon: const Icon(Icons.system_update_alt_rounded, size: 18),
        label: Text(
          context.l10n.playerUpdateAvailable,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: openRelease,
      ),
    );
  }
}
