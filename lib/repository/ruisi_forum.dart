// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:signals/signals.dart';
import 'package:watermeter/bridge/app_info.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as preference;

/// 睿思论坛显示开关的信号（UI 用 `SignalBuilder` 监听它实时重排页签）。
final Signal<bool> ruisiForumEnabledSignal = signal<bool>(false);

/// 睿思论坛的显示开关。
///
/// **默认一律隐藏**（发布包与调试包都一样）—— 睿思属校园 UGC 社区，
/// 监管审批通过前不对外提供。审批期间由开发者在
/// 「设置 → 调试 → 睿思论坛」临时打开自测。
///
/// **为什么开关只存在于调试签名包**（[available]）：如果正式包里也能打开，
/// 用户一开就等于应用在提供该功能，合规要求就白做了。因此正式包恒为隐藏，
/// 且启动时会把可能残留的开关值清掉。
///
/// 审批通过后的收尾（三处）：把 `bridge/platform_capability.dart` 的
/// `supportsRuisiForum` 直接改成 `true`，再删掉本模块与调试页里的那个开关。
abstract final class RuisiForum {
  /// 本安装包是否允许打开该开关。**只有调试签名包可以**。
  static bool get available => isDebugProvisioned;

  /// 当前是否显示睿思入口（非鸿蒙平台不受影响，见 `supportsRuisiForum`）。
  static bool get enabled => available && ruisiForumEnabledSignal.value;

  /// 启动时解析一次（[main] 里调用）。
  ///
  /// 与其它启动期偏好读取一样**必须容错**：这个函数跑在 `runApp` 之前，
  /// 一旦抛异常 App 就会停在启动页（历史上偏好 type 写错大小写踩过一次）。
  static Future<void> resolve() async {
    var stored = false;
    try {
      stored = preference.getBool(preference.Preference.ruisiForumEnabled);
    } catch (e) {
      log.error('[RuisiForum] 读取睿思开关失败（按隐藏处理）：$e');
      ruisiForumEnabledSignal.value = false;
      return;
    }

    if (!available) {
      // 正式包：强制隐藏，并清掉可能残留的开关值
      if (stored) {
        try {
          await preference.setBool(
            preference.Preference.ruisiForumEnabled,
            false,
          );
          log.info('[RuisiForum] 非调试签名包，已清除遗留的睿思开关');
        } catch (e) {
          log.error('[RuisiForum] 清除睿思开关失败：$e');
        }
      }
      ruisiForumEnabledSignal.value = false;
      return;
    }

    ruisiForumEnabledSignal.value = stored;
    log.info('[RuisiForum] 启动解析：enabled=$stored');
  }

  /// 打开 / 关闭睿思入口（调试页的开关调用它）。正式包里强制为 false。
  static Future<void> setEnabled(bool value) async {
    ruisiForumEnabledSignal.value = available && value;
    try {
      await preference.setBool(
        preference.Preference.ruisiForumEnabled,
        ruisiForumEnabledSignal.value,
      );
      log.info('[RuisiForum] 开关已设为 ${ruisiForumEnabledSignal.value}');
    } catch (e) {
      log.error('[RuisiForum] 写入睿思开关失败：$e');
    }
  }
}
