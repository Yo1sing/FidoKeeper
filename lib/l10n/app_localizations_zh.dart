// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get waitForCurrentOperation => '请等待当前操作完成';

  @override
  String get operationCompleted => '操作成功';

  @override
  String get dismiss => '关闭';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get save => '保存';

  @override
  String get retry => '重试';

  @override
  String get navAuthenticators => '认证器';

  @override
  String get navCredentials => '凭证';

  @override
  String get navFingerprints => '指纹';

  @override
  String get navSettings => '设置';

  @override
  String get scanAgain => '重新扫描';

  @override
  String get selectAuthenticator => '选择认证器';

  @override
  String get resetAuthenticator => '重置认证器';

  @override
  String resetAuthenticatorDetail(String label) {
    return '$label\n此操作会永久清除全部凭证、PIN 和指纹，无法撤销。请重新插入设备后立即确认，并按设备提示触碰。';
  }

  @override
  String get supported => '支持';

  @override
  String get notSupported => '不支持';

  @override
  String get transport => '传输';

  @override
  String get protocol => '协议';

  @override
  String get path => '路径';

  @override
  String get credentialManagement => '凭证管理';

  @override
  String get fingerprint => '指纹';

  @override
  String get waitForUsbOrNfc => '等待插入 USB 密钥或贴上 NFC 密钥';

  @override
  String get noAuthenticatorsFound => '未发现可用认证器；请检查连接、设备权限或隐藏列表。';

  @override
  String get moreActions => '更多操作';

  @override
  String get details => '详情';

  @override
  String get disconnect => '断开连接';

  @override
  String get hideDevice => '隐藏设备';

  @override
  String get resetDevice => '重置设备…';

  @override
  String get unlocked => '已解锁';

  @override
  String get tapToSelectAndEnterPin => '轻触以选择并输入 PIN';

  @override
  String get localHid => '本机 HID';

  @override
  String get credentialsUnsupported => '当前认证器不支持凭证管理';

  @override
  String get readCredentials => '读取凭证';

  @override
  String get changePin => '更改 PIN';

  @override
  String credentialsQuota(String used, String remaining) {
    return '已用: $used · 剩余: $remaining';
  }

  @override
  String get searchWebsiteOrUser => '搜索网站或用户，回车筛选';

  @override
  String get deleteCredential => '删除凭证';

  @override
  String get permanentlyDeleteCredential => '永久删除凭证';

  @override
  String deleteCredentialDetail(String rpId, String userName) {
    return '$rpId\n$userName\n删除后可能无法再登录此账号，操作无法撤销。';
  }

  @override
  String get noMatchingCredentials => '没有匹配的可发现凭证';

  @override
  String get fingerprintsUnsupported => '当前认证器不支持指纹';

  @override
  String get enrollFingerprint => '录入指纹';

  @override
  String get renameFingerprint => '重命名指纹';

  @override
  String get deleteFingerprint => '删除指纹';

  @override
  String get permanentlyDeleteFingerprint => '永久删除指纹';

  @override
  String get noFingerprintsEnrolled => '尚未录入指纹';

  @override
  String get fingerprintName => '指纹名称';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get hiddenAuthenticators => '已隐藏的认证器';

  @override
  String get showAgain => '恢复显示';

  @override
  String get communicatingWithAuthenticator => '正在与认证器通信，请按设备提示触碰或采样…';

  @override
  String get devicePin => '设备 PIN';

  @override
  String get newPin => '新 PIN';

  @override
  String get confirmNewPin => '确认新 PIN';

  @override
  String get cancellingEnrollment => '正在取消录入，请稍候…';

  @override
  String get enrollInstruction => '请在安全密钥上按压指纹传感器，每按一次会多显出一段纹路';

  @override
  String get enrollIncomplete => '采样未完成，可以重试。';

  @override
  String get cancelEnrollment => '取消录入';

  @override
  String get selectDeviceFirst => '请先在认证器页面选择设备';

  @override
  String get minimizeWindow => '最小化';

  @override
  String get restoreWindow => '还原';

  @override
  String get maximizeWindow => '最大化';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get waitForCurrentOperation => '請等待目前操作完成';

  @override
  String get operationCompleted => '操作成功';

  @override
  String get dismiss => '關閉';

  @override
  String get close => '關閉';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '確認';

  @override
  String get save => '儲存';

  @override
  String get retry => '重試';

  @override
  String get navAuthenticators => '認證器';

  @override
  String get navCredentials => '憑證';

  @override
  String get navFingerprints => '指紋';

  @override
  String get navSettings => '設定';

  @override
  String get scanAgain => '重新掃描';

  @override
  String get selectAuthenticator => '選擇認證器';

  @override
  String get resetAuthenticator => '重設認證器';

  @override
  String resetAuthenticatorDetail(String label) {
    return '$label\n此操作會永久清除全部憑證、PIN 和指紋，無法復原。請重新插入裝置後立即確認，並依裝置提示觸碰。';
  }

  @override
  String get supported => '支援';

  @override
  String get notSupported => '不支援';

  @override
  String get transport => '傳輸';

  @override
  String get protocol => '協定';

  @override
  String get path => '路徑';

  @override
  String get credentialManagement => '憑證管理';

  @override
  String get fingerprint => '指紋';

  @override
  String get waitForUsbOrNfc => '等待插入 USB 金鑰或貼上 NFC 金鑰';

  @override
  String get noAuthenticatorsFound => '未發現可用認證器；請檢查連線、裝置權限或隱藏清單。';

  @override
  String get moreActions => '更多操作';

  @override
  String get details => '詳情';

  @override
  String get disconnect => '中斷連線';

  @override
  String get hideDevice => '隱藏裝置';

  @override
  String get resetDevice => '重設裝置…';

  @override
  String get unlocked => '已解鎖';

  @override
  String get tapToSelectAndEnterPin => '輕觸以選擇並輸入 PIN';

  @override
  String get localHid => '本機 HID';

  @override
  String get credentialsUnsupported => '目前認證器不支援憑證管理';

  @override
  String get readCredentials => '讀取憑證';

  @override
  String get changePin => '變更 PIN';

  @override
  String credentialsQuota(String used, String remaining) {
    return '已用: $used · 剩餘: $remaining';
  }

  @override
  String get searchWebsiteOrUser => '搜尋網站或使用者，按 Enter 篩選';

  @override
  String get deleteCredential => '刪除憑證';

  @override
  String get permanentlyDeleteCredential => '永久刪除憑證';

  @override
  String deleteCredentialDetail(String rpId, String userName) {
    return '$rpId\n$userName\n刪除後可能無法再登入此帳號，操作無法復原。';
  }

  @override
  String get noMatchingCredentials => '沒有符合的可發現憑證';

  @override
  String get fingerprintsUnsupported => '目前認證器不支援指紋';

  @override
  String get enrollFingerprint => '登錄指紋';

  @override
  String get renameFingerprint => '重新命名指紋';

  @override
  String get deleteFingerprint => '刪除指紋';

  @override
  String get permanentlyDeleteFingerprint => '永久刪除指紋';

  @override
  String get noFingerprintsEnrolled => '尚未登錄指紋';

  @override
  String get fingerprintName => '指紋名稱';

  @override
  String get theme => '主題';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get hiddenAuthenticators => '已隱藏的認證器';

  @override
  String get showAgain => '恢復顯示';

  @override
  String get communicatingWithAuthenticator => '正在與認證器通訊，請依裝置提示觸碰或取樣…';

  @override
  String get devicePin => '裝置 PIN';

  @override
  String get newPin => '新 PIN';

  @override
  String get confirmNewPin => '確認新 PIN';

  @override
  String get cancellingEnrollment => '正在取消登錄，請稍候…';

  @override
  String get enrollInstruction => '請在安全金鑰上按壓指紋感應器，每按一次會多顯出一段紋路';

  @override
  String get enrollIncomplete => '取樣未完成，可以重試。';

  @override
  String get cancelEnrollment => '取消登錄';

  @override
  String get selectDeviceFirst => '請先在認證器頁面選擇裝置';

  @override
  String get minimizeWindow => '最小化';

  @override
  String get restoreWindow => '還原';

  @override
  String get maximizeWindow => '最大化';
}
