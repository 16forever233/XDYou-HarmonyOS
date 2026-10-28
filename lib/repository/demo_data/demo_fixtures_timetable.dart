// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:intl/intl.dart';
import 'package:watermeter/model/pda_service/custom_class.dart';
import 'package:watermeter/model/xidian_ids/classtable.dart';

/// 演示用课表 / 自定义课程（**全部虚构**，不指向任何真人真课）。
///
/// 生成规则（依据解析器与课表布局的实际语义）：
/// - `TimeArrangement.start/stop` 是**闭区间的节次序号**（与教务 `KSJCDM/JSJCDM` 一致），
///   节次 1..11 分别对应 `timeList[(n-1)*2]` 起、`timeList[(n-1)*2+1]` 止；
/// - `day` 1..7 表示周一..周日；`weekList` 长度 = `semesterLength`（20 周），1~16 周有课；
/// - `termStartDay` = **本周一往前 8 周**，保证截图当天永远落在"第 9 周"（不会显示"假期中"）；
/// - `index` 指向 `classDetail[index]`，两端必须一致。
///
/// **时间不随"拍摄时刻"变化**：今天也是这份固定课表（上午/下午自然分布）。
/// 拍图时会因为"已经上完的课"而被隐藏/变灰 —— 这由 `demoAwareNow()`
/// （把演示态的"现在"固定为当天 10:20）解决，而不是去改课表本身。
const int _semesterLength = 20;
const int _lastTeachingWeek = 16;

/// 演示学期码（形式与教务一致）。
const String demoSemesterCode = "2026-2027-1";

/// 课程名（按 index 与 [_demoEntries] 对应）。
const List<String> _demoCourseNames = [
  "高等数学（下）",
  "大学物理",
  "程序设计基础",
  "离散数学",
  "大学英语",
  "线性代数",
  "概率论与数理统计",
  "思想道德与法治",
  "体育（篮球）",
  "形势与政策",
];

/// 一条「星期、节次、课程、教室、老师」记录。
class _DemoEntry {
  final int day;
  final int start;
  final int stop;
  final int course;
  final String classroom;
  final String teacher;

  const _DemoEntry(
    this.day,
    this.start,
    this.stop,
    this.course,
    this.classroom,
    this.teacher,
  );
}

/// 周一到周五的课表（共 17 节次块，看起来像一份真实的工科课表）。
const List<_DemoEntry> _demoEntries = [
  // 周一
  _DemoEntry(1, 1, 2, 0, "A-101", "张伟"),
  _DemoEntry(1, 3, 4, 1, "B-203", "李静"),
  _DemoEntry(1, 6, 7, 4, "C-305", "陈晨"),
  _DemoEntry(1, 9, 10, 8, "体育馆", "吴涛"),
  // 周二
  _DemoEntry(2, 1, 2, 2, "计算中心-2", "王强"),
  _DemoEntry(2, 3, 4, 5, "A-102", "赵敏"),
  _DemoEntry(2, 6, 8, 3, "B-201", "刘洋"),
  // 周三
  _DemoEntry(3, 1, 2, 1, "B-203", "李静"),
  _DemoEntry(3, 3, 4, 0, "A-101", "张伟"),
  _DemoEntry(3, 6, 7, 6, "A-203", "孙鹏"),
  _DemoEntry(3, 9, 10, 7, "D-401", "周晓"),
  // 周四
  _DemoEntry(4, 1, 2, 2, "计算中心-2", "王强"),
  _DemoEntry(4, 3, 4, 4, "C-305", "陈晨"),
  _DemoEntry(4, 6, 7, 5, "A-102", "赵敏"),
  // 周五
  _DemoEntry(5, 1, 2, 0, "A-101", "张伟"),
  _DemoEntry(5, 3, 4, 6, "A-203", "孙鹏"),
  _DemoEntry(5, 6, 7, 9, "D-402", "郑华"),
];

/// 本周一的零点（用于推算学期开始日与自定义课程日期）。
DateTime _thisMonday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}

/// 今天/明天的某个时刻。
DateTime _dayAt(int dayOffset, int hour, int minute) {
  final day = _thisMonday().add(
    Duration(days: DateTime.now().weekday - 1 + dayOffset),
  );
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// 演示课表数据。
ClassTableData buildDemoClassTable() {
  final weekList = List<bool>.generate(
    _semesterLength,
    (index) => index < _lastTeachingWeek,
    growable: false,
  );

  return ClassTableData(
    semesterLength: _semesterLength,
    semesterCode: demoSemesterCode,
    // 往前 8 周 → 当前是第 9 周（`getCurrentWeek` 返回 0 基，界面显示 +1）
    termStartDay: DateFormat("yyyy-MM-dd").format(
      _thisMonday().subtract(const Duration(days: 7 * 8)),
    ),
    classDetail: [
      for (final name in _demoCourseNames)
        ClassDetail(
          name: name,
          code: "DEMO${_demoCourseNames.indexOf(name) + 1}",
          number: "01",
        ),
    ],
    notArranged: [
      NotArrangementClassDetail(
        name: "毕业设计（选题中）",
        code: "DEMO90",
        number: "01",
        teacher: "待定",
      ),
      NotArrangementClassDetail(
        name: "创新创业实践",
        code: "DEMO91",
        number: "02",
        teacher: "马宁",
      ),
    ],
    timeArrangement: [
      for (final entry in _demoEntries)
        TimeArrangement(
          source: Source.school,
          index: entry.course,
          weekList: weekList,
          teacher: entry.teacher,
          day: entry.day,
          start: entry.start,
          stop: entry.stop,
          classroom: entry.classroom,
        ),
    ],
    // 调课留空：真实数据里的调课记录字段很多，演示态不造这条以免展示错乱
    classChanges: const [],
  );
}

/// 演示用自定义课程（今天 1 条 + 明天 1 条，让首页日程更丰富）。
///
/// 时间固定（今天傍晚 18:30-20:00、明天下午），不随拍摄时刻变化 ——
/// 是否"已结束"由 `demoAwareNow()` 统一处理。
List<CustomClass> buildDemoCustomClasses() {
  return [
    CustomClass(
      id: "demo-custom-1",
      name: "实验室安全培训",
      teacher: "实验中心",
      classroom: "E-101",
      timeRanges: [
        CustomClassTimeRange(
          id: "demo-custom-1-a",
          startTime: _dayAt(0, 18, 30),
          endTime: _dayAt(0, 20, 0),
        ),
      ],
    ),
    CustomClass(
      id: "demo-custom-2",
      name: "学术前沿讲座",
      teacher: "王建国",
      classroom: "图书馆报告厅",
      timeRanges: [
        CustomClassTimeRange(
          id: "demo-custom-2-a",
          startTime: _dayAt(1, 14, 0),
          endTime: _dayAt(1, 15, 30),
        ),
      ],
    ),
  ];
}
