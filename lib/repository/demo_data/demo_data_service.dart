// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/custom_class_controller.dart';
import 'package:watermeter/controller/energy_controller.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/controller/library_controller.dart';
import 'package:watermeter/controller/other_experiment_controller.dart';
import 'package:watermeter/controller/physics_experiment_controller.dart';
import 'package:watermeter/controller/school_card_controller.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_timetable.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as preference;

/// 演示数据的应用 / 刷新 / 清除。
///
/// 设计要点：
/// - **只在内存里注入**：调用各控制器的 `applyDemoFixture()`，不经过任何
///   `saveCache/updateCacheAndGroup`，因此真实缓存与真实偏好完全不受影响；
/// - 演示期间各控制器的 `reload*()` 会首行早退（见控制器实现），不会发网络请求；
/// - 关闭时把开关翻掉并让控制器走真实路径重新加载，真实数据自然回来。
abstract final class DemoDataModeService {
  /// 打开演示数据：先置内存标志（后续 reload 会早退），再把假数据推给各控制器。
  static Future<void> applyAll() async {
    if (!DemoDataMode.available) {
      log.warning('[DemoDataMode] 非测试签名包，忽略开启演示数据的请求');
      return;
    }
    DemoDataMode.setEnabledInMemory(true);
    await _ensureSemester();
    refreshAll();
    log.info('[DemoDataMode] 已开启演示数据');
  }

  /// 确保「当前学期」偏好有值。
  ///
  /// **为什么演示态也要写一次偏好**：不少页面直接读 `Preference.currentSemester`，
  /// 其中「空闲教室」最脆弱 —— 它拿学期码做 `int.parse(code.substring(0, 4))`，
  /// 空串会抛 RangeError，页面直接变成「发生错误啦」（2026-09-14 真机实测）。
  /// 真实登录本来就会写这个偏好（见 `login_window.dart` 登录成功后的 setString），
  /// 但审核体验账号不走真实登录，所以在这里补上，与演示课表用同一个学期码。
  ///
  /// ⚠️ **只在为空时补，绝不覆盖**：截图模式跑在作者的日常包上，
  /// 覆盖了会把真实学期改掉，那就违背了"演示数据不碰真实数据"的前提。
  static Future<void> _ensureSemester() async {
    try {
      if (preference
          .getString(preference.Preference.currentSemester)
          .isEmpty) {
        await preference.setString(
          preference.Preference.currentSemester,
          demoSemesterCode,
        );
        log.info('[DemoDataMode] 当前学期偏好为空，已补为演示学期 $demoSemesterCode');
      }
    } catch (e) {
      log.error('[DemoDataMode] 补写演示学期失败：$e');
    }
  }

  /// 重新生成一遍"今天"的假数据（跨天或改了时间后用来刷新）。
  ///
  /// 各 fixture 的时间都是固定的（不随拍摄时刻变化），这里只负责按序注入。
  static void refreshAll() {
    if (!DemoDataMode.enabled) return;

    ClassTableController.i.applyDemoFixture();
    ExamController.i.applyDemoFixture();
    PhysicsExperimentController.i.applyDemoFixture();
    OtherExperimentController.i.applyDemoFixture();
    CustomClassController.i.applyDemoFixture();
    EnergyController.i.applyDemoFixture();
    LibraryController.i.applyDemoFixture();
    SchoolCardController.i.applyDemoFixture();
  }

  /// 关闭演示数据：翻转标志后让各控制器重新加载真实数据。
  static Future<void> clearAll() async {
    DemoDataMode.setEnabledInMemory(false);
    log.info('[DemoDataMode] 已关闭演示数据，开始重新加载真实数据');

    // 顺序无所谓：每个 reload 都是独立的数据源；失败会被各自 catch 成错误态，
    // 不影响其它页面。
    await Future.wait([
      ClassTableController.i.reloadClassTable(),
      ExamController.i.reloadExamInfo(),
      PhysicsExperimentController.i.reloadPhysicsExperiment(),
      OtherExperimentController.i.reloadOtherExperiment(),
      EnergyController.i.refreshElectricityInfo(force: true),
      LibraryController.i.reloadBorrowList(),
      SchoolCardController.i.reloadOverview(),
    ]);
  }
}
