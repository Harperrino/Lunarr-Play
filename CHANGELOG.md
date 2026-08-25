# Changelog

## 1.0.0

Lunarr Player 1.0 is the first stable, feature-complete Windows release. It
combines M3U/Xtream IPTV, Jellyfin playback and TMDB/Seerr discovery in a
single Material 3 Expressive desktop application while keeping every major
area modular and optional.

### Highlights

- M3U and Xtream-compatible Live TV, VOD and series libraries with catalogue
  sorting, dynamic playlist activation, top-bar switching, favorites, Watch
  Later, hidden or pinned categories and global Live TV search.
- Multiple Jellyfin servers and user profiles, full library browsing,
  Direct-Play-first playback, selectable audio tracks, resume, season/episode
  navigation and top-bar account switching.
- Jellyfin trickplay previews, configurable relative seeking, intro/recap skip
  buttons or automatic skipping, and outro-aware endcards with configurable
  next-episode autoplay when the server supplies the required metadata.
- TMDB discovery and search plus optional Seerr discovery, availability and
  request flows. Both services can be configured and switched from Home;
  validated trailer links open in the system browser.
- Bundled MPV/libmpv playback and all required Windows runtime files in one
  portable archive: extract the ZIP and start `lunarr_one.exe`.
- A responsive Material 3 Expressive interface with adjustable accent/surface
  colors, the optional Lunarr ambient background, hideable tabs, high contrast,
  reduced motion, keyboard navigation and large-text support.
- Configurable Live TV startup buffering and VOD pre-buffering, stream fallback
  policies, audio-track selection and stereo compatibility controls.
- Local-first privacy: sensitive values are masked in settings, diagnostics and
  logs; Jellyfin credentials and discovery API keys use Windows DPAPI-backed
  secret storage and are never logged.

### Stability and maintenance

- Bounded Jellyfin, EPG and catalogue caches reduce tab-switch work without
  keeping inactive tabs mounted.
- Startup maintenance is serialized and deferred around tab changes and player
  opens; routine logging no longer adds unnecessary release-console work.
- Player controls share one responsive Material 3 chrome while Xtream and
  Jellyfin retain separate controllers, lifecycle and stream policies.
- Discovery navigation, search, source switching and refresh now live in the
  common window top bar, leaving the Home feed more vertical space.

### Project status

- Version 1.0 is considered feature complete. Ongoing development prioritizes
  bug fixes and maintenance; future features remain selective.
- Windows x64 is the supported release platform. Android smartphone/foldable
  support is the next planned platform effort. iOS and macOS are no longer
  project targets.

### Updating

- Existing 0.9.x and 0.10.x local databases, playlists, settings, favorites,
  Watch Later entries and playback progress remain compatible.
- Replace the complete previous application folder with the contents of the
  new portable ZIP. Do not copy only the executable.
- The Windows build is not code-signed, so SmartScreen may show a warning.

## 0.10.0 RC1

This release turns Lunarr Player into a combined IPTV and Jellyfin desktop
client while keeping both integrations modular and independently configurable.

### Jellyfin libraries and accounts

- Connect multiple Jellyfin servers or users and switch profiles from the
  account selector beside the search field.
- Connection profiles persist locally, while signing out and switching servers
  cleanly reset the active Jellyfin session.
- Browse server libraries from a dedicated Material 3 sidebar with Overview,
  Continue Watching, Next Up and recently added shelves.
- Hide the Jellyfin tab completely when it is not used. All primary navigation
  tabs except Settings can now be enabled or disabled individually.

### Details and artwork

- New responsive Material 3 movie, series and episode detail pages with
  backdrops, posters, descriptions, genres, people and technical metadata.
- IMDb and TMDb provider IDs open their corresponding external pages instead
  of being shown as ratings. Jellyfin community and critic ratings remain
  clearly labelled.
- Posters keep a consistent 2:3 crop without stretching, including library and
  Continue Watching shelves.
- Series use a compact season dropdown instead of rendering every season at
  once.

