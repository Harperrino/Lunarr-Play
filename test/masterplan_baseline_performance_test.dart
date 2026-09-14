import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/imports/import_budget.dart';
import 'package:m3uxtream_player/core/imports/import_profiles.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/parsers/epg_parser.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/core/services/channel_sorting.dart';

import 'support/masterplan_fixtures.dart';

const _runMasterplanBaseline = bool.fromEnvironment('MASTERPLAN_PERF');

void main() {
  test(
    'masterplan synthetic import and sorting baseline',
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !_runMasterplanBaseline,
    () async {
      final rssBefore = ProcessInfo.currentRss;

      final m3uSource = syntheticM3u();
      final m3uBudget = ImportBudget(limits: ImportProfiles.m3u)
        ..consumeTransportBytes(
          utf8.encode(m3uSource).length,
          phase: 'm3u_transport',
        )
        ..consumeDecodedBytes(
          utf8.encode(m3uSource).length,
          phase: 'm3u_decode',
        );
      final m3uWatch = Stopwatch()..start();
      final parsed = M3uParser.parse(m3uSource, budget: m3uBudget);
      m3uWatch.stop();
      expect(parsed, hasLength(masterplanLargeImportRecordCount));

      final xtreamSource = syntheticXtreamStreams();
      final xtreamBudget = ImportBudget(limits: ImportProfiles.xtream)
        ..consumeTransportBytes(
          utf8.encode(xtreamSource).length,
          phase: 'xtream_transport',
          endpoint: 'live_streams',
        )
        ..consumeDecodedBytes(
          utf8.encode(xtreamSource).length,
          phase: 'xtream_decode',
        );
      final xtreamWatch = Stopwatch()..start();
      final xtream = XtreamParser.parseLiveStreams(
        streamsJsonStr: xtreamSource,
        categoriesJsonStr: '[]',
        host: 'https://example.invalid',
        username: 'synthetic-user',
        password: 'synthetic-pass',
        budget: xtreamBudget,
      );
      xtreamWatch.stop();
      expect(xtream, hasLength(masterplanLargeImportRecordCount));

      final xmltvSource = syntheticXmltv();
      final xmltvBytes = utf8.encode(xmltvSource);
      final xmltvBudget = ImportBudget(limits: ImportProfiles.xmltv)
        ..consumeTransportBytes(xmltvBytes.length, phase: 'xmltv_transport');
      final xmltvWatch = Stopwatch()..start();
      final xmltv = await EpgParser.parse(
        byteStream: Stream.value(xmltvBytes),
        isGzipped: false,
        budget: xmltvBudget,
      );
      xmltvWatch.stop();
      expect(xmltv.entries, hasLength(10000));
      expect(xmltv.channels, hasLength(1000));

      final channels = syntheticChannels(
        playlistId: 1,
        count: masterplanSortChannelCount,
      );
      final alphabeticalWatch = Stopwatch()..start();
      final alphabetical = sortChannels(channels, ChannelSortMode.alphabetical);
      alphabeticalWatch.stop();
      expect(alphabetical, hasLength(masterplanSortChannelCount));

      final numericWatch = Stopwatch()..start();
      final numeric = sortChannels(channels, ChannelSortMode.numeric);
      numericWatch.stop();
      expect(numeric, hasLength(masterplanSortChannelCount));

      final rssAfter = ProcessInfo.currentRss;
      // Machine-readable single-line output for comparison in the Windows
      // profile lane. These are observations, not debug-JIT release gates.
      // ignore: avoid_print
      print({
        'm3uRecords': parsed.length,
        'm3uMs': m3uWatch.elapsedMilliseconds,
        'xtreamRecords': xtream.length,
        'xtreamMs': xtreamWatch.elapsedMilliseconds,
        'xmltvRecords': xmltv.entries.length,
        'xmltvMs': xmltvWatch.elapsedMilliseconds,
        'sortRecords': channels.length,
        'alphabeticalMs': alphabeticalWatch.elapsedMilliseconds,
        'numericMs': numericWatch.elapsedMilliseconds,
        'rssDeltaBytes': rssAfter - rssBefore,
      });
    },
  );
}
