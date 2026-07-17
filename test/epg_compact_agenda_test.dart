import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_compact_agenda.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

Channel _channel() => const Channel(
  id: 1,
  playlistId: 1,
  streamId: null,
  name: 'Testkanal',
  logo: null,
  groupName: 'Tests',
  tvgId: 'example.channel',
  streamUrl: 'https://example.invalid/live.m3u8',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'live',
  lastWatchedPosition: null,
  duration: null,
  lastWatchedAt: null,
);

EpgEntry _entry({
  required int id,
  required String title,
  required DateTime start,
  required DateTime end,
}) => EpgEntry(
  id: id,
  channelId: 'example.channel',
  title: title,
  description: null,
  startTime: start,
  endTime: end,
);

EpgGridRowData _row(DateTime now) => EpgGridRowData(
  channel: _channel(),
  matchStatus: EpgMatchStatus.matched,
  resolvedEpgChannelId: 'example.channel',
  programs: [
    _entry(
      id: 1,
      title: 'Laufende Sendung',
      start: now.subtract(const Duration(minutes: 10)),
      end: now.add(const Duration(minutes: 20)),
    ),
    _entry(
      id: 2,
      title: 'Nächste Sendung',
      start: now.add(const Duration(minutes: 20)),
      end: now.add(const Duration(minutes: 50)),
    ),
  ],
);

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: child),
  ),
);

void main() {
  test('compact agenda breakpoint keeps desktop at 720 logical pixels', () {
    expect(usesEpgCompactAgenda(719), isTrue);
    expect(usesEpgCompactAgenda(720), isFalse);
    expect(usesEpgCompactAgenda(1200), isFalse);
  });

  testWidgets('responsive body selects agenda only below desktop breakpoint', (
    tester,
  ) async {
    for (final layout in <({double width, Key expected})>[
      (width: 719, expected: const ValueKey('compact-child')),
      (width: 720, expected: const ValueKey('desktop-child')),
    ]) {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: layout.width,
            height: 300,
            child: const EpgAgendaResponsiveBody(
              compactChild: SizedBox(key: ValueKey('compact-child')),
              desktopChild: SizedBox(key: ValueKey('desktop-child')),
            ),
          ),
        ),
      );

      expect(find.byKey(layout.expected), findsOneWidget);
    }
  });

  testWidgets('agenda exposes live, now and next status at 200% text scale', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime(2026, 7, 13, 10, 30);
    Channel? tapped;

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 360,
          height: 640,
          child: EpgCompactAgenda(
            rows: [_row(now)],
            now: now,
            onChannelTap: (channel) => tapped = channel,
          ),
        ),
        textScale: 2,
      ),
    );

    expect(find.byKey(const ValueKey('epg-compact-agenda')), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('JETZT: Laufende Sendung'), findsOneWidget);
    expect(find.text('Danach: Nächste Sendung'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('LIVE')).style?.color,
      AppTheme.darkTheme.extension<AppStatusColors>()!.onLiveContainer,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('Sender: Testkanal. LIVE, läuft jetzt: Laufende Sendung'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('epg-compact-agenda-row-1')));
    expect(tapped, _channel());
    semantics.dispose();
  });

  test('compact activation preserves select, open, then Live-tab order', () {
    final calls = <String>[];
    final channel = _channel();

    activateEpgChannel(
      channel: channel,
      onSelectChannel: (selected) => calls.add('select:${selected.id}'),
      onOpenStream: (url) => calls.add('open:$url'),
      onShowLiveTab: () => calls.add('live-tab'),
    );

    expect(calls, ['select:1', 'open:${channel.streamUrl}', 'live-tab']);
  });

  test(
    'current and next agenda entries respect exact start and end bounds',
    () {
      final firstStart = DateTime(2026, 7, 13, 10);
      final firstEnd = firstStart.add(const Duration(minutes: 30));
      final secondEnd = firstEnd.add(const Duration(minutes: 30));
      final thirdEnd = secondEnd.add(const Duration(minutes: 30));
      final programmes = [
        _entry(id: 1, title: 'Erste Sendung', start: firstStart, end: firstEnd),
        _entry(id: 2, title: 'Grenzsendung', start: firstEnd, end: secondEnd),
        _entry(id: 3, title: 'Dritte Sendung', start: secondEnd, end: thirdEnd),
      ];

      expect(currentProgramAt(programmes, firstStart)?.title, 'Erste Sendung');
      expect(
        epgAgendaNextProgramme(programmes, firstStart)?.title,
        'Grenzsendung',
      );

      expect(currentProgramAt(programmes, firstEnd)?.title, 'Grenzsendung');
      expect(
        epgAgendaNextProgramme(programmes, firstEnd)?.title,
        'Dritte Sendung',
      );

      expect(currentProgramAt(programmes, secondEnd)?.title, 'Dritte Sendung');
      expect(currentProgramAt(programmes, thirdEnd), isNull);
      expect(epgAgendaNextProgramme(programmes, thirdEnd), isNull);
    },
  );
}
