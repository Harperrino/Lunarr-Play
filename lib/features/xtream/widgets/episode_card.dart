import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';

/// Tonal, interactive presentation for a single series episode.
///
/// The owner keeps episode selection and preparation outside this widget.
class EpisodeCard extends StatefulWidget {
  const EpisodeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  Set<WidgetState> get _states => <WidgetState>{
    if (_hovered) WidgetState.hovered,
    if (_focused) WidgetState.focused,
    if (_pressed) WidgetState.pressed,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Episode: ${widget.title}',
      onTap: widget.onTap,
      child: AppSurface(
        level: AppSurfaceLevel.low,
        elevation: AppElevation.level1,
        elevationBehavior: AppElevationBehavior.elevatedCard,
        states: _states,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          excludeFromSemantics: true,
          onTap: widget.onTap,
          onHover: (value) {
            if (_hovered != value) setState(() => _hovered = value);
          },
          onFocusChange: (value) {
            if (_focused != value) setState(() => _focused = value);
          },
          onHighlightChanged: (value) {
            if (_pressed != value) setState(() => _pressed = value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: ShapeDecoration(
                    color: colors.secondaryContainer,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 16,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MediaMetadataRow(
                    title: widget.title,
                    subtitle: widget.subtitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
