# pubspec.yaml — Dependency Policy & Re-Pin Guide

**Status:** Verifiziert & gepinnt (Dependency-Refresh abgeschlossen, 17. Juli 2026 — Analyse, 594 Tests, Datenbankvertrag und Windows Build OK)

---

## Regel für Coding-Agenten

1. **`pubspec.yaml` ist FROZEN** — Agenten dürfen sie **nicht** ändern, es sei denn, der User-Prompt erlaubt es **explizit** (z. B. „Re-Pin“ oder „Package X hinzufügen“).
2. **Kein `^`, kein `any`** bei direkten Dependencies — nur exakte Versionen.
3. **`dart:ffi` ist SDK-Built-in** — das Pub-Package `ffi` **nicht** manuell hinzufügen (kommt transitiv).
4. Nach **jeder** genehmigten pubspec-Änderung zwingend:
   ```powershell
   flutter pub get
   dart run build_runner build   # wenn drift/drift_dev geändert
   flutter analyze
   flutter test
   flutter build windows
   ```
5. **`pubspec.lock` mit committen** — hält transitive Versionen stabil.
6. Aktuelle Mindest-Toolchain: Dart `>=3.12.2`, Flutter `>=3.44.4`.

---

## Verifizierte Pins (Runtime) — maßgeblich

| Package | Version | Anmerkung |
|---|---|---|
| `flutter_riverpod` | 2.6.1 | Höchste aktuell sauber lösbare 2.x-Version; Riverpod 3.3.2 ist durch Test-/Analyzer-/Generator-Konflikt blockiert |
| `media_kit` | 1.2.6 | Media-Welle nach Beta 4 |
| `media_kit_video` | 2.0.1 | Aktuelle Version; Windows Platform-Thread-Fix aus 1.3.1 enthalten |
| `media_kit_libs_windows_video` | 1.0.11 | niemals `any` |
| `media_kit_libs_ios_video` | 1.1.4 | |
| `drift` | 2.34.2 | Aktuelles kompatibles Patch-Release; Datenbankvertrag unverändert |
| `sqlite3` | 3.4.0 | Direkt gepinnt; Windows nutzt die Native-Asset-SQLite-Kette |
| `path_provider` | 2.1.6 | Wave 1b upgrade |
| `path` | 1.9.1 | SDK erzwingt ≥1.9.1 via flutter_test |
| `window_manager` | 0.5.2 | Nicht-Riverpod-Patch-Welle; zweite Instanz/Fokuslogik bleibt unverändert |
| `flutter_single_instance` | 1.7.0 | Nutzt unter Windows RPC-Fokus auf die laufende Hauptinstanz; macOS benoetigt vor Support eine separate Entitlements-Entscheidung |
| `cached_network_image` | 3.4.1 | Wave 1d upgrade (smtc_windows-Entfernung hat uuid-Blocker geloest) |
| `shimmer` | 3.0.0 | |
| `lucide_icons_flutter` | 3.1.15 | Aktuelles kompatibles Patch-Release |
| `google_fonts` | 8.2.0 | Aktuelles kompatibles Patch-Release |
| `xml` | 7.0.1 | Wave 1c upgrade |
| `logger` | 2.7.0 | Wave 1b upgrade |

Wichtige transitive Media-Auflösung:

- `wakelock_plus: 1.6.1`
- `package_info_plus: 10.2.1`
- `package_info_plus_platform_interface: 4.1.0`
- `win32: 6.3.0`
- `ffi_leak_tracker: 0.1.2`
- `safe_local_storage: 2.0.4`
- `uri_parser: 3.0.2`
- `screen_retriever: 0.2.2` plus Windows/macOS/Linux/platform-interface-Pakete
- `code_assets: 1.2.1`, `native_toolchain_c: 0.19.2`
- `sqflite: 2.4.3`, `uuid: 4.6.0`
- `volume_controller` und sämtliche `screen_brightness`-Pakete sind seit
  `media_kit_video 2.0.1` nicht mehr enthalten.
- `sqlite3_flutter_libs` ist seit der Drift-/SQLite-Welle nicht mehr
  enthalten. Der Clean Windows Release Build enthält genau eine `sqlite3.dll`
  im Release-Ordner sowie eine Native-Asset-Kopie unter
  `build/native_assets/windows`.

## Verifizierte Pins (dev_dependencies)

| Package | Version | Anmerkung |
|---|---|---|
| `flutter_lints` | 6.0.0 | Nicht-Riverpod-Patch-Welle; erzeugte nur kleine mechanische Info-Fixes |
| `build_runner` | 2.15.1 | 2.15.2 ist durch Flutter-SDK-Pin `meta 1.18.0` blockiert; alter `--delete-conflicting-outputs`-Parameter nicht mehr verwenden |
| `drift_dev` | 2.34.4 | zu `drift` 2.34.2 passend |

