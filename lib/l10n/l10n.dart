import 'package:flutter/widgets.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations_en.dart';

final AppLocalizations _fallbackEnglish = AppLocalizationsEn();

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      _fallbackEnglish;
}
