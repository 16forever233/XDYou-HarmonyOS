// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _appInfoChannel = MethodChannel('xdyou/app_info');

bool _isDebugProvisioned = false;
int _deviceSdkApiVersion = 0;

/// 当前安装包是否为「调试签名」（鸿蒙 debug profile / 其他平台 debug 构建）。
///
/// 用途：调试入口（考试调试）只在调试包里出现 ——
/// 真机测试装的都是调试签名包（publish 证书签名的包在真机上装不上），
/// 而应用市场里的正式包是 release profile，会自动隐藏调试入口。
bool get isDebugProvisioned => _isDebugProvisioned;

/// 设备实际 API 等级（**不是**应用的 targetSdkVersion）。读不到时为 0。
///
/// 用途：按设备能力决定系统能力上限，例如代理提醒的调度条数
/// （API 26+ 配额 64、API ≤25 为 30，见 `reminder_quota.dart`）。
int get deviceSdkApiVersion => _deviceSdkApiVersion;

/// 启动时解析一次（[main] 里调用）。解析失败按 false 处理（更安全）。
Future<void> resolveDebugProvisioned() async {
  if (!Platform.isOhos) {
    _isDebugProvisioned = kDebugMode;
    return;
  }
  try {
    _isDebugProvisioned =
        await _appInfoChannel.invokeMethod<bool>('isDebugProvisioned') ?? false;
  } on PlatformException {
    _isDebugProvisioned = false;
  } on MissingPluginException {
    _isDebugProvisioned = false;
  }
}

/// 启动时解析一次（[main] 里调用）。读不到时保持 0（调用方按"最保守"处理）。
Future<void> resolveDeviceSdkApiVersion() async {
  if (!Platform.isOhos) {
    return;
  }
  try {
    _deviceSdkApiVersion =
        await _appInfoChannel.invokeMethod<int>('sdkApiVersion') ?? 0;
  } on PlatformException {
    _deviceSdkApiVersion = 0;
  } on MissingPluginException {
    _deviceSdkApiVersion = 0;
  }
}
