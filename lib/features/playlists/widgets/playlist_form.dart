import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

enum PlaylistFormMode { m3u, xtream }

class PlaylistForm extends StatelessWidget {
  const PlaylistForm({
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
    this.showSubmitButton = true,
    super.key,
  });

  final PlaylistFormMode mode;
  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController hostController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController epgUrlController;
  final bool isBusy;
  final bool compact;
  final ValueChanged<PlaylistFormMode> onModeChanged;
  final VoidCallback onSubmit;
  final bool showSubmitButton;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isM3u = mode == PlaylistFormMode.m3u;

    return AppSurface(
      level: AppSurfaceLevel.standard,
      padding: EdgeInsets.all(compact ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3SettingsSectionHeader(
            icon: Icons.add_circle_outline_rounded,
            title: context.l10n.playlistFormTitle,
            description: context.l10n.playlistFormDescription,
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
              PlaylistTextField(
                controller: nameController,
                label: context.l10n.playlistFormNameLabel,
                hint: context.l10n.playlistFormNameHint,
                enabled: !isBusy,
              ),
              SizedBox(height: compact ? 12 : 14),
              if (isM3u)
                PlaylistTextField(
                  controller: urlController,
                  label: context.l10n.playlistFormUrlOrFileLabel,
                  hint: 'https://example.com/playlist.m3u',
                  enabled: !isBusy,
                )
              else ...[
                PlaylistTextField(
                  controller: hostController,
                  label: context.l10n.playlistFormHostLabel,
                  hint: 'http://provider.example.com:8080',
                  enabled: !isBusy,
                ),
                SizedBox(height: compact ? 12 : 14),
                PlaylistTextField(
                  controller: usernameController,
                  label: context.l10n.playlistFormUsernameLabel,
                  enabled: !isBusy,
                ),
                SizedBox(height: compact ? 12 : 14),
                PlaylistTextField(
                  controller: passwordController,
                  label: context.l10n.playlistFormPasswordLabel,
                  obscureText: true,
                  enabled: !isBusy,
                ),
              ],
              SizedBox(height: compact ? 12 : 14),
              PlaylistTextField(
                controller: epgUrlController,
                label: context.l10n.playlistFormEpgOverrideLabel,
                hint: context.l10n.playlistFormEpgOverrideHint,
                enabled: !isBusy,
              ),
            ],
          ),
          if (showSubmitButton) ...[
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
                label: Text(
                  isBusy
                      ? context.l10n.playlistFormWorking
                      : context.l10n.playlistFormAddAndSync,
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PlaylistTextField extends StatelessWidget {
  const PlaylistTextField({
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

  final PlaylistFormMode mode;
  final bool compact;
  final ValueChanged<PlaylistFormMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: EdgeInsets.all(compact ? 3 : 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<PlaylistFormMode>(
          segments: const [
            ButtonSegment<PlaylistFormMode>(
              value: PlaylistFormMode.m3u,
              label: Text('M3U'),
              icon: Icon(Icons.playlist_play_rounded),
            ),
            ButtonSegment<PlaylistFormMode>(
              value: PlaylistFormMode.xtream,
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
