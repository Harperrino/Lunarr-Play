import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// Layout constants for the EPG grid timeline.
const double epgGridChannelColumnWidth = 160;
const double epgGridRowHeight = 56;
const double epgGridPixelsPerMinuteDefault = 2;
const double epgGridPixelsPerMinuteMin = 0.75;
const double epgGridPixelsPerMinuteMax = 12;
const double epgGridPixelsPerMinute = epgGridPixelsPerMinuteDefault;
const int epgGridSlotMinutes = 30;
const double epgGridSlotResizeHandleWidth = 8;

/// User-adjustable horizontal zoom (pixels per minute) for the EPG timeline.
final epgGridPixelsPerMinuteProvider = StateProvider<double>(
  (ref) => epgGridPixelsPerMinuteDefault,
);

double epgGridSlotWidth(double pixelsPerMinute) =>
    epgGridSlotMinutes * pixelsPerMinute;

void setEpgGridPixelsPerMinute(WidgetRef ref, double pixelsPerMinute) {
  ref.read(epgGridPixelsPerMinuteProvider.notifier).state = pixelsPerMinute
      .clamp(epgGridPixelsPerMinuteMin, epgGridPixelsPerMinuteMax);
}

void adjustEpgGridPixelsPerMinute(WidgetRef ref, double deltaPixelsPerMinute) {
  final current = ref.read(epgGridPixelsPerMinuteProvider);
  setEpgGridPixelsPerMinute(ref, current + deltaPixelsPerMinute);
}

/// One row in the EPG grid — channel + resolved programmes.
class EpgGridRowData {
  const EpgGridRowData({
    required this.channel,
    required this.matchStatus,
    required this.resolvedEpgChannelId,
    required this.programs,
  });

  final Channel channel;
  final EpgMatchStatus matchStatus;
  final String? resolvedEpgChannelId;
  final List<EpgEntry> programs;
}

/// Groups EPG entries by XMLTV channel ID, sorted by start time.
Map<String, List<EpgEntry>> groupEpgEntriesByChannelId(List<EpgEntry> entries) {
  final map = <String, List<EpgEntry>>{};
  for (final entry in entries) {
    map.putIfAbsent(entry.channelId, () => []).add(entry);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  return map;
}

/// Case-insensitive lookup map for XMLTV channel IDs.
Map<String, String> buildEpgDataLookupKeys(
  Map<String, List<EpgEntry>> epgData,
) {
  final lookup = <String, String>{};
  for (final key in epgData.keys) {
    lookup[key.toLowerCase()] = key;
  }
  return lookup;
}

/// Looks up programmes for [resolvedId] with case-insensitive fallback.
List<EpgEntry> programsForResolvedId(
  Map<String, List<EpgEntry>> epgData,
  String resolvedId, {
  Map<String, String>? lookupKeys,
}) {
  final direct = epgData[resolvedId];
  if (direct != null) return direct;

  final canonical = lookupKeys?[resolvedId.toLowerCase()];
  if (canonical != null) return epgData[canonical] ?? const [];

  for (final entry in epgData.entries) {
    if (entry.key.toLowerCase() == resolvedId.toLowerCase()) {
      return entry.value;
    }
  }
  return const [];
}

/// Builds per-channel match results — used by tests and providers.
Map<int, EpgChannelMatchResult> buildChannelMatches({
  required List<Channel> channels,
  required Set<String> knownEpgChannelIds,
  Map<String, List<String>> displayNamesByChannelId = const {},
  EpgMatchingIndex? matchingIndex,
}) {
  final index =
      matchingIndex ??
      EpgMatchingIndex(
        knownEpgChannelIds: knownEpgChannelIds,
        displayNamesByChannelId: displayNamesByChannelId,
      );

  return {
    for (final channel in channels) channel.id: index.matchChannel(channel),
  };
}

/// Builds grid row data for each channel in the active playlist.
List<EpgGridRowData> buildEpgGridRows({
  required List<Channel> channels,
  required Map<String, List<EpgEntry>> epgData,
  required Map<int, EpgChannelMatchResult> channelMatches,
}) {
  final lookupKeys = buildEpgDataLookupKeys(epgData);

  return channels.map((channel) {
    final match =
        channelMatches[channel.id] ??
        const EpgChannelMatchResult(matchStatus: EpgMatchStatus.noTvgId);
    final resolvedId = match.resolvedEpgChannelId;
    final programs = resolvedId != null
        ? programsForResolvedId(epgData, resolvedId, lookupKeys: lookupKeys)
        : const <EpgEntry>[];

    return EpgGridRowData(
      channel: channel,
      matchStatus: match.matchStatus,
      resolvedEpgChannelId: resolvedId,
      programs: programs,
    );
  }).toList();
}

/// Shifts the EPG window by [delta].
void shiftEpgWindow(WidgetRef ref, Duration delta) {
  final start = ref.read(epgWindowStartProvider);
  final end = ref.read(epgWindowEndProvider);
  ref.read(epgWindowStartProvider.notifier).state = start.add(delta);
  ref.read(epgWindowEndProvider.notifier).state = end.add(delta);
}

/// Jumps the window to now-centered range and scrolls the timeline.
void jumpEpgWindowToNow(WidgetRef ref) {
  final now = DateTime.now();
  ref.read(epgWindowStartProvider.notifier).state = epgGridWindowStartAroundNow(
    now,
  );
  ref.read(epgWindowEndProvider.notifier).state = epgGridWindowEndAroundNow(
    now,
  );
  ref.read(epgGridScrollToNowTickProvider.notifier).state++;
}

/// Same channel pool as the Live tab (respects group filter).
final epgGridChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channels = ref.watch(filteredChannelsProvider);
  final sorted = List<Channel>.from(channels);
  sorted.sort((a, b) {
    final groupA = a.groupName ?? '';
    final groupB = b.groupName ?? '';
    final groupCompare = groupA.compareTo(groupB);
    if (groupCompare != 0) return groupCompare;
    return a.name.compareTo(b.name);
  });
  return sorted;
});

