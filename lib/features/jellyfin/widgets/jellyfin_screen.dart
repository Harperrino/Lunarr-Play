import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_connect_view.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';

/// Standalone Jellyfin main tab: server check, sign-in and session state.
class JellyfinScreen extends ConsumerStatefulWidget {
  const JellyfinScreen({super.key});

  @override
  ConsumerState<JellyfinScreen> createState() => _JellyfinScreenState();
}

class _JellyfinScreenState extends ConsumerState<JellyfinScreen> {
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    await ref
        .read(jellyfinSessionControllerProvider.notifier)
        .checkServer(_serverUrlController.text.trim());
  }

  Future<void> _signIn() async {
    await ref
        .read(jellyfinSessionControllerProvider.notifier)
        .signIn(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _signOut() async {
    _usernameController.clear();
    _passwordController.clear();
    await ref.read(jellyfinSessionControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jellyfinSessionControllerProvider);

    return switch (state) {
      JellyfinIdle() => JellyfinServerForm(
        serverUrlController: _serverUrlController,
        onCheckConnection: _checkServer,
      ),
      JellyfinVerifyingServer() => _StatusView(
        message: context.l10n.jellyfinCheckingServer,
        busy: true,
      ),
      JellyfinServerVerified(server: final server) => JellyfinLoginForm(
        server: server,
        usernameController: _usernameController,
        passwordController: _passwordController,
        onSignIn: _signIn,
      ),
      JellyfinSigningIn() => _StatusView(
        message: context.l10n.jellyfinConnecting,
        busy: true,
      ),
      JellyfinAuthenticated(connection: final connection) => _ConnectedView(
        connection: connection,
        onSignOut: _signOut,
      ),
      JellyfinSessionFailure(
        kind: final kind,
        server: final server,
      ) when server == null => JellyfinServerForm(
        serverUrlController: _serverUrlController,
        onCheckConnection: _checkServer,
        errorMessage: _errorMessage(context.l10n, kind),
      ),
      JellyfinSessionFailure(
        kind: final kind,
        server: final server,
      ) => JellyfinLoginForm(
        server: server!,
        usernameController: _usernameController,
        passwordController: _passwordController,
        onSignIn: _signIn,
        errorMessage: _errorMessage(context.l10n, kind),
      ),
    };
  }
}

String _errorMessage(AppLocalizations l10n, JellyfinFailureKind kind) {
  return switch (kind) {
    JellyfinFailureKind.invalidUrl => l10n.jellyfinErrorInvalidUrl,
    JellyfinFailureKind.dns => l10n.jellyfinErrorDns,
    JellyfinFailureKind.connectionRefused => l10n.jellyfinErrorConnectionRefused,
    JellyfinFailureKind.hostUnreachable => l10n.jellyfinErrorHostUnreachable,
    JellyfinFailureKind.timeout => l10n.jellyfinErrorTimeout,
    JellyfinFailureKind.tls => l10n.jellyfinErrorTls,
    JellyfinFailureKind.notJellyfin => l10n.jellyfinErrorNotJellyfin,
    JellyfinFailureKind.invalidCredentials => l10n.jellyfinErrorInvalidCredentials,
    JellyfinFailureKind.unknown => l10n.jellyfinErrorUnknown,
  };
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.message, this.busy = false});

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
            ),
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

class _ConnectedView extends StatelessWidget {
  const _ConnectedView({required this.connection, required this.onSignOut});

  final JellyfinConnection connection;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
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
                icon: Icons.check_circle_rounded,
                title: context.l10n.jellyfinConnected,
                description: connection.baseUrl,
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.jellyfinSignedInAs(connection.username),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.jellyfinServerVersionLabel(
                  connection.serverVersion,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(context.l10n.jellyfinSignOut),
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
