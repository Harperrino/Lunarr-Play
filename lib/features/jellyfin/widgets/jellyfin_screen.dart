import 'package:flutter/material.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';

/// Connection lifecycle of the Jellyfin feature.
enum JellyfinConnectionStage { disconnected, loading, connected }

/// Standalone Jellyfin main tab.
///
/// Wave 1 renders the connect view only; the loading and connected branches
/// prepare the states for the upcoming connection wave.
class JellyfinScreen extends StatelessWidget {
  const JellyfinScreen({
    super.key,
    this.initialStage = JellyfinConnectionStage.disconnected,
  });

  final JellyfinConnectionStage initialStage;

  @override
  Widget build(BuildContext context) {
    return switch (initialStage) {
      JellyfinConnectionStage.disconnected => const _JellyfinConnectView(),
      JellyfinConnectionStage.loading => _JellyfinStatusView(
        icon: Icons.sync_rounded,
        message: context.l10n.jellyfinConnecting,
        busy: true,
      ),
      JellyfinConnectionStage.connected => _JellyfinStatusView(
        icon: Icons.check_circle_rounded,
        message: context.l10n.jellyfinConnected,
      ),
    };
  }
}

class _JellyfinConnectView extends StatelessWidget {
  const _JellyfinConnectView();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppSurface(
          level: AppSurfaceLevel.standard,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              M3SettingsSectionHeader(
                icon: Icons.connected_tv_rounded,
                title: context.l10n.jellyfinConnectTitle,
                description: context.l10n.jellyfinConnectDescription,
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.jellyfinServerLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    style: TextStyle(fontSize: 13, color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: context.l10n.jellyfinServerHint,
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
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
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(context.l10n.jellyfinCheckConnection),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JellyfinStatusView extends StatelessWidget {
  const _JellyfinStatusView({
    required this.icon,
    required this.message,
    this.busy = false,
  });

  final IconData icon;
  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          else
            Icon(icon, size: 40, color: colors.primary),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
