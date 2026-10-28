// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as preference;

/// 审核体验账号（应用市场审核员专用）。
///
/// 背景：审核员装的是**应用市场里的正式签名包**，既没有西电学号、也过不了
/// 统一身份认证与验证码，因此没法看到登录之后长什么样。这里内置一个本地账号：
/// 用它登录**不发任何网络请求、不弹验证码**，直接进入「本地示例数据」模式
/// （复用 `demo_data_mode` 那套 fixtures），审核员就能看到完整界面。
///
/// **这组凭据要写进 AGC 的审核说明**（与 `docs/应用商店测试说明.md` 一致）。
///
/// 安全约束（与 `DemoDataMode` 同一套思路，改这个模块时务必遵守）：
/// 1. **绝不写凭据**：`idsAccount` / `idsPassword` / `ruisi_*` 一律不碰，
///    登录态靠 `DemoDataMode.enabled` 让 `isFirst` 为 false 来维持；
/// 2. **展示的全是本地虚构数据**（见 `demo_fixtures_*.dart`），
///    不涉及任何真实学生信息，也不访问任何校内系统；
/// 3. 只在用户**主动输入这组凭据**时启用，行为可预期；
/// 4. 「设置 → 退出登录」会清空全部偏好 → 体验模式一并结束。
///
/// ⚠️ 这组凭据必然硬编码在包里（审核账号只能如此），所以**不要把它当成权限边界**：
/// 它唯一的"权限"是打开一份本地假数据，既碰不到服务器也拿不到真实用户信息。
abstract final class ReviewAccount {
  /// 审核体验账号的学号。
  static const String account = "2026112345";

  /// 审核体验账号的密码。
  static const String password = "xdyou2026";

  /// 体验模式下展示的身份（与演示数据保持一致）。
  static const String displayName = "张明";

  static bool _active = false;

  /// 体验模式是否已启用。`DemoDataMode.available` 依赖它。
  static bool get active => _active;

  /// 输入的是不是审核账号。学号两端空白做宽松处理，避免误判。
  static bool matches(String id, String pass) =>
      id.trim() == account && pass == password;

  /// 启动时解析一次（[main] 里调用，**必须早于 `DemoDataMode.resolve()`**）。
  ///
  /// 与 `DemoDataMode.resolve()` 一样跑在 `runApp` 之前，**必须容错**：
  /// 读偏好失败一律按"未启用"处理，绝不能让 App 停在启动页
  /// （历史上偏好 `type` 写错大小写就把 App 卡在启动页过一次）。
  static Future<void> resolve() async {
    try {
      _active = preference.getBool(preference.Preference.reviewAccountEnabled);
    } catch (e) {
      log.error('[ReviewAccount] 读取体验模式开关失败（按未启用处理）：$e');
      _active = false;
    }
    log.info('[ReviewAccount] 启动解析：active=$_active');
  }

  /// 启用体验模式，并写入偏好（重启/杀进程后仍生效）。
  static Future<void> enable() async {
    _active = true;
    try {
      await preference.setBool(
        preference.Preference.reviewAccountEnabled,
        true,
      );
      log.info('[ReviewAccount] 已启用审核体验模式');
    } catch (e) {
      log.error('[ReviewAccount] 写入体验模式开关失败：$e');
    }
  }

  /// 关闭体验模式。
  ///
  /// 当前没有直接调用点：「设置 → 退出登录」是把偏好整体清掉的，重启后自然就没了。
  /// 保留此方法供将来做"退出体验模式"入口时使用。
  static Future<void> disable() async {
    _active = false;
    try {
      await preference.setBool(
        preference.Preference.reviewAccountEnabled,
        false,
      );
      log.info('[ReviewAccount] 已关闭审核体验模式');
    } catch (e) {
      log.error('[ReviewAccount] 清除体验模式开关失败：$e');
    }
  }
}