### Jellyfin playback

- Direct Play is preferred whenever the server reports a compatible source;
  Direct Stream or transcoding is used only as the server-selected fallback.
- A dedicated media_kit player shares Lunarr's Material 3 control language,
  rounded video surface, volume, mute, seek and fullscreen behavior.
- Resume actions now open playback at the stored position.
- Previous/next episode actions and an expandable in-player episode picker
  make continuous series playback easier.
- Fullscreen covers the complete app window and automatically hides its chrome
  after inactivity while restoring controls on mouse or keyboard input.

### Reliability, privacy and tooling

- HTTP playlist imports finish reading before their client is closed, avoiding
  truncated responses and ensuring asynchronous failures use the intended
  cleanup path.
- Repository ignore rules now cover local credentials, environment files,
  keys, databases, diagnostics, dumps and editor-specific workspace state.
- Windows release packaging excludes Flutter's intermediate native-assets
  manifest so absolute local build paths are not shipped in portable archives.
- Updated the project baseline to Flutter 3.47, Dart 3.13 and current compatible
  Drift, SQLite, Google Fonts and build tooling releases.
- Expanded Jellyfin, player, responsive-layout, accessibility, database and
  privacy regression coverage. The release gate passes 930 tests with three
  explicitly skipped opt-in performance tests.

### Updating

- Existing 0.9.x playlists, settings, favorites, Watch Later entries and
  playback progress remain available.
- Replace the complete previous application folder with the contents of the
  new portable ZIP. Do not copy only the executable.
- The Windows build is not code-signed, so SmartScreen may show a warning.

## 0.9.1 RC2

RC2 makes large libraries faster to browse, fixes playlist and programme-guide
mix-ups, and introduces the final Lunarr Player branding.

### Highlights

- Final layered moon logo and matching Lunarr Player wordmark in the app,
  Windows executable and GitHub project.
- Much faster switching between playlists after their first load.
- A responsive “All active playlists” view that combines enabled sources
  without hanging.
- Inactive playlists can be opened temporarily without silently enabling them.
- Alphabetical and numeric sorting no longer freezes the interface on very
  large channel lists.

### Programme guide

- Programme data is now kept separate for every playlist. Providers using the
  same channel IDs can no longer overwrite or display each other's schedule.
- The guide loads as one current snapshot, reducing repeated database work and
  stale results while switching playlists or time ranges.
- Short programmes retain their correct visual duration without overlapping
  the next programme.

### Imports and privacy

- Large M3U, Xtream and XMLTV imports now have safe resource limits,
  cancellation and atomic updates, so a rejected import cannot leave a
  half-replaced library.
- Diagnostics redact credentials, private URLs and local paths before they
  reach logs, the UI or copied reports.
- Error messages remain useful without exposing provider credentials.

### Interface and accessibility

- English UI text is now managed through a localization system, providing the
  foundation for additional languages.
- Narrow layouts, high contrast, reduced motion, keyboard focus and large text
  received additional regression coverage.
- Playlist selection, active status and the playlist-management screen now
  behave as separate, predictable controls.

### Updating

- Existing Beta 5 and RC1 playlists, settings, favorites and playback progress
  remain available.
- Replace the complete previous application folder with the contents of the
  new portable ZIP. Do not copy only the executable.
- The Windows build is not code-signed, so SmartScreen may show a warning.

## 0.9.0 RC1

LUNARR One introduced the product identity used by that Windows release
candidate. The application adopted a neutral Material 3 moon-and-screen mark
as its Windows icon and displayed the same mark beside a centered LUNARR One
wordmark in the desktop sidebar.

The release includes the responsive Material 3 redesign, favorites and Watch
Later libraries, pinned and hidden category management, improved VOD/series and
EPG experiences, high-contrast and reduced-motion modes, large-text layout
hardening, narrower state watches, debounced catalogue search and lazy category
rendering.

Player open, playback, fallback, seek, audio and recovery behavior are unchanged.
RC1 retains the Beta-5 `v2` database and its persisted settings.
