import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_server_info.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';

/// Shared entry form: server address validation.
class JellyfinServerForm extends StatelessWidget {
  const JellyfinServerForm({
    super.key,
    required this.serverUrlController,
    required this.onCheckConnection,
    this.errorMessage,
  });

  final TextEditingController serverUrlController;
  final VoidCallback onCheckConnection;
  final String? errorMessage;

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
                icon: Icons.connected_tv_rounded,
                title: context.l10n.jellyfinConnectTitle,
                description: context.l10n.jellyfinConnectDescription,
              ),
              const SizedBox(height: 20),
              if (errorMessage != null) ...[
                _ErrorBanner(message: errorMessage!),
                const SizedBox(height: 16),
              ],
              _FieldLabel(context.l10n.jellyfinServerLabel),
              const SizedBox(height: 6),
              _ServerTextField(
                controller: serverUrlController,
                hintText: context.l10n.jellyfinServerHint,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCheckConnection,
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

/// Credential form shown after the server has been verified.
class JellyfinLoginForm extends StatelessWidget {
  const JellyfinLoginForm({
    super.key,
    required this.server,
    required this.usernameController,
    required this.passwordController,
    required this.onSignIn,
    this.errorMessage,
  });

  final JellyfinServerInfo server;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSignIn;
  final String? errorMessage;

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
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.l10n.jellyfinServerVerifiedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      server.serverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.jellyfinServerVersionLabel(server.serverVersion),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (Uri.tryParse(server.baseUrl)?.scheme.toLowerCase() ==
                  'http') ...[
                _WarningBanner(message: context.l10n.jellyfinHttpWarning),
                const SizedBox(height: 16),
              ],
              if (errorMessage != null) ...[
                _ErrorBanner(message: errorMessage!),
                const SizedBox(height: 16),
              ],
              _FieldLabel(context.l10n.jellyfinUsernameLabel),
              const SizedBox(height: 6),
              _ServerTextField(
                controller: usernameController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _FieldLabel(context.l10n.jellyfinPasswordLabel),
              const SizedBox(height: 6),
              _ServerTextField(
                controller: passwordController,
                obscureText: true,
                onSubmitted: (_) => onSignIn(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(context.l10n.jellyfinSignIn),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: colors.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 17,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}

class _ServerTextField extends StatelessWidget {
  const _ServerTextField({
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 13, color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
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
    );
  }
}
