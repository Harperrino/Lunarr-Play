/// Automatic EPG refresh cadence persisted per playlist.
enum EpgRefreshInterval {
  manual,
  hours6,
  hours12,
  hours24;

  String get label => switch (this) {
    EpgRefreshInterval.manual => 'Manuell',
    EpgRefreshInterval.hours6 => 'Alle 6 Stunden',
    EpgRefreshInterval.hours12 => 'Alle 12 Stunden',
    EpgRefreshInterval.hours24 => 'Alle 24 Stunden',
  };

  Duration? get duration => switch (this) {
    EpgRefreshInterval.manual => null,
    EpgRefreshInterval.hours6 => const Duration(hours: 6),
    EpgRefreshInterval.hours12 => const Duration(hours: 12),
    EpgRefreshInterval.hours24 => const Duration(hours: 24),
  };

  bool get isAutomatic => duration != null;

  String get storageValue => name;

  static EpgRefreshInterval fromStorage(String? value) {
    return switch (value) {
      'hours6' => EpgRefreshInterval.hours6,
      'hours12' => EpgRefreshInterval.hours12,
      'hours24' => EpgRefreshInterval.hours24,
      _ => EpgRefreshInterval.manual,
    };
  }
}
