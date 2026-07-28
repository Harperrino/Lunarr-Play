# Masterplan baseline harness

The masterplan performance fixtures are synthetic and contain no provider
credentials or private paths.

Run the opt-in debug-JIT baseline:

```powershell
flutter test test/masterplan_baseline_performance_test.dart `
  --dart-define=MASTERPLAN_PERF=true
```

Run the existing indexed SQLite playlist-switch probe:

```powershell
flutter test test/playlist_switch_performance_test.dart `
  --dart-define=PLAYLIST_SWITCH_PERF=true
```

Release/profile acceptance remains a manual Windows lane over 20 real scope
changes:

- cold p95 at most 500 ms;
- warm p95 at most 150 ms;
- no frame longer than 50 ms.

The synthetic reference sizes are 20,000 import records, 16,940 EPG channel
IDs, and 100,000 sortable channels. Import profiles must accept these reference
fixtures and must define a finite production hard maximum for transport bytes,
expanded bytes, records, field length, persisted rows, and total duration.

Record dated Windows profile results here before comparing later waves. Do not
record usernames, provider URLs, credentials, or absolute private paths.

## 2026-07-26 synthetic debug-JIT baseline

Reference machine result:

| Probe | Records | Duration | Observed RSS delta |
| --- | ---: | ---: | ---: |
| M3U parse | 20,000 | 179 ms | included below |
| Alphabetical sort | 100,000 | 285 ms | included below |
| Numeric sort | 100,000 | 271 ms | included below |
| Combined process delta | — | — | 96,206,848 bytes |

These values validate the harness only. Release/profile results remain the
acceptance source for frame and scope-switch budgets.

## Calibrated production profiles

All values are finite. A limit violation cancels the entire logical sync and
must not publish partial catalogue data.

| Dimension | M3U default / hard | Xtream aggregate default / hard | XMLTV default / hard |
| --- | --- | --- | --- |
| Transport bytes | 64 / 256 MiB | 256 / 512 MiB | 128 / 512 MiB |
| Expanded/decoded bytes | 128 / 512 MiB | 384 / 768 MiB | 1 / 2 GiB |
| Total records | 250k / 1m | 500k / 1m | 2m / 5m programmes |
| Channel/category records | 250k / 1m | 500k / 1m | 250k / 500k channels |
| Single field | 16 / 64 KiB | 16 / 64 KiB | 32 / 128 KiB |
| Persisted rows | 250k / 1m | 500k / 1m | 2.25m / 5.5m |
| Total duration | 10 / 20 min | 10 / 20 min | 20 / 40 min |

The public application uses the default column. Hard values constrain future
advanced profiles and tests; no production path may select an unlimited
profile.

## 2026-07-26 production-budget reference run

The same synthetic fixtures were rerun through the finite production profiles
after Wave 5:

| Probe | Records | Duration |
| --- | ---: | ---: |
| M3U import | 20,000 | 192 ms |
| Xtream aggregate import | 20,000 | 56 ms |
| XMLTV import | 10,000 | 567 ms |
| Alphabetical sort | 100,000 | 300 ms |
| Numeric sort | 100,000 | 244 ms |

The combined RSS delta was 127,881,216 bytes. It is not directly comparable to
the Wave-0 value because this run deliberately retains all three import
datasets instead of only the M3U dataset. The reference run verifies that the
calibrated production limits accept the target fixtures; Windows profile frame
timings remain a Wave-10 release gate.
