import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/playlist_epg.dart';
import 'package:m3uxtream_player/app/providers/playlist_form_providers.dart';
import 'package:m3uxtream_player/features/playlists/widgets/playlist_form.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

Future<void> showPlaylistAddDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PlaylistAddDialog(),
  );
}

Future<void> showPlaylistEditDialog(BuildContext context, Playlist playlist) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PlaylistEditDialog(playlist: playlist),
  );
}

class _PlaylistAddDialog extends ConsumerStatefulWidget {
  const _PlaylistAddDialog();

  @override
  ConsumerState<_PlaylistAddDialog> createState() => _PlaylistAddDialogState();
}

class _PlaylistAddDialogState extends ConsumerState<_PlaylistAddDialog> {
  PlaylistFormMode _mode = PlaylistFormMode.m3u;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _host = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _epg = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _host.dispose();
    _username.dispose();
    _password.dispose();
    _epg.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(playlistFormNotifierProvider.notifier);
    try {
      final result = _mode == PlaylistFormMode.m3u
          ? await notifier.addM3uPlaylist(
              name: _name.text,
              urlOrPath: _url.text,
              epgUrlOverride: _epg.text,
            )
          : await notifier.addXtreamPlaylist(
              name: _name.text,
              host: _host.text,
              username: _username.text,
              password: _password.text,
              epgUrl: _epg.text,
            );
      if (!mounted) return;
      switch (result) {
        case PlaylistFormValidationError(:final message):
          _showMessage(message);
        case PlaylistFormSuccess():
          Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context.l10n.playlistDialogCreateFailed(error.toString()));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(playlistFormNotifierProvider).isLoading;
    return AlertDialog(
      title: Text(context.l10n.playlistDialogAddTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 560),
        child: SingleChildScrollView(
          child: PlaylistForm(
            mode: _mode,
            nameController: _name,
            urlController: _url,
            hostController: _host,
            usernameController: _username,
            passwordController: _password,
            epgUrlController: _epg,
            isBusy: busy,
            compact: true,
            showSubmitButton: false,
            onModeChanged: (mode) => setState(() => _mode = mode),
            onSubmit: _submit,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.playlistDialogCancel),
        ),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Text(context.l10n.playlistDialogAddAndSync),
        ),
      ],
    );
  }
}

class _PlaylistEditDialog extends ConsumerStatefulWidget {
  const _PlaylistEditDialog({required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<_PlaylistEditDialog> createState() =>
      _PlaylistEditDialogState();
}

class _PlaylistEditDialogState extends ConsumerState<_PlaylistEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _source;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _override;

  @override
  void initState() {
    super.initState();
    final playlist = widget.playlist;
    _name = TextEditingController(text: playlist.name);
    _source = TextEditingController(text: playlist.urlOrHost);
    _username = TextEditingController(text: playlist.username ?? '');
    _password = TextEditingController(text: playlist.password ?? '');
    _override = TextEditingController(text: playlist.epgUrlOverride ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _source.dispose();
    _username.dispose();
    _password.dispose();
    _override.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await ref
        .read(playlistFormNotifierProvider.notifier)
        .updatePlaylist(
          playlistId: widget.playlist.id,
          type: widget.playlist.type,
          name: _name.text,
          urlOrPath: _source.text,
          username: widget.playlist.type == 'xtream' ? _username.text : null,
          password: widget.playlist.type == 'xtream' ? _password.text : null,
          epgUrl: _override.text,
        );
    if (!mounted) return;
    switch (result) {
      case PlaylistFormValidationError(:final message):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      case PlaylistFormSuccess():
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(playlistFormNotifierProvider).isLoading;
    final playlist = widget.playlist;
    final automatic = playlist.epgUrl?.trim();
    final effective = playlist.effectiveEpgUrl;
    return AlertDialog(
      title: Text(
        context.l10n.playlistDialogEditTitle(playlist.type.toUpperCase()),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlaylistTextField(
                controller: _name,
                label: context.l10n.playlistDialogNameField,
                enabled: !busy,
              ),
              const SizedBox(height: 12),
              PlaylistTextField(
                controller: _source,
                label: playlist.type == 'xtream'
                    ? context.l10n.playlistDialogHostField
                    : context.l10n.playlistDialogUrlOrFileField,
                enabled: !busy,
              ),
              if (playlist.type == 'xtream') ...[
                const SizedBox(height: 12),
                PlaylistTextField(
                  controller: _username,
                  label: context.l10n.playlistDialogUsernameField,
                  enabled: !busy,
                ),
                const SizedBox(height: 12),
                PlaylistTextField(
                  controller: _password,
                  label: context.l10n.playlistDialogPasswordField,
                  obscureText: true,
                  enabled: !busy,
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.playlistDialogAutomaticUrlTitle,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  automatic == null || automatic.isEmpty
                      ? context.l10n.playlistDialogNoAutomaticUrl
                      : automatic,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PlaylistTextField(
                controller: _override,
                label: context.l10n.playlistDialogEpgOverrideField,
                hint: context.l10n.playlistDialogEpgOverrideHint,
                enabled: !busy,
              ),
              if (effective != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.playlistDialogEffectiveUrl(effective),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.playlistDialogCancel),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: Text(
            busy
                ? context.l10n.playlistDialogSaving
                : context.l10n.playlistDialogSave,
          ),
        ),
      ],
    );
  }
}
