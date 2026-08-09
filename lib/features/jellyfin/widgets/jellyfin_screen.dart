import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_server_info.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_connect_view.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_details_view.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_home_view.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_library_view.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_library_sidebar.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_view.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

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
  String? _confirmedHttpServer;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    _confirmedHttpServer = null;
    await ref
        .read(jellyfinSessionControllerProvider.notifier)
        .checkServer(_serverUrlController.text.trim());
  }

  Future<void> _signIn(JellyfinServerInfo server) async {
    if (_isHttpServer(server.baseUrl) &&
        _confirmedHttpServer != server.baseUrl) {
      final confirmed = await _confirmHttpLogin();
      if (!mounted || !confirmed) return;
      _confirmedHttpServer = server.baseUrl;
    }
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
    _confirmedHttpServer = null;
    ref.read(jellyfinViewStackProvider.notifier).state = const [
      JellyfinHomeRoute(),
    ];
    await ref.read(jellyfinSessionControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jellyfinSessionControllerProvider);

    return switch (state) {
      JellyfinRestoringSession() => _StatusView(
        message: context.l10n.jellyfinConnecting,
        busy: true,
      ),
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
        onSignIn: () => _signIn(server),
      ),
      JellyfinSigningIn() => _StatusView(
        message: context.l10n.jellyfinConnecting,
        busy: true,
      ),
      JellyfinAuthenticated(connection: final connection) =>
        _JellyfinBrowseArea(connection: connection, onSignOut: _signOut),
      JellyfinSessionFailure(kind: final kind, server: final server)
          when server == null =>
        JellyfinServerForm(
          serverUrlController: _serverUrlController,
          onCheckConnection: _checkServer,
          errorMessage: _errorMessage(context.l10n, kind),
        ),
      JellyfinSessionFailure(kind: final kind, server: final server) =>
        JellyfinLoginForm(
          server: server!,
          usernameController: _usernameController,
          passwordController: _passwordController,
          onSignIn: () => _signIn(server),
          errorMessage: _errorMessage(context.l10n, kind),
        ),
    };
  }

  bool _isHttpServer(String baseUrl) =>
      Uri.tryParse(baseUrl)?.scheme.toLowerCase() == 'http';

  Future<bool> _confirmHttpLogin() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.jellyfinHttpDialogTitle),
        content: Text(context.l10n.jellyfinHttpDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.jellyfinHttpCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.jellyfinHttpContinue),
          ),
        ],
      ),
    );
    return result == true;
  }
}

/// Renders the internal Jellyfin view stack (home → library → details).
class _JellyfinBrowseArea extends ConsumerWidget {
  const _JellyfinBrowseArea({
    required this.connection,
    required this.onSignOut,
  });

  final JellyfinConnection connection;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(jellyfinViewStackProvider);
    final route = stack.isEmpty ? const JellyfinHomeRoute() : stack.last;
    if (route case JellyfinPlayerRoute(item: final item)) {
      return JellyfinPlayerView(connection: connection, item: item);
    }

    final home = ref.watch(jellyfinHomeDataProvider);
    final libraries = home.valueOrNull?.libraries ?? const [];
    final selectedLibrary = jellyfinSelectedLibrary(stack);
    final content = switch (route) {
      JellyfinHomeRoute() => JellyfinHomeView(
        connection: connection,
        onSignOut: onSignOut,
      ),
      JellyfinLibraryRoute(library: final library) => JellyfinLibraryView(
        connection: connection,
        library: library,
      ),
      JellyfinDetailsRoute(item: final item) => JellyfinDetailsView(
        connection: connection,
        item: item,
      ),
      JellyfinPlayerRoute() => const SizedBox.shrink(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth.isFinite && constraints.maxWidth >= 960;
        final selectedLibraryId = selectedLibrary?.id;

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JellyfinLibrarySidebar(
                libraries: libraries,
                selectedLibraryId: selectedLibraryId,
                onOverviewSelected: () => jellyfinSelectOverview(ref),
                onLibrarySelected: (library) =>
                    jellyfinSelectLibrary(ref, library),
              ),
              const SizedBox(width: 16),
              Expanded(child: content),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JellyfinLibraryPicker(
              libraries: libraries,
              selectedLibraryId: selectedLibraryId,
              onOverviewSelected: () => jellyfinSelectOverview(ref),
              onLibrarySelected: (library) =>
                  jellyfinSelectLibrary(ref, library),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

String _errorMessage(AppLocalizations l10n, JellyfinFailureKind kind) {
  return switch (kind) {
    JellyfinFailureKind.invalidUrl => l10n.jellyfinErrorInvalidUrl,
    JellyfinFailureKind.dns => l10n.jellyfinErrorDns,
    JellyfinFailureKind.connectionRefused =>
      l10n.jellyfinErrorConnectionRefused,
    JellyfinFailureKind.hostUnreachable => l10n.jellyfinErrorHostUnreachable,
    JellyfinFailureKind.timeout => l10n.jellyfinErrorTimeout,
    JellyfinFailureKind.tls => l10n.jellyfinErrorTls,
    JellyfinFailureKind.notJellyfin => l10n.jellyfinErrorNotJellyfin,
    JellyfinFailureKind.invalidCredentials =>
      l10n.jellyfinErrorInvalidCredentials,
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
