import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

import 'vod_poster_image.dart';

export 'vod_poster_image.dart' show vodPosterAspectRatio;

/// Backward-compatible movie poster card for older catalogue callers.
class VodCard extends StatelessWidget {
  const VodCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.isSelected = false,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final accent = GroupAccent.forGroup(channel.groupName ?? 'Movies');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaPosterFrame(
          semanticLabel: context.l10n.movieCardSemantics(channel.name),
          isSelected: isSelected,
          onActivate: onTap,
          poster: VodPosterImage(logoUrl: channel.logo, accent: accent),
        ),
        const SizedBox(height: 8),
        MediaMetadataRow(title: channel.name, subtitle: channel.groupName),
      ],
    );
  }
}
