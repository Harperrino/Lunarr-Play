import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/seerr_discovery_client.dart';
import 'package:m3uxtream_player/features/discovery/api/tmdb_discovery_client.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_ui_text.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';
import 'package:url_launcher/url_launcher.dart';

class DiscoverySettingsCard extends ConsumerStatefulWidget {
  const DiscoverySettingsCard({super.key, required this.compact});

  final bool compact;

  @override
  ConsumerState<DiscoverySettingsCard> createState() =>
      _DiscoverySettingsCardState();
}

class _DiscoverySettingsCardState extends ConsumerState<DiscoverySettingsCard> {
  final TextEditingController _tmdbToken = TextEditingController();
  final TextEditingController _seerrEndpoint = TextEditingController();
  final TextEditingController _seerrApiKey = TextEditingController();

  DiscoverySource _source = DiscoverySource.tmdb;
  AppStartupDestination _startup = AppStartupDestination.home;
  bool _initialized = false;
  bool _saving = false;
  bool _testing = false;
  bool _showTmdbToken = false;
  bool _showSeerrKey = false;
  String? _connectionMessage;
  Object? _connectionError;

  @override
  void dispose() {
    _tmdbToken.dispose();
    _seerrEndpoint.dispose();
    _seerrApiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(discoveryPreferencesProvider);
    final secretsAsync = ref.watch(discoverySecretsProvider);
    final preferences = preferencesAsync.valueOrNull;
    final secrets = secretsAsync.valueOrNull;
    if (!_initialized && preferences != null && secrets != null) {
      _initialized = true;
      _source = preferences.source;
      _startup = preferences.startupDestination;
      _seerrEndpoint.text = preferences.seerrEndpoint;
    }

    final colors = Theme.of(context).colorScheme;
    final busy = _saving || _testing || preferences == null || secrets == null;
    final insecure = _source == DiscoverySource.seerr && _usesHttpEndpoint();

    return AppSurface(
      key: const ValueKey('discovery-settings-card'),
      level: AppSurfaceLevel.standard,
      padding: EdgeInsets.all(widget.compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3SettingsSectionHeader(
            icon: Icons.explore_rounded,
            iconColor: colors.tertiary,
            title: context.l10n.discoverySettingsTitle,
            description: context.l10n.discoverySettingsDescription,
            compact: widget.compact,
          ),
          SizedBox(height: widget.compact ? 14 : 18),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              M3DropdownField<DiscoverySource>(
                key: const ValueKey('discovery-source-dropdown'),
                value: _source,
                width: 260,
                label: Text(context.l10n.discoverySettingsSource),
                leadingIcon: const Icon(Icons.hub_rounded),
                entries: [
                  DropdownMenuEntry(
                    value: DiscoverySource.tmdb,
                    label: context.l10n.discoverySourceTmdb,
                    leadingIcon: const Icon(Icons.public_rounded),
                  ),
                  DropdownMenuEntry(
                    value: DiscoverySource.seerr,
                    label: context.l10n.discoverySourceSeerr,
                    leadingIcon: const Icon(Icons.dns_rounded),
                  ),
                ],
                onSelected: busy
                    ? (_) {}
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _source = value;
                          _connectionMessage = null;
                          _connectionError = null;
                        });
                      },
              ),
              M3DropdownField<AppStartupDestination>(
                key: const ValueKey('discovery-startup-dropdown'),
                value: _startup,
                width: 260,
                label: Text(context.l10n.discoverySettingsStartupDestination),
                leadingIcon: const Icon(Icons.start_rounded),
                entries: [
                  DropdownMenuEntry(
                    value: AppStartupDestination.home,
                    label: context.l10n.discoverySettingsStartupHome,
                  ),
                  DropdownMenuEntry(
                    value: AppStartupDestination.live,
                    label: context.l10n.discoverySettingsStartupLive,
                  ),
                ],
                onSelected: busy
                    ? (_) {}
                    : (value) {
                        if (value != null) setState(() => _startup = value);
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_source == DiscoverySource.tmdb)
            _secretField(
              key: const ValueKey('discovery-tmdb-token-field'),
              controller: _tmdbToken,
              label: context.l10n.discoverySettingsTmdbToken,
              hint: secrets?.hasTmdbToken == true
                  ? context.l10n.discoverySettingsSecretStored
                  : context.l10n.discoverySettingsTmdbTokenHint,
              visible: _showTmdbToken,
              onToggleVisibility: () =>
                  setState(() => _showTmdbToken = !_showTmdbToken),
              hasStoredSecret: secrets?.hasTmdbToken == true,
              onClearStored: () => _clearSecret(tmdb: true),
            )
          else ...[
            TextField(
              key: const ValueKey('discovery-seerr-endpoint-field'),
              controller: _seerrEndpoint,
              enabled: !busy,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {
                _connectionMessage = null;
                _connectionError = null;
              }),
              decoration: InputDecoration(
                labelText: context.l10n.discoverySettingsSeerrEndpoint,
                hintText: context.l10n.discoverySettingsSeerrEndpointHint,
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _secretField(
              key: const ValueKey('discovery-seerr-key-field'),
              controller: _seerrApiKey,
              label: context.l10n.discoverySettingsSeerrApiKey,
              hint: secrets?.hasSeerrApiKey == true
                  ? context.l10n.discoverySettingsSecretStored
                  : context.l10n.discoverySettingsSeerrApiKeyHint,
              visible: _showSeerrKey,
              onToggleVisibility: () =>
                  setState(() => _showSeerrKey = !_showSeerrKey),
              hasStoredSecret: secrets?.hasSeerrApiKey == true,
              onClearStored: () => _clearSecret(tmdb: false),
            ),
            const SizedBox(height: 12),
            _Notice(
              icon: Icons.admin_panel_settings_rounded,
              text: context.l10n.discoverySettingsAdminKeyWarning,
              color: colors.tertiary,
            ),
            if (insecure) ...[
              const SizedBox(height: 8),
              _Notice(
                icon: Icons.no_encryption_gmailerrorred_rounded,
                text: context.l10n.discoverySettingsHttpWarning,
                color: colors.error,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              context.l10n.discoverySettingsMinimumVersion,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.lock_rounded,
            text: context.l10n.discoverySettingsSecretsInfo,
            color: colors.primary,
          ),
          if (_connectionMessage != null || _connectionError != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _connectionError == null
                    ? _connectionMessage!
                    : discoveryFailureText(context.l10n, _connectionError!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _connectionError == null
                      ? colors.primary
                      : colors.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : _testConnection,
                icon: _testing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded),
                label: Text(context.l10n.discoverySettingsTestConnection),
              ),
              FilledButton.icon(
                onPressed: busy ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(context.l10n.discoverySettingsSave),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            context.l10n.discoveryCreditsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              link: true,
              label: context.l10n.discoveryTmdbLogoSemantics,
              child: InkWell(
                onTap: () => launchUrl(Uri.https('www.themoviedb.org', '/')),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SvgPicture.asset(
                    'assets/branding/tmdb-blue-short.svg',
                    width: 180,
                    semanticsLabel: context.l10n.discoveryTmdbLogoSemantics,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.discoveryTmdbAttribution,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _secretField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool visible,
    required VoidCallback onToggleVisibility,
    required bool hasStoredSecret,
    required VoidCallback onClearStored,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: !_saving && !_testing,
    obscureText: !visible,
    enableSuggestions: false,
    autocorrect: false,
    onChanged: (_) => setState(() {
      _connectionMessage = null;
      _connectionError = null;
    }),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: const Icon(Icons.key_rounded),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: visible
                ? context.l10n.discoverySettingsHideSecretTooltip
                : context.l10n.discoverySettingsShowSecretTooltip,
            onPressed: onToggleVisibility,
            icon: Icon(
              visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            ),
          ),
          if (hasStoredSecret)
            IconButton(
              tooltip: context.l10n.discoverySettingsClearSecretTooltip,
              onPressed: onClearStored,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    ),
  );

  bool _usesHttpEndpoint() {
    final raw = _seerrEndpoint.text.trim();
    if (raw.isEmpty) return false;
    try {
      return normalizeSeerrApiBase(raw).scheme == 'http';
    } catch (_) {
      return false;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _connectionError = null;
      _connectionMessage = null;
    });
    try {
      final preferences = ref.read(discoveryPreferencesProvider.notifier);
      await preferences.setSource(_source);
      await preferences.setStartupDestination(_startup);
      await preferences.setSeerrEndpoint(_seerrEndpoint.text);
      final secrets = ref.read(discoverySecretsProvider.notifier);
      if (_tmdbToken.text.trim().isNotEmpty) {
        await secrets.setTmdbToken(_tmdbToken.text);
        _tmdbToken.clear();
      }
      if (_seerrApiKey.text.trim().isNotEmpty) {
        await secrets.setSeerrApiKey(_seerrApiKey.text);
        _seerrApiKey.clear();
      }
      ref.invalidate(discoveryHomeProvider);
      ref.read(discoverySearchProvider.notifier).clear();
      if (!mounted) return;
      setState(() => _connectionMessage = context.l10n.discoverySettingsSaved);
    } catch (error) {
      if (mounted) setState(() => _connectionError = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _connectionError = null;
      _connectionMessage = null;
    });
    try {
      final stored = await ref.read(discoverySecretsProvider.future);
      final http = ref.read(discoveryHttpClientProvider);
      if (_source == DiscoverySource.tmdb) {
        final token = _tmdbToken.text.trim().isNotEmpty
            ? _tmdbToken.text.trim()
            : stored.tmdbToken;
        await TmdbDiscoveryClient(
          httpClient: http,
          readAccessToken: token,
        ).testConnection();
        if (mounted) {
          setState(
            () => _connectionMessage = context.l10n.discoverySettingsConnected,
          );
        }
      } else {
        final key = _seerrApiKey.text.trim().isNotEmpty
            ? _seerrApiKey.text.trim()
            : stored.seerrApiKey;
        final result = await SeerrDiscoveryClient(
          httpClient: http,
          endpoint: _seerrEndpoint.text,
          apiKey: key,
        ).testConnection();
        if (mounted) {
          setState(
            () => _connectionMessage = context.l10n
                .discoverySettingsConnectedVersion(result.version),
          );
        }
      }
    } catch (error) {
      if (mounted) setState(() => _connectionError = error);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clearSecret({required bool tmdb}) async {
    try {
      if (tmdb) {
        await ref.read(discoverySecretsProvider.notifier).setTmdbToken('');
        _tmdbToken.clear();
      } else {
        await ref.read(discoverySecretsProvider.notifier).setSeerrApiKey('');
        _seerrApiKey.clear();
      }
      ref.invalidate(discoveryHomeProvider);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _connectionError = error);
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
    ],
  );
}
