import 'package:m3uxtream_player/core/database/app_database.dart';

/// Pure channel zapping logic — direction +1 = next, -1 = previous (wrap-around).
///
/// Returns `null` when [channels] is empty or [selected] is not in [channels].
Channel? navigateChannel({
  required List<Channel> channels,
  required Channel? selected,
  required int direction,
}) {
  if (channels.isEmpty) return null;

  final currentIndex = selected != null
      ? channels.indexWhere((c) => c.id == selected.id)
      : -1;

  if (currentIndex == -1 && selected != null) return null;

  final newIndex =
      (currentIndex + direction + channels.length) % channels.length;
  return channels[newIndex];
}
