// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/bridge/platform_capability.dart';

import 'package:flutter/services.dart';

const MethodChannel _nativeScanChannel = MethodChannel('xdyou/native_scan');

/// 拉起鸿蒙原生扫码（Scan Kit 默认界面扫码），返回扫描到的原始文本。
///
/// - 仅在 ohos 平台有效，其他平台返回 null；
/// - 用户取消扫码时返回 null；
/// - 默认界面扫码是系统级能力，无需 AGC 配置（相机权限已系统预授权）；
///   若调用失败会抛出 [PlatformException]，调用方应决定是否回退到应用内扫码。
Future<String?> nativeScanQrCode() async {
  if (!supportsNativeScan) {
    return null;
  }
  try {
    final String? result = await _nativeScanChannel.invokeMethod<String>(
      'startScan',
    );
    return result;
  } on MissingPluginException {
    return null;
  }
}
