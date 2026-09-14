import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_reminder_logic.dart';

Playlist _playlist({
  required int id,
  String? epgUrl,
  DateTime? epgLastSyncedAt,
  DateTime? lastSyncedAt,
}) {
  return Playlist(
    id: id,
    name: 'Test',
    type: 'm3u',
    urlOrHost: 'http://example.com/list.m3u',
    username: null,
    password: null,
    createdAt: DateTime(2024, 1, 1),
    lastSyncedAt: lastSyncedAt,
    epgUrl: epgUrl,
    epgLastSyncedAt: epgLastSyncedAt,
  );
}

void main() {
  group('EPG reminder logic', () {
    test('shows when epgUrl set and epg never synced', () {
      final playlist = _playlist(
        id: 1,
        epgUrl: 'http://epg.example.com/xml.gz',
        lastSyncedAt: DateTime(2025, 6, 1),
      );

      expect(
        shouldShowEpgReminder(
          playlist: playlist,
          isDismissed: false,
          selectedPlaylistId: 1,
        ),
        isTrue,
      );
    });

    test('shows when playlist synced after last EPG sync', () {
      final playlist = _playlist(
        id: 1,
        epgUrl: 'http://epg.example.com/xml.gz',
        epgLastSyncedAt: DateTime(2025, 6, 1, 10),
        lastSyncedAt: DateTime(2025, 6, 1, 12),
      );

      expect(
        shouldShowEpgReminder(
          playlist: playlist,
          isDismissed: false,
          selectedPlaylistId: 1,
        ),
        isTrue,
      );
    });

    test('hidden when dismissed', () {
      final playlist = _playlist(
        id: 1,
        epgUrl: 'http://epg.example.com/xml.gz',
      );

      expect(
        shouldShowEpgReminder(
          playlist: playlist,
          isDismissed: true,
          selectedPlaylistId: 1,
        ),
        isFalse,
      );
    });

    test('hidden when no epgUrl', () {
      final playlist = _playlist(id: 1, lastSyncedAt: DateTime(2025, 6, 1));

      expect(
        shouldShowEpgReminder(
          playlist: playlist,
          isDismissed: false,
          selectedPlaylistId: 1,
        ),
        isFalse,
      );
    });

    test('hidden when EPG synced after playlist sync', () {
      final playlist = _playlist(
        id: 1,
        epgUrl: 'http://epg.example.com/xml.gz',
        epgLastSyncedAt: DateTime(2025, 6, 1, 14),
        lastSyncedAt: DateTime(2025, 6, 1, 12),
      );

      expect(
        shouldShowEpgReminder(
          playlist: playlist,
          isDismissed: false,
          selectedPlaylistId: 1,
        ),
        isFalse,
      );
    });

    test('hidden when selected playlist differs', () {
      final playlist = _playlist(
        id: 1,
        epgUrl: 'http://epg.example.com/xml.gz',
      );

      expect(
        shouldShowEpgReminder(
          playlist: playlist,
          isDismissed: false,
          selectedPlaylistId: 2,
        ),
        isFalse,
      );
    });

    test('resolveEpgReminderPlaylistId returns id when reminder needed', () {
      final playlist = _playlist(
        id: 42,
        epgUrl: 'http://epg.example.com/xml.gz',
        lastSyncedAt: DateTime(2025, 6, 1),
      );

      expect(
        resolveEpgReminderPlaylistId(playlist: playlist, isDismissed: false),
        42,
      );
    });

    test('resolveEpgReminderPlaylistId returns null when dismissed', () {
      final playlist = _playlist(
        id: 42,
        epgUrl: 'http://epg.example.com/xml.gz',
      );

      expect(
        resolveEpgReminderPlaylistId(playlist: playlist, isDismissed: true),
        isNull,
      );
    });
  });
}
