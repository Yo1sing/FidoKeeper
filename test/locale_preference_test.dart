import 'package:fidokeeper/l10n/locale_preference.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('语言偏好映射到对应 locale，跟随系统时不指定 locale', () {
    expect(localeFromPreference('zh-CN'), const Locale('zh'));
    expect(localeFromPreference('zh-TW'), const Locale('zh', 'TW'));
    expect(localeFromPreference('en-US'), const Locale('en'));
    expect(localeFromPreference(null), const Locale('zh'));
    expect(localeFromPreference('system'), isNull);
  });

  test('跟随系统时按系统语言解析到支持的语言', () {
    Locale system(List<Locale> locales) => resolveAppLocale('system', locales);
    expect(system(const [Locale('en', 'US')]), const Locale('en'));
    expect(system(const [Locale('zh', 'CN')]), const Locale('zh'));
    expect(
      system(const [
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      ]),
      const Locale('zh', 'TW'),
    );
    // 系统语言不在支持范围时退回 Flutter 的默认规则：第一个受支持语言。
    expect(
      system(const [Locale('fr', 'FR')]),
      AppLocalizations.supportedLocales.first,
    );
  });

  test('已选语言不受系统语言影响', () {
    expect(
      resolveAppLocale('zh-TW', const [Locale('en')]),
      const Locale('zh', 'TW'),
    );
    expect(resolveAppLocale('en-US', const [Locale('zh')]), const Locale('en'));
  });
}
