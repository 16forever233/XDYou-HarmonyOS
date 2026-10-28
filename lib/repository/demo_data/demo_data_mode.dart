// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:signals/signals.dart';
import 'package:watermeter/bridge/app_info.dart';
import 'package:watermeter/model/home_arrangement.dart';
import 'package:watermeter/repository/demo_data/review_account.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as preference;

/// 演示数据（截图模式）是否开启。
///
/// 只有 [DemoDataMode.enabled] 为 true 时才是真的生效（正式包恒为 false）。
final Signal<bool> demoDataEnabledSignal = signal<bool>(false);

/// 演示数据（截图模式）开关。
///
/// 用途：拍应用市场宣传图时，把 App 变成"一个满数据的假学生"——
/// 首页 / 睿思 / 课表三个页面全部由虚构数据填充，**不显示任何真实个人信息**，
/// 且期间不发业务网络请求（没有加载中、没有报错、没有"数据来自缓存"提示）。
///
/// 安全约束（改这个模块时务必遵守）：
/// 1. **只在内存里注入**，绝不调用任何 `saveCache/updateCacheAndUpdateGroup`；
/// 2. **不碰真实凭据**（`idsAccount`/`idsPassword`/`ruisi_*` 一律不动）；
/// 3. 只在 [available] 为真时生效：调试签名包，或正式包里用**审核体验账号**
///    登录后（见 `review_account.dart`）；其余正式包启动时强制关闭；
/// 4. 关闭后各控制器走真实路径重新加载，即可恢复真实数据。
abstract final class DemoDataMode {
  /// 本安装包是否允许使用演示数据。
  ///
  /// 两条途径：
  /// ① **调试签名包**（与「考试调试」同一门禁）；
  /// ② **正式包里用审核体验账号登录后**（见 `review_account.dart`）——
  ///    审核员装的是应用市场的正式包，必须能打开本地示例数据才审得下去。
  /// 除此之外的正式包恒为 false（启动时会强制关闭并清掉遗留开关）。
  static bool get available => isDebugProvisioned || ReviewAccount.active;

  /// 演示数据当前是否生效。
  static bool get enabled => available && demoDataEnabledSignal.value;

  /// 演示身份（编得像真的、但全部虚构；不会写进任何偏好）。
  static const String studentId = "2026112345";
  static const String studentName = "张明";
  static const String ruisiUsername = "张明";

  /// 启动时解析一次（[main] 里调用）。
  ///
  /// 正式包（[available] == false）里强制关闭并清掉偏好，避免出现"市场包里还在演示"。
  ///
  /// **必须容错**：这个函数跑在 `runApp` 之前，一旦抛异常 App 就会停在启动页
  /// （实际踩过：偏好 `type` 写成 `"Bool"` 而守卫要求小写 `'bool'`，
  /// `getBool` 直接抛 `WrongTypeException` → 界面永远起不来）。
  static Future<void> resolve() async {
    var stored = false;
    try {
      stored = preference.getBool(preference.Preference.demoDataEnabled);
    } catch (e) {
      log.error('[DemoDataMode] 读取演示数据开关失败（按未开启处理）：$e');
      demoDataEnabledSignal.value = false;
      return;
    }
    if (!available) {
      if (stored) {
        try {
          await preference.setBool(
            preference.Preference.demoDataEnabled,
            false,
          );
          log.info('[DemoDataMode] 正式包，已清除遗留的演示数据开关');
        } catch (e) {
          log.error('[DemoDataMode] 清除演示数据开关失败：$e');
        }
      }
      demoDataEnabledSignal.value = false;
      return;
    }
    demoDataEnabledSignal.value = stored;
    log.info('[DemoDataMode] 启动解析：enabled=$stored');
  }

  /// 仅改内存态（供 [DemoDataModeService] 在应用/清除过程中使用）。
  static void setEnabledInMemory(bool value) {
    demoDataEnabledSignal.value = available && value;
  }

  /// 写偏好（不负责应用/清除假数据，由 `DemoDataModeService` 统一做）。
  static Future<void> persist(bool value) async {
    try {
      await preference.setBool(preference.Preference.demoDataEnabled, value);
    } catch (e) {
      log.error('[DemoDataMode] 写入演示数据开关失败：$e');
    }
  }

  /// 演示态下用于"当前时间"判断的时间：**固定为当天的 10:20**。
  ///
  /// 为什么需要它：App 里有两处按"现在"隐藏内容 ——
  /// ① 首页「今日日程」会过滤掉 `endTime <= 现在` 的条目
  ///    （`homepage_controller.arrangementComputedSignal`）；
  /// ② 课表会把已上完的课画成"已完成"样式（`class_table_view` 的 `now`）。
  /// 如果直接用真实时间，晚上拍宣传图就会拍到空日程/整列变灰。
  /// 演示态统一按"上午 10:20"来算，任何时刻拍图都是一份自然的上午课表。
  ///
  /// 非演示态原样返回，**不影响真实逻辑**。
  static DateTime awareNow(DateTime realNow) {
    if (!enabled) {
      return realNow;
    }
    return DateTime(realNow.year, realNow.month, realNow.day, 10, 20);
  }

  /// 演示态「今日/明日日程」最多显示几条。
  ///
  /// 演示数据把课程、考试、实验、自定义课程都堆在同一天，不去管的话首页那张卡
  /// 会挤成 6~7 条，拍宣传图不好看。这里给一个上限，并且**优先保留类型不同的条目**
  /// （课程 / 考试 / 实验 / 自定义各留一条），保证画面既不过满、又能看出"什么都能聚合"。
  /// 想再少/再多改这一个数字即可。当前取 2：一条课程 + 一条考试（最抓眼）。
  static const int todayItemLimit = 2;

  /// 按 [todayItemLimit] 裁剪演示日程：先"每种类型各留一条"，再按时间顺序补齐到上限。
  /// 真实数据不调用这个方法。
  static List<HomeArrangement> limitTodayItems(List<HomeArrangement> items) {
    if (items.length <= todayItemLimit) {
      return items;
    }
    final kept = <HomeArrangement>[];
    final usedTypes = <String>{};
    // 第一轮：每种类型先留一条（保持原顺序，即时间顺序）
    for (final item in items) {
      if (kept.length >= todayItemLimit) {
        break;
      }
      if (usedTypes.add(item.type)) {
        kept.add(item);
      }
    }
    // 第二轮：还不够就用剩下的补满
    for (final item in items) {
      if (kept.length >= todayItemLimit) {
        break;
      }
      if (!kept.contains(item)) {
        kept.add(item);
      }
    }
    kept.sort();
    return kept;
  }
}
