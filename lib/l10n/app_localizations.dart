import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @waitForCurrentOperation.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current operation'**
  String get waitForCurrentOperation;

  /// No description provided for @closing.
  ///
  /// In en, this message translates to:
  /// **'Closing…'**
  String get closing;

  /// No description provided for @closingWaitOperation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for “{operation}” to finish. The app closes as soon as it completes.'**
  String closingWaitOperation(String operation);

  /// No description provided for @closingWaitAny.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the current operation to finish. The app closes as soon as it completes.'**
  String get closingWaitAny;

  /// No description provided for @operationScan.
  ///
  /// In en, this message translates to:
  /// **'Scanning authenticators'**
  String get operationScan;

  /// No description provided for @operationVerifyPin.
  ///
  /// In en, this message translates to:
  /// **'Verifying PIN'**
  String get operationVerifyPin;

  /// No description provided for @operationReadFingerprints.
  ///
  /// In en, this message translates to:
  /// **'Reading fingerprints'**
  String get operationReadFingerprints;

  /// No description provided for @operationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Operation completed'**
  String get operationCompleted;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @navAuthenticators.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navAuthenticators;

  /// No description provided for @navCredentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get navCredentials;

  /// No description provided for @navFingerprints.
  ///
  /// In en, this message translates to:
  /// **'Fingerprints'**
  String get navFingerprints;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @selectAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Select authenticator'**
  String get selectAuthenticator;

  /// No description provided for @resetAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Reset authenticator'**
  String get resetAuthenticator;

  /// No description provided for @resetAuthenticatorDetail.
  ///
  /// In en, this message translates to:
  /// **'{label}\nThis permanently erases all credentials, PIN and fingerprints. Reinsert the device, confirm immediately, then touch it as prompted.'**
  String resetAuthenticatorDetail(String label);

  /// No description provided for @supported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get supported;

  /// No description provided for @notSupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported'**
  String get notSupported;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transport;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @credentialManagement.
  ///
  /// In en, this message translates to:
  /// **'Credential management'**
  String get credentialManagement;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @waitForUsbOrNfc.
  ///
  /// In en, this message translates to:
  /// **'Insert a USB key or hold an NFC key'**
  String get waitForUsbOrNfc;

  /// No description provided for @noAuthenticatorsFound.
  ///
  /// In en, this message translates to:
  /// **'No authenticators found. Check connections, device permissions, or hidden devices.'**
  String get noAuthenticatorsFound;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @hideDevice.
  ///
  /// In en, this message translates to:
  /// **'Hide device'**
  String get hideDevice;

  /// No description provided for @resetDevice.
  ///
  /// In en, this message translates to:
  /// **'Reset device…'**
  String get resetDevice;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @tapToSelectAndEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Tap to select and enter PIN'**
  String get tapToSelectAndEnterPin;

  /// No description provided for @localHid.
  ///
  /// In en, this message translates to:
  /// **'Local HID'**
  String get localHid;

  /// No description provided for @credentialsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This authenticator does not support credentials'**
  String get credentialsUnsupported;

  /// No description provided for @readCredentials.
  ///
  /// In en, this message translates to:
  /// **'Read credentials'**
  String get readCredentials;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @credentialsQuota.
  ///
  /// In en, this message translates to:
  /// **'Used: {used} · Remaining: {remaining}'**
  String credentialsQuota(String used, String remaining);

  /// No description provided for @searchWebsiteOrUser.
  ///
  /// In en, this message translates to:
  /// **'Search website or user, press Enter'**
  String get searchWebsiteOrUser;

  /// No description provided for @deleteCredential.
  ///
  /// In en, this message translates to:
  /// **'Delete credential'**
  String get deleteCredential;

  /// No description provided for @permanentlyDeleteCredential.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete credential'**
  String get permanentlyDeleteCredential;

  /// No description provided for @deleteCredentialDetail.
  ///
  /// In en, this message translates to:
  /// **'{rpId}\n{userName}\nYou may lose access to this account. This cannot be undone.'**
  String deleteCredentialDetail(String rpId, String userName);

  /// No description provided for @noMatchingCredentials.
  ///
  /// In en, this message translates to:
  /// **'No matching discoverable credentials'**
  String get noMatchingCredentials;

  /// No description provided for @fingerprintsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This authenticator does not support fingerprints'**
  String get fingerprintsUnsupported;

  /// No description provided for @enrollFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Enroll fingerprint'**
  String get enrollFingerprint;

  /// No description provided for @renameFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Rename fingerprint'**
  String get renameFingerprint;

  /// No description provided for @deleteFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Delete fingerprint'**
  String get deleteFingerprint;

  /// No description provided for @permanentlyDeleteFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete fingerprint'**
  String get permanentlyDeleteFingerprint;

  /// No description provided for @noFingerprintsEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No fingerprints enrolled'**
  String get noFingerprintsEnrolled;

  /// No description provided for @fingerprintName.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint name'**
  String get fingerprintName;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageZhTw.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageZhTw;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @hiddenAuthenticators.
  ///
  /// In en, this message translates to:
  /// **'Hidden authenticators'**
  String get hiddenAuthenticators;

  /// No description provided for @showAgain.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get showAgain;

  /// No description provided for @communicatingWithAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Communicating with the authenticator. Follow its touch or enrollment prompts…'**
  String get communicatingWithAuthenticator;

  /// No description provided for @devicePin.
  ///
  /// In en, this message translates to:
  /// **'Device PIN'**
  String get devicePin;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPin;

  /// No description provided for @confirmNewPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm new PIN'**
  String get confirmNewPin;

  /// No description provided for @cancellingEnrollment.
  ///
  /// In en, this message translates to:
  /// **'Cancelling enrollment…'**
  String get cancellingEnrollment;

  /// No description provided for @enrollInstruction.
  ///
  /// In en, this message translates to:
  /// **'Press the sensor on the key. Each press reveals more of the fingerprint.'**
  String get enrollInstruction;

  /// No description provided for @enrollIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Enrollment did not finish. You can try again.'**
  String get enrollIncomplete;

  /// No description provided for @cancelEnrollment.
  ///
  /// In en, this message translates to:
  /// **'Cancel enrollment'**
  String get cancelEnrollment;

  /// No description provided for @selectDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a device from Authenticators first'**
  String get selectDeviceFirst;

  /// No description provided for @minimizeWindow.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimizeWindow;

  /// No description provided for @restoreWindow.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreWindow;

  /// No description provided for @maximizeWindow.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximizeWindow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