---

## Removed Dead Dependencies (2026-06-17)

Diese Packages hatten **0 Code-Imports** im gesamten Projekt und wurden als Ballast entfernt.

| Package | Version | Grund | Wirkung |
|---|---|---|---|
| `smtc_windows` | 0.1.2 | 0 Imports. Kein SMTC-Code. | Unblockt `cached_network_image` 3.4.x. |
| `system_tray` | 2.0.3 | 0 Imports. Kein System-Tray-Code. | Keine. |
| `fl_pip` | 3.2.1 | 0 Imports. iOS PiP nicht implementiert. | Keine. |
| `connectivity_plus` | 6.1.5 | 0 Imports. Weder lib noch test. | Entfernte `flutter_rust_bridge`-Transitivkette. |
| `riverpod_annotation` | 2.3.5 | Keine `@riverpod`-/`@Riverpod`-Nutzung. | Generator-Konflikt entfernt. |
| `riverpod_generator` | 2.4.0 | Keine generierten Riverpod-Provider. | Generator-Konflikt entfernt. |
| `freezed_annotation` | 2.4.1 | Keine `@freezed`-Modelle im Projekt. | Nur noch transitiv über `flutter_single_instance`. |
| `freezed` | 2.5.2 | Keine Freezed-Codegenerierung. | Generator-Konflikt entfernt. |
| `json_annotation` | 4.9.0 | Keine direkte JsonSerializable-Nutzung. | Bleibt bei Bedarf transitiv. |
| `json_serializable` | 6.8.0 | Keine JsonSerializable-Codegenerierung. | Generator-Konflikt entfernt. |
| `sqlite3_flutter_libs` | 0.5.42 | Drift nutzt nun die `sqlite3`-Native-Asset-Kette. | Entfernt in Drift-/SQLite-Welle 3. |

11 transitive Pakete wurden mit den Dead Deps aus dem Lockfile entfernt.

Verifikation: `flutter analyze` clean, `flutter test` 289 passed, `flutter build windows` OK.

---

## Bekannte Konflikte (nicht blind alte Handover-Werte pinne!)

| Altes Ziel | Problem | Aktuelle Lösung |
|---|---|---|
| `drift: 2.16.0` | alte SQLite-/Generator-Kette | `drift: 2.34.2` mit `sqlite3: 3.4.0` |
| `sqlite3_flutter_libs: 0.5.24+3` | Version existiert nicht auf pub.dev; Paket ist inzwischen entfernt | `sqlite3: 3.3.4` |
| `media_kit_libs_*: 1.0.9+1 / 1.0.6` | nicht mehr auf pub.dev | `1.0.11` / `1.1.4` |
| `flutter_single_instance: 1.7.0` | braucht `window_manager ^0.5` | Gemeinsam auf `1.7.0` / `0.5.1` aktualisiert |
| `cached_network_image: 3.4.1` | uuid-Konflikt mit `smtc_windows` | `smtc_windows` entfernt (2026-06-17). Wave 1d: Upgrade auf 3.4.1 erfolgreich. |
| `connectivity_plus: 6.0.3` | web-Konflikt mit `drift ≥2.19` | Paket entfernt (2026-06-17), da 0 Code-Imports |
| `ffi` als Dependency | unnötig | `dart:ffi` in Tests |
| `build_runner: 2.15.2` | benötigt `meta ^1.18.3`, Flutter 3.44.4 pinnt über `flutter_test` exakt `meta 1.18.0` | `build_runner: 2.15.1` bis zum Flutter-SDK-Upgrade |
| `flutter_riverpod: 3.3.2` | Major-Migration; bestehender Test-/Analyzer-/Generatorvertrag ist auf Riverpod 2.x verifiziert | `flutter_riverpod: 2.6.1`; separate Migrationswelle erforderlich |

---

## Re-Pin Prompt (Copy-Paste für Agenten)

```
@memory.md @PUBSPEC_POLICY.md

## Aufgabe: pubspec.yaml Re-Pin (NUR auf explizite User-Anweisung)

Stelle pubspec.yaml auf die exakten Versionen aus PUBSPEC_POLICY.md wieder her.
Entferne alle ^-Wildcards und alle any-Einträge.

Regeln:
- NUR pubspec.yaml ändern — kein Feature-Code
- Keine neuen Packages hinzufügen
- Keine Version raten — Tabelle in PUBSPEC_POLICY.md ist maßgeblich
- Nach Änderung: flutter pub get → build_runner (bei drift, ohne `--delete-conflicting-outputs`) → analyze → test → build windows
- pubspec.lock aktualisieren (User committet)
- `project_notes/devlog.md` am Ende aktualisieren

Wenn pub get oder build windows fehlschlägt: STOP, dokumentieren, nicht improvisieren.
```
