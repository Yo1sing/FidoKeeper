import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// 将偏好里的语言标识映射为 Flutter locale。
Locale localeFromPreference(String? code) => switch (code) {
  'en-US' => const Locale('en'),
  'zh-TW' => const Locale('zh', 'TW'),
  _ => const Locale('zh'),
};

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
