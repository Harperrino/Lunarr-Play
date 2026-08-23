import 'package:material_ui/material_ui.dart';

/// Canonical application branding bundled with every Lunarr Player build.
abstract final class AppBrandAssets {
  static const logo = 'assets/branding/lunarr-player-logo.png';
  static const wordmark = 'assets/branding/lunarr-player-wordmark.png';
}

/// Standalone Lunarr Player moon mark.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.size = 28,
    this.semanticLabel = 'Lunarr Player',
  });

  static const imageKey = ValueKey('app-brand-logo-image');

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        AppBrandAssets.logo,
        key: imageKey,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

/// Full Lunarr Player logo and lettering for prominent brand surfaces.
class AppBrandWordmark extends StatelessWidget {
  const AppBrandWordmark({
    super.key,
    required this.width,
    this.semanticLabel = 'Lunarr Player',
  });

  static const imageKey = ValueKey('app-brand-wordmark-image');
  static const aspectRatio = 2048 / 682;

  final double width;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width / aspectRatio,
      child: Image.asset(
        AppBrandAssets.wordmark,
        key: imageKey,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
