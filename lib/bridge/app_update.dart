// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:watermeter/repository/logger.dart';

const MethodChannel _appUpdateChannel = MethodChannel('xdyou/app_update');

/// `updateManager.checkAppUpdate` 的结果（鸿蒙走华为应用市场）。
///
/// 失败时不再静默：`errorCode != 0`，界面据此提示原因
/// （原先失败被吞掉，表现就是点「检查更新」完全没反应）。
class AppUpdateResult {
  /// 1 = 有新版，0 = 无新版。
  final int updateAvailable;

  /// 新版本名（**官方文档注明仅元服务返回**，普通应用为空串）。
  final String versionName;

  /// 新版本号（同上，仅元服务返回）。
  final int versionCode;

  /// AppGalleryKit 错误码，0 = 成功。含义见 [appUpdateErrorHint]。
  final int errorCode;

  /// 原始错误信息（华为返回，用于日志排查）。
  final String errorMessage;

  const AppUpdateResult({
    required this.updateAvailable,
    required this.versionName,
    required this.versionCode,
    this.errorCode = 0,
    this.errorMessage = '',
  });

  bool get hasUpdate => updateAvailable == 1;

  /// 本次检查是否失败。失败时 [hasUpdate] 恒为 false，**不能**当成"已是最新"。
  bool get failed => errorCode != 0;
}

/// `updateManager.showUpdateDialog` 的结果。
class AppUpdateDialogResult {
  /// 0 = 更新弹窗已成功展示，1 = 展示失败（ShowUpdateResultCode）。
  final int resultCode;

  /// AppGalleryKit 错误码，0 = 无错误。
  final int errorCode;

  final String errorMessage;

  const AppUpdateDialogResult({
    required this.resultCode,
    this.errorCode = 0,
    this.errorMessage = '',
  });

  /// 0 表示弹窗正常弹出（用户在弹窗里选了什么不影响该结果）。
  bool get ok => resultCode == 0 && errorCode == 0;

  /// 展示给用户的错误码：优先业务错误码，否则用 ShowUpdateResultCode。
  int get displayCode => errorCode != 0 ? errorCode : resultCode;
}

/// AppGalleryKit 错误码 → 人能看懂的原因（用于日志与排查）。
String appUpdateErrorHint(int code) => switch (code) {
  0 => '成功',
  1 => '更新弹窗展示失败',
  -1 => '无法调用应用市场服务',
  401 => '参数错误',
  1009400001 => '应用市场服务连接失败',
  1009400002 => '应用市场服务请求失败',
  1009400003 => '网络异常',
  1009400004 => '应用不在前台',
  1009400005 => '尚未同意华为隐私协议（需先在应用市场同意后重试）',
  1009400006 => '操作过于频繁，请稍后再试',
  1009400007 => '其它错误',
  1006700001 => '隐私管理服务内部错误',
  1006700002 => '隐私管理服务扩展连接失败',
  1006700003 => '应用未接入隐私托管服务（需先在 AGC 配置隐私政策 / 隐私声明托管）',
  _ => '未知错误',
};

/// AppGalleryKit 隐私合规状态（`privacyManager`）。
///
/// **为什么更新检查需要它**：`updateManager.checkAppUpdate` 在"未同意隐私协议"时
/// 会直接返回 **1009400005**，必须先经 `requestAppPrivacyConsent` 拉起华为标准化
/// 隐私弹框征得同意；而 `privacyManager` 本身要求应用在 **AGC 配置过隐私政策**
/// （自定义隐私政策网址或隐私声明托管服务），否则报 **1006700003**。
class AppPrivacyStatus {
  /// 应用是否接入了隐私管理服务（false 通常意味着 AGC 侧还没配隐私政策）。
  final bool supported;

  /// 用户是否已同意（且无需重新签署）。
  final bool agreed;

  /// 协议版本更新，需要重新签署。
  final bool requiresResign;

  final int errorCode;
  final String errorMessage;

  const AppPrivacyStatus({
    required this.supported,
    required this.agreed,
    this.requiresResign = false,
    this.errorCode = 0,
    this.errorMessage = '',
  });

  bool get failed => errorCode != 0;

  /// AGC 未接入隐私托管服务（需要开发者去 AGC 配置，用户侧无解）。
  bool get notConfigured => errorCode == 1006700003;
}

/// 查询 AppGalleryKit 隐私合规状态（非鸿蒙返回 null）。
Future<AppPrivacyStatus?> checkPrivacyStatus() async {
  if (!Platform.isOhos) {
    return null;
  }
  try {
    final raw = await _appUpdateChannel.invokeMapMethod<dynamic, dynamic>(
      'privacyStatus',
    );
    if (raw == null) {
      return null;
    }
    return AppPrivacyStatus(
      supported: (raw['supported'] as bool?) ?? false,
      agreed: (raw['agreed'] as bool?) ?? false,
      requiresResign: (raw['requiresResign'] as bool?) ?? false,
      errorCode: (raw['errorCode'] as num?)?.toInt() ?? 0,
      errorMessage: (raw['errorMessage'] as String?) ?? '',
    );
  } catch (e, s) {
    log.error('[AppUpdate] checkPrivacyStatus 调用失败', e, s);
    return null;
  }
}

