import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

typedef DiscoveryExternalUrlLauncher = Future<bool> Function(Uri uri);

abstract interface class DiscoveryTrailerLauncher {
  Future<void> open(BuildContext context, {required DiscoveryTrailer trailer});
}

final discoveryTrailerLauncherProvider = Provider<DiscoveryTrailerLauncher>((
  ref,
) {
  return const DefaultDiscoveryTrailerLauncher();
});

class DefaultDiscoveryTrailerLauncher implements DiscoveryTrailerLauncher {
  const DefaultDiscoveryTrailerLauncher({
    this.launchExternalUrl = _launchExternalUrl,
  });

  final DiscoveryExternalUrlLauncher launchExternalUrl;

  @override
  Future<void> open(
    BuildContext context, {
    required DiscoveryTrailer trailer,
  }) async {
    final watchUri = trailer.validatedWatchUri;
    if (watchUri == null) {
      _showOpenFailure(context);
      return;
    }

    var opened = false;
    try {
      opened = await launchExternalUrl(watchUri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) _showOpenFailure(context);
  }
}

Future<bool> _launchExternalUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

void _showOpenFailure(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(context.l10n.discoveryTrailerOpenFailed)),
  );
}
