import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/updates/providers/update_providers.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

class PlayerVersionLabel extends ConsumerWidget {
  const PlayerVersionLabel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(playerPackageInfoProvider).valueOrNull;
    final version = info == null || info.version.isEmpty
        ? context.l10n.playerVersionUnavailable
        : info.version;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        context.l10n.playerVersion(version),
        key: const ValueKey('player-version'),
      ),
    );
  }
}