/// 拉起华为标准化隐私弹框征求同意（非鸿蒙返回 null）。
Future<AppPrivacyStatus?> requestPrivacyConsent() async {
  if (!Platform.isOhos) {
    return null;
  }
  try {
    final raw = await _appUpdateChannel.invokeMapMethod<dynamic, dynamic>(
      'requestPrivacyConsent',
    );
    if (raw == null) {
      return null;
    }
    return AppPrivacyStatus(
      supported: (raw['supported'] as bool?) ?? false,
      agreed: (raw['agreed'] as bool?) ?? false,
      requiresResign: (raw['requiresResign'] as bool?) ?? false,
      errorCode: (raw['errorCode'] as num?)?.toInt() ?? 0,
      errorMessage: (raw['errorMessage'] as String?) ?? '',
    );
  } catch (e, s) {
    log.error('[AppUpdate] requestPrivacyConsent 调用失败', e, s);
    return null;
  }
}

/// 最近一次 checkAppUpdate 的缓存。
///
/// 首页通知卡片每次重建都会调用本接口，而 AppGallery 侧有频率限制
/// （错误码 1009400006），所以默认 10 分钟内复用结果；用户手动点
/// 「检查更新」时用 `force: true` 绕过缓存。
AppUpdateResult? _cachedResult;
DateTime? _cachedAt;
const Duration _cacheTtl = Duration(minutes: 10);

/// 在途请求。
///
/// 启动时 `main.dart` 的启动检查与首页/登录页加载时的检查几乎同时发生，
/// 而缓存要等第一次**返回之后**才写入 —— 两者之间有个空档，实测会连打两次
/// 应用市场接口（2026-09-17 真机日志：15:35:40.908 与 15:35:41.751 各一次）。
/// 用同一个 Future 复用，保证同一时刻只有一个请求在途；市场侧有限流
/// （1009400006），少打一次是一次。
Future<AppUpdateResult?>? _inFlight;

/// 调用华为应用市场检查更新。非鸿蒙平台返回 null。
Future<AppUpdateResult?> checkAppUpdate({bool force = false}) {
  if (!Platform.isOhos) {
    return Future<AppUpdateResult?>.value(null);
  }
  if (!force &&
      _cachedResult != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl) {
    return Future<AppUpdateResult?>.value(_cachedResult);
  }
  final pending = _inFlight;
  if (pending != null) {
    return pending;
  }
  final future = _checkAppUpdateOnce();
  _inFlight = future;
  return future.whenComplete(() {
    _inFlight = null;
  });
}

Future<AppUpdateResult?> _checkAppUpdateOnce() async {
  try {
    final raw = await _appUpdateChannel.invokeMapMethod<dynamic, dynamic>(
      'checkAppUpdate',
    );
    if (raw == null) {
      return null;
    }
    final result = AppUpdateResult(
      updateAvailable: (raw['updateAvailable'] as num?)?.toInt() ?? 0,
      versionName: (raw['versionName'] as String?) ?? '',
      versionCode: (raw['versionCode'] as num?)?.toInt() ?? 0,
      errorCode: (raw['errorCode'] as num?)?.toInt() ?? 0,
      errorMessage: (raw['errorMessage'] as String?) ?? '',
    );
    _cachedResult = result;
    _cachedAt = DateTime.now();
    return result;
  } catch (e, s) {
    log.error('[AppUpdate] checkAppUpdate 调用失败', e, s);
    return null;
  }
}

/// 弹出华为应用市场更新弹窗。非鸿蒙平台返回失败结果。
Future<AppUpdateDialogResult> showAppUpdateDialog() async {
  if (!Platform.isOhos) {
    return const AppUpdateDialogResult(resultCode: 1);
  }
  try {
    final raw = await _appUpdateChannel.invokeMapMethod<dynamic, dynamic>(
      'showUpdateDialog',
    );
    return AppUpdateDialogResult(
      resultCode: (raw?['resultCode'] as num?)?.toInt() ?? 1,
      errorCode: (raw?['errorCode'] as num?)?.toInt() ?? 0,
      errorMessage: (raw?['errorMessage'] as String?) ?? '',
    );
  } catch (e, s) {
    log.error('[AppUpdate] showUpdateDialog 调用失败', e, s);
    return const AppUpdateDialogResult(resultCode: 1, errorCode: -1);
  }
}
