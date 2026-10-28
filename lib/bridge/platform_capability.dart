// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:watermeter/repository/ruisi_forum.dart';

/// Raw system locale name; kept in this file so callers do not need to
/// import `dart:io` just for `Platform.localeName`.
String get systemLocaleName => Platform.localeName;

/// Centralized platform capability checks.
///
/// UI pages and bootstrap code should use these helpers instead of writing
/// `Platform.isX` directly. Native-channel wrappers stay in this `bridge/`
/// directory; service-layer platform branches may also reuse these getters.
bool get supportsSystemNotifications =>
    Platform.isAndroid || Platform.isIOS || Platform.isOhos;

/// Fluttertoast works on mobile platforms (Android/iOS/OHOS); desktop uses
/// SnackBar instead.
bool get supportsFlutterToast =>
    Platform.isAndroid || Platform.isIOS || Platform.isOhos;

/// Native Scan Kit bridge is only available on HarmonyOS.
bool get supportsNativeScan => Platform.isOhos;

/// iOS-only HomeWidget App Group registration (upstream behaviour).
bool get supportsHomeWidgetAppGroup => Platform.isIOS;

/// The app is marketed as XDYou on mobile stores; desktop keeps the old
/// Traintime PDA title.
bool get usesXDYouAppTitle =>
    Platform.isIOS || Platform.isMacOS || Platform.isAndroid || Platform.isOhos;

/// Upstream only cancels the platform intent stream on Android/iOS.
bool get supportsPlatformIntentSub => Platform.isAndroid || Platform.isIOS;

/// 睿思论坛入口是否可见。
///
/// **默认一律隐藏**（含调试签名包）—— 睿思属校园 UGC 社区，监管审批通过前
/// 不对外提供。审批期间的临时开关见 `repository/ruisi_forum.dart`：
/// 它**只存在于调试签名包**，正式包恒为隐藏（否则用户一开就等于应用在提供该功能，
/// 合规要求就白做了）。
///
/// **审批通过后**：把本 getter 直接改成 `true`，再删掉 `RuisiForum` 与调试页里的开关。
///
/// 其他平台一律保持原行为（睿思始终显示），不因鸿蒙的合规限制给三端制造差异
/// （同 `ReminderQuota.enforced` 的处理方式）。
bool get supportsRuisiForum => !Platform.isOhos || RuisiForum.enabled;

/// Resolve the UI language code from the system locale.
///
/// iOS/macOS report Chinese variants as Hans/Hant; Android/OHOS/Linux/Windows
/// report CN/SG. Keep this logic in one place so controllers and services do
/// not duplicate it.
String resolveSystemLocaleLanguageCode() {
  final String systemLocale = Platform.localeName;
  if (!systemLocale.contains('zh')) {
    return 'en_US';
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return systemLocale.contains('Hans') ? 'zh_CN' : 'zh_TW';
  }
  return (systemLocale.contains('CN') || systemLocale.contains('SG'))
      ? 'zh_CN'
      : 'zh_TW';
}
