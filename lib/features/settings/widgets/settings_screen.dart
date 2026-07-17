import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/playlist_form_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/playback_settings_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_debug_mode_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/appearance_settings_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_layout.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_form.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_section.dart';
import 'package:m3uxtream_player/shared/widgets/status_snack_bar.dart';

/// Provider-aware Settings adapter. Presentation is delegated to small widgets.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsPlaylistFormMode _formMode = SettingsPlaylistFormMode.m3u;

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _epgUrlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _epgUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listenSyncErrors();
    _listenFormResults();
    _listenEpgSyncFeedback();

    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final inactivePlaylistIdsAsync = ref.watch(inactivePlaylistIdsProvider);
    final formAsync = ref.watch(playlistFormNotifierProvider);
    final syncAsync = ref.watch(playlistSyncNotifierProvider);
    final epgSyncAsync = ref.watch(epgSyncNotifierProvider);
    final debugModeAsync = ref.watch(debugModeProvider);
    final isBusy =
        formAsync.isLoading || syncAsync.isLoading || epgSyncAsync.isLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 760;
        final playlists = playlistsAsync.valueOrNull;
        final inactiveIds =
            inactivePlaylistIdsAsync.valueOrNull ?? const <int>{};

        return SettingsLayout(
          topSection: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsDebugModeCard(
                isEnabled: debugModeAsync.valueOrNull ?? false,
                isLoading: debugModeAsync.isLoading,
                compact: compact,
                onChanged: (value) =>
                    ref.read(debugModeProvider.notifier).setEnabled(value),
              ),
              SizedBox(height: compact ? 12 : 16),
              PlaybackSettingsCard(compact: compact),
              SizedBox(height: compact ? 12 : 16),
              AppearanceSettingsCard(compact: compact),
            ],
          ),
          playlistForm: SettingsPlaylistForm(
            mode: _formMode,
            nameController: _nameController,
            urlController: _urlController,
            hostController: _hostController,
            usernameController: _usernameController,
            passwordController: _passwordController,
            epgUrlController: _epgUrlController,
            isBusy: isBusy,
            compact: compact,
            onModeChanged: (mode) => setState(() => _formMode = mode),
            onSubmit: _submitForm,
          ),
          playlistSection: SettingsPlaylistSection(
            items: playlists
                ?.map(
                  (playlist) => SettingsPlaylistItem(
                    name: playlist.name,
                    type: playlist.type,
                    isActive: !inactiveIds.contains(playlist.id),
                    lastSyncedAt: playlist.lastSyncedAt,
                    epgUrl: playlist.epgUrl,
                    epgLastSyncedAt: playlist.epgLastSyncedAt,
                    onSync: () => ref
                        .read(playlistSyncNotifierProvider.notifier)
                        .sync(playlist.id),
                    onEpgSync: () => ref
                        .read(epgSyncNotifierProvider.notifier)
                        .sync(playlist.id),
                    onEdit: () => _editPlaylist(context, playlist),
                    onActiveChanged: (active) =>
                        _togglePlaylistActive(playlists, playlist, active),
                    onDelete: () => _confirmDelete(context, playlist),
                  ),
                )
                .toList(),
            isLoading: playlistsAsync.isLoading,
            errorMessage: playlistsAsync.whenOrNull(
              error: (error, _) => '$error',
            ),
            isSyncing: syncAsync.isLoading,
            isEpgSyncing: epgSyncAsync.isLoading,
            isBusy: isBusy,
            compact: compact,
          ),
        );
      },
    );
  }

  void _listenSyncErrors() {
    ref.listen(playlistSyncNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: 'Sync failed: $error',
              tone: AppStatusSnackBarTone.error,
            ),
          );
        },
      );
    });
  }

  void _listenFormResults() {
    ref.listen(playlistFormNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: 'Operation failed: $error',
              tone: AppStatusSnackBarTone.error,
            ),
          );
        },
      );
    });
  }

  void _listenEpgSyncFeedback() {
    ref.listen(epgSyncNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: 'EPG updated successfully.',
              tone: AppStatusSnackBarTone.success,
            ),
          );
        },
        error: (error, _) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: 'EPG sync failed: $error',
              tone: AppStatusSnackBarTone.error,
            ),
          );
        },
      );
    });
  }

  Future<void> _submitForm() async {
    final notifier = ref.read(playlistFormNotifierProvider.notifier);
    PlaylistFormResult result;

    try {
      if (_formMode == SettingsPlaylistFormMode.m3u) {
        result = await notifier.addM3uPlaylist(
          name: _nameController.text,
          urlOrPath: _urlController.text,
        );
      } else {
        result = await notifier.addXtreamPlaylist(
          name: _nameController.text,
          host: _hostController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          epgUrl: _epgUrlController.text,
        );
      }
    } catch (_) {
      return;
    }

    if (!mounted) return;
    switch (result) {
      case PlaylistFormValidationError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          appStatusSnackBar(
            context,
            message: message,
            tone: AppStatusSnackBarTone.warning,
          ),
        );
      case PlaylistFormSuccess(:final playlistName):
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          appStatusSnackBar(
            context,
            message: 'Playlist "$playlistName" added and synced.',
            tone: AppStatusSnackBarTone.success,
          ),
        );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _urlController.clear();
    _hostController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _epgUrlController.clear();
  }

  Future<void> _confirmDelete(BuildContext context, Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          'Delete "${playlist.name}" and all its channels? This cannot be undone.',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(playlistFormNotifierProvider.notifier)
          .deletePlaylist(playlist.id);
      if (!mounted) return;
      messenger.showSnackBar(
        appStatusSnackBar(
          this.context,
          message: 'Playlist "${playlist.name}" deleted.',
          tone: AppStatusSnackBarTone.success,
        ),
      );
    } catch (e) {
      AppLogger.error('SettingsScreen: Delete failed', e);
      if (!mounted) return;
      messenger.showSnackBar(
        appStatusSnackBar(
          this.context,
          message: 'Delete failed: $e',
          tone: AppStatusSnackBarTone.error,
        ),
      );
    }
  }

  Future<void> _togglePlaylistActive(
    List<Playlist> playlists,
    Playlist playlist,
    bool active,
  ) async {
    final selectedChannel = ref.read(selectedChannelProvider);
    if (!active &&
        selectedChannel != null &&
        selectedChannel.playlistId == playlist.id) {
      ref.read(selectedChannelProvider.notifier).state = null;
      AppLogger.info(
        'SettingsScreen: Cleared active channel (playlist deactivated).',
      );
    }
    await ref
        .read(inactivePlaylistIdsProvider.notifier)
        .setActive(playlist.id, active);
    final inactiveIds =
        ref.read(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
    normalizeSelectedPlaylist(ref, playlists, inactiveIds);
  }

  Future<void> _editPlaylist(BuildContext context, Playlist playlist) async {
    final updatedName = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _EditPlaylistDialog(playlist: playlist),
    );
    if (!mounted || updatedName == null) return;

    ScaffoldMessenger.of(this.context).showSnackBar(
      appStatusSnackBar(
        this.context,
        message: 'Playlist "$updatedName" updated.',
        tone: AppStatusSnackBarTone.success,
      ),
    );
  }
}

