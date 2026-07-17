import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';

enum SettingsPlaylistFormMode { m3u, xtream }

class SettingsPlaylistForm extends StatelessWidget {
  const SettingsPlaylistForm({
    required this.mode,
    required this.nameController,
    required this.urlController,
    required this.hostController,
    required this.usernameController,
    required this.passwordController,
    required this.epgUrlController,
    required this.isBusy,
    required this.compact,
    required this.onModeChanged,
    required this.onSubmit,
    super.key,
  });

  final SettingsPlaylistFormMode mode;
  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController hostController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController epgUrlController;
  final bool isBusy;
  final bool compact;
  final ValueChanged<SettingsPlaylistFormMode> onModeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isM3u = mode == SettingsPlaylistFormMode.m3u;

    return AppSurface(
      level: AppSurfaceLevel.standard,
      padding: EdgeInsets.all(compact ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3SettingsSectionHeader(
            icon: Icons.add_circle_outline_rounded,
            title: 'ADD PLAYLIST',
            description:
                'Create a new source and keep the flow focused on setup, sync and playback.',
            compact: compact,
          ),
          SizedBox(height: compact ? 14 : 20),
          _ModeSelector(
            mode: mode,
            compact: compact,
            onModeChanged: onModeChanged,
          ),
          SizedBox(height: compact ? 14 : 20),
          Column(
            children: [
              SettingsTextField(
                controller: nameController,
                label: 'Name',
                hint: 'My IPTV List',
                enabled: !isBusy,
              ),
              SizedBox(height: compact ? 12 : 14),
              if (isM3u)
                SettingsTextField(
                  controller: urlController,
                  label: 'URL or file path',
                  hint: 'https://example.com/playlist.m3u',
                  enabled: !isBusy,
                )
              else ...[
                SettingsTextField(
                  controller: hostController,
                  label: 'Host',
                  hint: 'http://provider.example.com:8080',
                  enabled: !isBusy,
                ),
                SizedBox(height: compact ? 12 : 14),
                SettingsTextField(
                  controller: usernameController,
                  label: 'Username',
                  enabled: !isBusy,
                ),
                SizedBox(height: compact ? 12 : 14),
                SettingsTextField(
                  controller: passwordController,
                  label: 'Password',
                  obscureText: true,
                  enabled: !isBusy,
                ),
                SizedBox(height: compact ? 12 : 14),
                SettingsTextField(
                  controller: epgUrlController,
                  label: 'EPG URL (optional)',
                  hint: 'https://example.com/epg.xml.gz',
                  enabled: !isBusy,
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onSubmit,
              icon: isBusy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(isBusy ? 'Working…' : 'Add & Sync'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  const SettingsTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          enabled: enabled,
          style: TextStyle(fontSize: 13, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            filled: true,
            fillColor: colors.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.compact,
    required this.onModeChanged,
  });

  final SettingsPlaylistFormMode mode;
  final bool compact;
  final ValueChanged<SettingsPlaylistFormMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: EdgeInsets.all(compact ? 3 : 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<SettingsPlaylistFormMode>(
          segments: const [
            ButtonSegment<SettingsPlaylistFormMode>(
              value: SettingsPlaylistFormMode.m3u,
              label: Text('M3U'),
              icon: Icon(Icons.playlist_play_rounded),
            ),
            ButtonSegment<SettingsPlaylistFormMode>(
              value: SettingsPlaylistFormMode.xtream,
              label: Text('Xtream'),
              icon: Icon(Icons.dns_rounded),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onModeChanged(selection.first);
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(
              Size.fromHeight(compact ? 40 : 44),
            ),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
            ),
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontSize: compact ? 11.5 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
