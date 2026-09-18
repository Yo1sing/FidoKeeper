import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// 语言偏好里表示跟随系统语言的值。
const systemLocalePreference = 'system';

/// 将偏好里的语言标识映射为 Flutter locale；返回 null 表示交给系统语言决定。
Locale? localeFromPreference(String? code) => switch (code) {
  systemLocalePreference => null,
  'en-US' => const Locale('en'),
  'zh-TW' => const Locale('zh', 'TW'),
  _ => const Locale('zh'),
};

/// 把语言偏好和系统语言合成为实际使用的 locale。
///
/// 跟随系统时用 Flutter 的默认规则挑选受支持的语言，保证与 MaterialApp 自身的
/// 解析结果一致；界面之外的文案（错误条、提示）也据此选语言。
Locale resolveAppLocale(String? code, List<Locale> systemLocales) =>
    localeFromPreference(code) ??
    basicLocaleListResolution(systemLocales, AppLocalizations.supportedLocales);

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