/// Owns the edit form's controllers for exactly as long as the dialog route is
/// mounted. A dialog pop completes before its exit animation is unmounted, so
/// disposing controllers in the caller immediately after `showDialog` returns
/// leaves TextFields listening to already-disposed controllers.
class _EditPlaylistDialog extends ConsumerStatefulWidget {
  const _EditPlaylistDialog({required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<_EditPlaylistDialog> createState() =>
      _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends ConsumerState<_EditPlaylistDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _sourceController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _epgUrlController;
  bool _isSaving = false;

  bool get _isXtream => widget.playlist.type == 'xtream';

  @override
  void initState() {
    super.initState();
    final playlist = widget.playlist;
    _nameController = TextEditingController(text: playlist.name);
    _sourceController = TextEditingController(text: playlist.urlOrHost);
    _usernameController = TextEditingController(text: playlist.username ?? '');
    _passwordController = TextEditingController(text: playlist.password ?? '');
    _epgUrlController = TextEditingController(text: playlist.epgUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sourceController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _epgUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final result = await ref
          .read(playlistFormNotifierProvider.notifier)
          .updatePlaylist(
            playlistId: widget.playlist.id,
            type: widget.playlist.type,
            name: _nameController.text,
            urlOrPath: _sourceController.text,
            username: _isXtream ? _usernameController.text : null,
            password: _isXtream ? _passwordController.text : null,
            epgUrl: _isXtream ? _epgUrlController.text : null,
          );
      if (!mounted) return;

      switch (result) {
        case PlaylistFormValidationError(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: message,
              tone: AppStatusSnackBarTone.warning,
            ),
          );
          setState(() => _isSaving = false);
        case PlaylistFormSuccess():
          Navigator.of(context).pop(_nameController.text.trim());
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appStatusSnackBar(
          context,
          message: 'Update failed: $error',
          tone: AppStatusSnackBarTone.error,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.playlist.type.toUpperCase()} playlist'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsTextField(
                controller: _nameController,
                label: 'Name',
                enabled: !_isSaving,
              ),
              const SizedBox(height: 14),
              SettingsTextField(
                controller: _sourceController,
                label: _isXtream ? 'Host' : 'URL or file path',
                hint: _isXtream
                    ? 'http://provider.example.com:8080'
                    : 'https://example.com/playlist.m3u',
                enabled: !_isSaving,
              ),
              if (_isXtream) ...[
                const SizedBox(height: 14),
                SettingsTextField(
                  controller: _usernameController,
                  label: 'Username',
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 14),
                SettingsTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: true,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 14),
                SettingsTextField(
                  controller: _epgUrlController,
                  label: 'EPG URL (optional)',
                  hint: 'https://example.com/epg.xml.gz',
                  enabled: !_isSaving,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
