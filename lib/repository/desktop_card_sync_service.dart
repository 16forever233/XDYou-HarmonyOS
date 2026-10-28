// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:intl/intl.dart';
import 'package:watermeter/bridge/desktop_card.dart';
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/global_timer_controller.dart';
import 'package:watermeter/controller/homepage_controller.dart';
import 'package:watermeter/model/home_arrangement.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as preference;
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';

/// 鸿蒙桌面卡片写入的窗口天数（今天起，含今天）。
///
/// 卡片端按设备日期从这个窗口里取“今天/明天”，所以窗口至少要有 2 天；
/// 取 7 天可保证跨天后打开卡片仍有数据、点“明日”也有内容，无需开 App。
const int desktopCardWindowDays = 7;

/// 上次**成功写入**卡片的数据指纹（进程内）。
///
/// 冷启动（`main.dart`）、登录回调、首页数据就绪的 effect 都会调用
/// [syncDesktopCard]，其中前两次经常发生在课表数据到位之前 —— 那时写进卡片的
/// 是空窗口，卡片只能显示「暂无课程」。内容完全一致时重复写盘 + 通知卡片没有
/// 任何意义（还白白多推一次），这里用内容指纹去重：只有内容真的变了才写。
String? _lastSyncedFingerprint;

/// 卡片数据的内容指纹：登录态 + 演示模式 + 错误提示 + 7 天窗口
/// （视图内的课程条数、时间、名称、地点、颜色都算进去）。
String _cardFingerprint({
  required bool isLoggedIn,
  required bool isDemo,
  required String errorType,
  required Map<String, DesktopCardDayData> days,
}) {
  final buffer = StringBuffer()
    ..write(isLoggedIn ? 'L' : 'l')
    ..write(isDemo ? 'D' : 'd')
    ..write(errorType)
    ..write('#');
  final keys = days.keys.toList()..sort();
  for (final key in keys) {
    final day = days[key]!;
    buffer
      ..write(key)
      ..write(':')
      ..write(day.week)
      ..write(':');
    for (final item in day.items) {
      buffer
        ..write(item.startTime)
        ..write('-')
        ..write(item.endTime)
        ..write(item.name)
        ..write('/')
        ..write(item.type)
        ..write('/')
        ..write(item.place)
        ..write('/')
        ..write(item.seat)
        ..write('/')
        ..write(item.colorIndex)
        ..write(';');
    }
    buffer.write('|');
  }
  return buffer.toString();
}

/// 根据首页聚合数据刷新鸿蒙桌面卡片。
///
/// 写入今天起 [desktopCardWindowDays] 天的完整日程（**不做时间过滤**，
/// 由卡片按设备时间过滤已结束条目），日程类型与 iOS 一致：
/// 课程 / 考试 / 实验 / 自定义。
Future<void> syncDesktopCard() async {
  final now = GlobalTimerController.i.currentTimeSignal.value;
  final homepage = HomepageController.i;

  /// 第 N 周 / 假期中；无课表数据时返回空串。
  String weekLabelFor(DateTime day) {
    final controller = ClassTableController.i;
    final week = controller.getCurrentWeek(day);
    if (week < 0) {
      return '';
    }
    final semesterLength = controller.classTableComputedSignal.value
        .semesterLength;
    if (week >= semesterLength) {
      return '假期中';
    }
    return '第 ${week + 1} 周';
  }

  // 调试签名包注入的「模拟考试」不在这里处理：它已并进
  // `ExamController.subjects`（见 exam_controller.dart），会随
  // `homepage.arrangementsOfDay` → `examsOfDay` 一起进窗口，
  // 在这里再并一次会变成两条。

  DesktopCardDayData buildDayData(
    List<HomeArrangement> arrangements,
    DateTime day,
  ) {
    final items = arrangements
        .map(
          (e) => DesktopCardItem(
            type: e.type,
            name: e.name,
            teacher: e.teacher ?? '',
            place: e.place ?? '',
            seat: e.seat ?? '',
            startTime: DateFormat('HH:mm').format(e.startTime),
            endTime: DateFormat('HH:mm').format(e.endTime),
            colorIndex: e.colorIndex ?? 0,
          ),
        )
        .toList();
    items.sort((a, b) => a.startTime.compareTo(b.startTime));
    return DesktopCardDayData(
      date: DateFormat('M月d日 E').format(day),
      week: weekLabelFor(day),
      items: items,
    );
  }

  // 演示数据（截图模式）下没有真实账号，但卡片要当作已登录显示日程，
  // 否则宣传图里的桌面卡片会写着「未登录」。
  final loggedIn = DemoDataMode.enabled ||
      preference.getString(preference.Preference.idsAccount).isNotEmpty;

  final days = <String, DesktopCardDayData>{};
  for (var i = 0; i < desktopCardWindowDays; i++) {
    final day = now.add(Duration(days: i));
    final isoDate = DateFormat('yyyy-MM-dd').format(day);
    days[isoDate] = buildDayData(homepage.arrangementsOfDay(day), day);
  }

  // 卡片级错误提示：
  // ① 课表本身加载失败（卡片的主要内容来源）；或
  // ② 有数据源失败且整个窗口没有任何日程（否则会用错误页盖住本来能显示的课表）。
  final failedSources = homepage.failedSourcesComputedSignal.value;
  final windowHasItems = days.values.any((e) => e.items.isNotEmpty);
  var errorType = '';
  var error = '';
  if (failedSources.isNotEmpty) {
    final primaryFailed = failedSources.contains(HomepageFailedSource.classInfo);
    if (primaryFailed || !windowHasItems) {
      final source = primaryFailed
          ? HomepageFailedSource.classInfo
          : failedSources.first;
      errorType = source.name;
      error = switch (source) {
        HomepageFailedSource.classInfo => '课程数据加载失败，打开应用重试',
        HomepageFailedSource.examInfo => '考试数据加载失败，打开应用重试',
        HomepageFailedSource.physicsExperiment => '物理实验数据加载失败，打开应用重试',
        HomepageFailedSource.otherExperiment => '实验数据加载失败，打开应用重试',
      };
    }
  }

  log.info(
    '[syncDesktopCard] loggedIn=$loggedIn, window=$desktopCardWindowDays, '
    'today=${days.values.first.items.length}, errorType=$errorType',
  );

  final fingerprint = _cardFingerprint(
    isLoggedIn: loggedIn,
    isDemo: DemoDataMode.enabled,
    errorType: errorType,
    days: days,
  );
  if (fingerprint == _lastSyncedFingerprint) {
    // 内容没变：卡片端轮询比较的推送签名也不会变，重复写盘 + 推送纯属浪费。
    log.info('[syncDesktopCard] unchanged, skip card update.');
    return;
  }

  final saved = await saveDesktopCardData(
    isLoggedIn: loggedIn,
    isTomorrow: false,
    days: days,
    errorType: errorType,
    error: error,
    // 演示数据（截图模式）：卡片端也跳过"已结束"过滤，
    // 否则晚上拍宣传图时卡片会空掉或显示「今日课程已结束」。
    isDemo: DemoDataMode.enabled,
  );
  // 只有写入成功才记住指纹：写失败（如通道异常）时保留旧指纹，
  // 下一次调用会重试，不会因为"以为写过了"而让卡片一直停在旧数据上。
  if (saved) {
    _lastSyncedFingerprint = fingerprint;
  }
}
