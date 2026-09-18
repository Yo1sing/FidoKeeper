import 'package:fidokeeper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

const testLocaleZh = Locale('zh');
const testLocaleEn = Locale('en');

Widget l10nApp({
  required Widget home,
  Locale locale = testLocaleZh,
  Widget Function(BuildContext, Widget?)? builder,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: builder,
    home: home,
  );
}
