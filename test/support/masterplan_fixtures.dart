import 'dart:convert';

import 'package:m3uxtream_player/core/database/app_database.dart';

const masterplanEpgChannelCount = 16940;
const masterplanSortChannelCount = 100000;
const masterplanLargeImportRecordCount = 20000;

List<Channel> syntheticChannels({
  required int playlistId,
  required int count,
  String channelType = 'live',
}) {
  return List<Channel>.generate(
    count,
    (index) => Channel(
      id: playlistId * 1000000 + index + 1,
      playlistId: playlistId,
      name: 'Channel ${(count - index).toString().padLeft(6, '0')}',
      streamUrl: 'https://example.invalid/$playlistId/$index',
      groupName: 'Group ${(index % 250).toString().padLeft(3, '0')}',
      channelNumber: '${index + 1}',
      providerOrder: index,
      isFavorite: false,
      isWatchLater: false,
      channelType: channelType,
    ),
  );
}

String syntheticM3u({int count = masterplanLargeImportRecordCount}) {
  final buffer = StringBuffer('#EXTM3U\n');
  for (var index = 0; index < count; index++) {
    buffer
      ..writeln(
        '#EXTINF:-1 tvg-id="shared-$index" '
        'group-title="Group ${index % 250}",Channel $index',
      )
      ..writeln('https://example.invalid/live/$index.ts');
  }
  return buffer.toString();
}

String syntheticXmltv({
  int channelCount = 1000,
  int programmesPerChannel = 10,
}) {
  final buffer = StringBuffer('<?xml version="1.0"?><tv>');
  for (var channel = 0; channel < channelCount; channel++) {
    buffer
      ..write('<channel id="shared-$channel"><display-name>')
      ..write('Channel $channel')
      ..write('</display-name></channel>');
  }
  for (var channel = 0; channel < channelCount; channel++) {
    for (var slot = 0; slot < programmesPerChannel; slot++) {
      final startHour = slot.toString().padLeft(2, '0');
      final endHour = (slot + 1).toString().padLeft(2, '0');
      buffer
        ..write(
          '<programme channel="shared-$channel" '
          'start="20260726${startHour}0000 +0000" '
          'stop="20260726${endHour}0000 +0000">',
        )
        ..write('<title>Programme $channel/$slot</title></programme>');
    }
  }
  buffer.write('</tv>');
  return buffer.toString();
}

String syntheticXtreamStreams({int count = masterplanLargeImportRecordCount}) {
  return jsonEncode(
    List<Map<String, Object?>>.generate(
      count,
      (index) => {
        'stream_id': index + 1,
        'name': 'Stream $index',
        'category_id': '${index % 250}',
        'stream_icon': 'https://example.invalid/icon/$index.png',
        'epg_channel_id': 'shared-$index',
      },
    ),
  );
}
