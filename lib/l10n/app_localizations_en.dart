// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get waitForCurrentOperation => 'Wait for the current operation';

  @override
  String get operationCompleted => 'Operation completed';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String get navAuthenticators => 'Devices';

  @override
  String get navCredentials => 'Credentials';

  @override
  String get navFingerprints => 'Fingerprints';

  @override
  String get navSettings => 'Settings';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get selectAuthenticator => 'Select authenticator';

  @override
  String get resetAuthenticator => 'Reset authenticator';

  @override
  String resetAuthenticatorDetail(String label) {
    return '$label\nThis permanently erases all credentials, PIN and fingerprints. Reinsert the device, confirm immediately, then touch it as prompted.';
  }

  @override
  String get supported => 'Supported';

  @override
  String get notSupported => 'Not supported';

  @override
  String get transport => 'Transport';

  @override
  String get protocol => 'Protocol';

  @override
  String get path => 'Path';

  @override
  String get credentialManagement => 'Credential management';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get waitForUsbOrNfc => 'Insert a USB key or hold an NFC key';

  @override
  String get noAuthenticatorsFound =>
      'No authenticators found. Check connections, device permissions, or hidden devices.';

  @override
  String get moreActions => 'More actions';

  @override
  String get details => 'Details';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get hideDevice => 'Hide device';

  @override
  String get resetDevice => 'Reset device…';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get tapToSelectAndEnterPin => 'Tap to select and enter PIN';

  @override
  String get localHid => 'Local HID';

  @override
  String get credentialsUnsupported =>
      'This authenticator does not support credentials';

  @override
  String get readCredentials => 'Read credentials';

  @override
  String get changePin => 'Change PIN';

  @override
  String credentialsQuota(String used, String remaining) {
    return 'Used: $used · Remaining: $remaining';
  }

  @override
  String get searchWebsiteOrUser => 'Search website or user, press Enter';

  @override
  String get deleteCredential => 'Delete credential';

  @override
  String get permanentlyDeleteCredential => 'Permanently delete credential';

  @override
  String deleteCredentialDetail(String rpId, String userName) {
    return '$rpId\n$userName\nYou may lose access to this account. This cannot be undone.';
  }

  @override
  String get noMatchingCredentials => 'No matching discoverable credentials';

  @override
  String get fingerprintsUnsupported =>
      'This authenticator does not support fingerprints';

  @override
  String get enrollFingerprint => 'Enroll fingerprint';

  @override
  String get renameFingerprint => 'Rename fingerprint';

  @override
  String get deleteFingerprint => 'Delete fingerprint';

  @override
  String get permanentlyDeleteFingerprint => 'Permanently delete fingerprint';

  @override
  String get noFingerprintsEnrolled => 'No fingerprints enrolled';

  @override
  String get fingerprintName => 'Fingerprint name';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get hiddenAuthenticators => 'Hidden authenticators';

  @override
  String get showAgain => 'Show again';

  @override
  String get communicatingWithAuthenticator =>
      'Communicating with the authenticator. Follow its touch or enrollment prompts…';

  @override
  String get devicePin => 'Device PIN';

  @override
  String get newPin => 'New PIN';

  @override
  String get confirmNewPin => 'Confirm new PIN';

  @override
  String get cancellingEnrollment => 'Cancelling enrollment…';

  @override
  String get enrollInstruction =>
      'Press the sensor on the key. Each press reveals more of the fingerprint.';

  @override
  String get enrollIncomplete =>
      'Enrollment did not finish. You can try again.';

  @override
  String get cancelEnrollment => 'Cancel enrollment';

  @override
  String get selectDeviceFirst => 'Select a device from Authenticators first';

  @override
  String get minimizeWindow => 'Minimize';

  @override
  String get restoreWindow => 'Restore';

  @override
  String get maximizeWindow => 'Maximize';
}
