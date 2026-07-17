import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

import 'vod_poster_image.dart';

/// Material 3 Expressive card used only by the VOD movie catalogue.
///
/// The optional [posterAction] keeps feature actions outside this shared card
/// primitive so it remains usable without a provider scope in isolation.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.isSelected = false,
    this.posterAction,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool isSelected;
  final Widget? posterAction;

  @override
  Widget build(BuildContext context) {
    final accent = GroupAccent.forGroup(channel.groupName ?? 'Movies');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: [
            MediaPosterFrame(
              semanticLabel: 'Film: ${channel.name}',
              isSelected: isSelected,
              onActivate: onTap,
              poster: VodPosterImage(logoUrl: channel.logo, accent: accent),
            ),
            if (posterAction != null)
              Positioned(top: 8, right: 8, child: posterAction!),
          ],
        ),
        const SizedBox(height: 8),
        MediaMetadataRow(title: channel.name, subtitle: channel.groupName),
      ],
    );
  }
}