/// Resolved XMLTV IDs for the active playlist — derived from [epgChannelMatchesProvider].
final epgGridResolvedChannelIdsProvider = Provider.autoDispose<Set<String>>((
  ref,
) {
  final matches = ref.watch(epgChannelMatchesProvider);
  return matches.values
      .map((match) => match.resolvedEpgChannelId)
      .whereType<String>()
      .toSet();
});

/// Single reactive bulk query for all matched channels in the window.
final epgGridEntriesStreamProvider = StreamProvider.autoDispose<List<EpgEntry>>(
  (ref) {
    if (ref.watch(selectedPlaylistIdProvider) == null) {
      return Stream.value(const []);
    }

    ref.watch(epgSyncNotifierProvider);

    final knownIds = ref.watch(knownEpgChannelIdsProvider).valueOrNull;
    if (knownIds == null) {
      return Stream.value(const []);
    }

    final start = ref.watch(epgWindowStartProvider);
    final end = ref.watch(epgWindowEndProvider);
    final resolvedIds = ref.watch(epgGridResolvedChannelIdsProvider);

    if (resolvedIds.isEmpty) {
      return Stream.value(const []);
    }

    return ref
        .read(epgRepositoryProvider)
        .watchEntriesInRangeForChannelIds(resolvedIds.toList(), start, end);
  },
);

Duration epgGridMinuteTickDelay([DateTime? now]) {
  final current = now ?? DateTime.now();
  final elapsed = Duration(
    seconds: current.second,
    milliseconds: current.millisecond,
    microseconds: current.microsecond,
  );
  final remaining = const Duration(minutes: 1) - elapsed;
  return remaining == Duration.zero ? const Duration(minutes: 1) : remaining;
}

/// Visible-only minute tick used to keep the EPG now-line fresh while the grid is mounted.
final epgGridMinuteTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  late final StreamController<DateTime> controller;
  Timer? timer;

  void scheduleTick() {
    if (controller.isClosed) return;
    final now = DateTime.now();
    controller.add(now);
    timer?.cancel();
    timer = Timer(epgGridMinuteTickDelay(now), scheduleTick);
  }

  controller = StreamController<DateTime>(
    onListen: scheduleTick,
    onCancel: () => timer?.cancel(),
  );

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Programmes keyed by XMLTV channel id within the active window.
final epgGridDataProvider = Provider.autoDispose<Map<String, List<EpgEntry>>>((
  ref,
) {
  final entries =
      ref.watch(epgGridEntriesStreamProvider).valueOrNull ?? const [];
  return groupEpgEntriesByChannelId(entries);
});

/// Combined row model for the grid UI.
final epgGridRowsProvider = Provider.autoDispose<List<EpgGridRowData>>((ref) {
  final channels = ref.watch(epgGridChannelsProvider);
  final epgData = ref.watch(epgGridDataProvider);
  final channelMatches = ref.watch(epgChannelMatchesProvider);
  return buildEpgGridRows(
    channels: channels,
    epgData: epgData,
    channelMatches: channelMatches,
  );
});

/// True when at least one grid row has EPG programmes in the active window.
bool epgGridHasVisibleProgrammes(List<EpgGridRowData> rows) {
  return rows.any((row) => row.programs.isNotEmpty);
}

