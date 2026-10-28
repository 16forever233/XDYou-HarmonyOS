// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:intl/intl.dart';
import 'package:watermeter/model/xidian_ids/exam.dart';
import 'package:watermeter/model/xidian_ids/experiment.dart';

/// 演示用考试 / 实验数据（**全部虚构**）。
///
/// 时间**固定**（今天 10:00~17:30 之间自然分布），不随拍摄时刻变化；
/// "已结束的要不要显示"由演示态的"现在"（`demoAwareNow()`）统一处理，
/// 这样任何时刻拍图，首页「今日日程」都是一份完整的日程。
const String _datePattern = "yyyy-MM-dd HH:mm";

/// 今天（+[dayOffset] 天）的某个时刻。
DateTime _dayAt(int dayOffset, int hour, int minute) {
  final now = DateTime.now();
  final day = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: dayOffset));
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// 演示考试数据（3 场：今天下午 1 场，其余在本周内）。
ExamData buildDemoExamData() {
  Subject build({
    required String subject,
    required String place,
    required String seat,
    required DateTime start,
    required Duration length,
  }) => Subject.generate(
    subject: subject,
    typeStr: "期末考试",
    time:
        "${DateFormat(_datePattern).format(start)}-"
        "${DateFormat("HH:mm").format(start.add(length))}",
    place: place,
    seat: seat,
  );

  return ExamData(
    subject: [
      build(
        subject: "高等数学（下）",
        place: "A-101",
        seat: "12",
        start: _dayAt(0, 14, 0),
        length: const Duration(hours: 2),
      ),
      build(
        subject: "大学物理",
        place: "B-305",
        seat: "28",
        start: _dayAt(3, 9, 0),
        length: const Duration(hours: 2),
      ),
      build(
        subject: "程序设计基础",
        place: "计算中心-2",
        seat: "05",
        start: _dayAt(6, 14, 30),
        length: const Duration(hours: 2, minutes: 30),
      ),
    ],
    toBeArranged: const [],
  );
}

/// 演示实验数据（物理 2 个，今天上午 1 个）。
List<ExperimentData> buildDemoPhysicsExperiments() {
  return [
    ExperimentData(
      type: ExperimentType.physics,
      name: "示波器的使用",
      classroom: "物理实验楼 204",
      teacher: "杨帆",
      reference: "《大学物理实验》第三版 P78",
      timeRanges: [(_dayAt(0, 10, 0), _dayAt(0, 12, 0))],
    ),
    ExperimentData(
      type: ExperimentType.physics,
      name: "迈克尔逊干涉仪的调节与使用",
      classroom: "物理实验楼 208",
      teacher: "杨帆",
      reference: "《大学物理实验》第三版 P102",
      timeRanges: [(_dayAt(3, 14, 0), _dayAt(3, 16, 0))],
    ),
  ];
}

/// 演示实验数据（其他类，今天下午 1 个）。
List<ExperimentData> buildDemoOtherExperiments() {
  return [
    ExperimentData(
      type: ExperimentType.others,
      name: "电路基础实验",
      classroom: "实验楼 A-305",
      teacher: "何静",
      reference: "实验指导书第 4 章",
      timeRanges: [(_dayAt(0, 15, 30), _dayAt(0, 17, 30))],
    ),
    ExperimentData(
      type: ExperimentType.others,
      name: "数字电路综合实验",
      classroom: "实验楼 A-308",
      teacher: "何静",
      reference: "实验指导书第 7 章",
      timeRanges: [(_dayAt(4, 15, 0), _dayAt(4, 17, 0))],
    ),
  ];
}