/// True when rows exist that should have EPG (matched to XMLTV catalogue).
bool epgGridHasMatchedChannels(List<EpgGridRowData> rows) {
  return rows.any((row) => row.matchStatus == EpgMatchStatus.matched);
}

/// Current time marker for the now-line (rebuilt when window or tick changes).
final epgGridNowMarkerProvider = Provider.autoDispose<DateTime>((ref) {
  ref.watch(epgGridMinuteTickProvider);
  ref.watch(epgWindowStartProvider);
  ref.watch(epgGridScrollToNowTickProvider);
  return DateTime.now();
});

/// Increment to trigger horizontal scroll-to-now in [EpgGrid].
final epgGridScrollToNowTickProvider = StateProvider<int>((ref) => 0);

/// Timeline width in logical pixels for the active window.
double epgGridTimelineWidth(
  DateTime windowStart,
  DateTime windowEnd, {
  double pixelsPerMinute = epgGridPixelsPerMinuteDefault,
}) {
  final minutes = windowEnd.difference(windowStart).inMinutes;
  return minutes * pixelsPerMinute;
}

/// Horizontal pixel offset for [time] within the window.
double epgGridTimeToOffset(
  DateTime windowStart,
  DateTime time, {
  double pixelsPerMinute = epgGridPixelsPerMinuteDefault,
}) {
  return time.difference(windowStart).inMinutes * pixelsPerMinute;
}

/// Layout for a programme block clipped to the visible EPG window.
({double left, double width, int durationMin}) epgProgrammeLayout({
  required DateTime windowStart,
  required DateTime windowEnd,
  required EpgEntry entry,
  double pixelsPerMinute = epgGridPixelsPerMinuteDefault,
}) {
  final visibleStart = entry.startTime.isBefore(windowStart)
      ? windowStart
      : entry.startTime;
  final visibleEnd = entry.endTime.isAfter(windowEnd)
      ? windowEnd
      : entry.endTime;

  if (!visibleEnd.isAfter(visibleStart)) {
    return (left: 0, width: 0, durationMin: 0);
  }

  final left = epgGridTimeToOffset(
    windowStart,
    visibleStart,
    pixelsPerMinute: pixelsPerMinute,
  );
  final durationMin = visibleEnd.difference(visibleStart).inMinutes;
  final width = (durationMin * pixelsPerMinute).clamp(48.0, double.infinity);

  return (left: left, width: width, durationMin: durationMin);
}

/// Programmes overlapping the window — skips blocks entirely outside the range.
List<EpgEntry> epgEntriesVisibleInWindow(
  List<EpgEntry> programs,
  DateTime windowStart,
  DateTime windowEnd,
) {
  return programs
      .where(
        (entry) =>
            entry.endTime.isAfter(windowStart) &&
            entry.startTime.isBefore(windowEnd),
      )
      .toList();
}

/// IPTV/XMLTV feeds often ship staggered duplicate slots for the same show.
/// Collapses temporally overlapping entries so the grid lays out one tile per slot.
List<EpgEntry> epgEntriesForGridDisplay(List<EpgEntry> programs) {
  if (programs.length <= 1) return programs;

  final sorted = List<EpgEntry>.from(programs)
    ..sort((a, b) {
      final byStart = a.startTime.compareTo(b.startTime);
      if (byStart != 0) return byStart;
      return b.endTime.compareTo(a.endTime);
    });

  final result = <EpgEntry>[];
  for (final entry in sorted) {
    if (result.isEmpty) {
      result.add(entry);
      continue;
    }
    final last = result.last;
    if (entry.startTime.isBefore(last.endTime)) {
      continue;
    }
    result.add(entry);
  }
  return result;
}

/// Visible programmes in the window, deduplicated for grid layout.
List<EpgEntry> epgEntriesVisibleForGrid(
  List<EpgEntry> programs,
  DateTime windowStart,
  DateTime windowEnd,
) {
  return epgEntriesForGridDisplay(
    epgEntriesVisibleInWindow(programs, windowStart, windowEnd),
  );
}

/// Currently airing programme within [programs], if any.
EpgEntry? currentProgramAt(List<EpgEntry> programs, DateTime now) {
  for (final program in programs) {
    if (!program.startTime.isAfter(now) && program.endTime.isAfter(now)) {
      return program;
    }
  }
  return null;
}

/// Second line under the channel name — mirrors Live tab „Jetzt:" label.
String epgGridRowSubtitle(EpgGridRowData row, DateTime now) {
  if (row.matchStatus != EpgMatchStatus.matched) return 'Kein EPG';

  final current = currentProgramAt(epgEntriesForGridDisplay(row.programs), now);
  if (current != null) return 'Jetzt: ${current.title}';
  if (row.programs.isEmpty) return 'Kein Programm';
  return row.channel.groupName ?? '';
}
