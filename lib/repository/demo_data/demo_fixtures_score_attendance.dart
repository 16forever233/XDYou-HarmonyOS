// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/model/xidian_ids/class_attendance.dart';
import 'package:watermeter/model/xidian_ids/score.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_timetable.dart';

/// 演示用**成绩**数据（全部虚构）。
///
/// 用途：审核体验账号登录后，「成绩查询」页要有像样的数据 —— 审核员没有真实学号，
/// 走不到真实接口。与课表演示数据用同一套课程名，保证各页面互相自洽。
///
/// 设计说明：
/// - 三个学期：`2025-2026-1`、`2025-2026-2` 已出分，当前学期 `2026-2027-1`
///   （= [demoSemesterCode]，即演示课表所在学期）只排了课、**成绩未出**（`score: null`
///   且 `isPassedStr: null`，界面显示「暂无」）—— 这正是开学初的真实样子。
/// - `classStatus` 用 `"选修 "`（**带一个尾空格**）与 `"必修"`：这个尾空格不是笔误，
///   `score_statics.dart` 的 `notCoreClassType = "选修 "` 就是照真实教务系统来的，
///   应用靠 `classStatus.contains("选修 ")` 统计"不参与均分的选修学分"，
///   少了这个空格那段统计会空掉。
/// - 故意混入 `军事理论` / `形势与政策` / `物理实验`：它们在 `score_statics.dart`
///   的 `courseIgnore` 里，默认不勾选参与均分 —— 演示数据的价值之一就是能看出这类规则在生效。
///
/// 全为虚构数据，不含任何真实学生信息；只在内存中使用，不落盘。
List<Score> buildDemoScores() {
  const List<List<Object?>> rows = [
    // [学期, 课程名, 学分, 分数, 课程性质, 课程类别, 修读类型]
    ["2025-2026-1", "高等数学（上）", 5.0, 92.0, "必修", "专业必修课", "初修"],
    ["2025-2026-1", "大学物理（上）", 3.5, 88.0, "必修", "专业必修课", "初修"],
    ["2025-2026-1", "程序设计基础", 3.0, 95.0, "必修", "专业必修课", "初修"],
    ["2025-2026-1", "大学英语（一）", 3.0, 85.0, "必修", "通识教育核心课", "初修"],
    ["2025-2026-1", "思想道德与法治", 3.0, 87.0, "必修", "通识教育核心课", "初修"],
    ["2025-2026-1", "体育（一）", 1.0, 90.0, "必修", "通识教育核心课", "初修"],
    ["2025-2026-1", "军事理论", 2.0, 86.0, "必修", "通识教育核心课", "初修"],
    ["2025-2026-1", "形势与政策（一）", 0.5, 91.0, "必修", "通识教育核心课", "初修"],

    ["2025-2026-2", "高等数学（下）", 5.0, 89.0, "必修", "专业必修课", "初修"],
    ["2025-2026-2", "大学物理（下）", 3.5, 91.0, "必修", "专业必修课", "初修"],
    ["2025-2026-2", "数据结构", 3.5, 93.0, "必修", "专业必修课", "初修"],
    ["2025-2026-2", "大学英语（二）", 3.0, 88.0, "必修", "通识教育核心课", "初修"],
    ["2025-2026-2", "线性代数", 3.0, 94.0, "必修", "专业必修课", "初修"],
    ["2025-2026-2", "体育（二）", 1.0, 91.0, "必修", "通识教育核心课", "初修"],
    ["2025-2026-2", "物理实验", 1.5, 90.0, "必修", "集中实践环节", "初修"],
    ["2025-2026-2", "中国近现代史纲要", 3.0, 89.0, "选修 ", "通识教育选修课", "初修"],

    // 当前学期：课在上、分还没出
    ["2026-2027-1", "概率论与数理统计", 3.0, null, "必修", "专业必修课", "初修"],
    ["2026-2027-1", "离散数学", 3.5, null, "必修", "专业必修课", "初修"],
    ["2026-2027-1", "数字电路与逻辑设计", 3.5, null, "必修", "专业必修课", "初修"],
    ["2026-2027-1", "体育（三）", 1.0, null, "必修", "通识教育核心课", "初修"],
  ];

  final List<Score> toReturn = [];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final double? score = row[3] as double?;
    toReturn.add(
      Score(
        mark: i,
        name: row[1] as String,
        score: score,
        semesterCode: row[0] as String,
        credit: row[2] as double,
        classStatus: row[4] as String,
        classType: row[5] as String,
        scoreStatus: row[6] as String,
        scoreTypeCode: 0, // 0 = 百分制（1/2/3 才是等级制）
        // 出分即通过（演示数据不留挂科），未出分则保持 null → 界面显示「暂无」
        isPassedStr: score == null ? null : (score >= 60 ? "1" : "0"),
        classID: "DEMO-CLASS-${i + 1}",
      ),
    );
  }
  return toReturn;
}

/// 演示用**成绩分项**（点开某门课看到的构成）。
///
/// 真实实现要按教学班去教务系统拉，演示态直接给一份通用水课构成，
/// 免得上网、也免得审核员点开是空白。
List<ComposeDetail> buildDemoScoreDetail(String courseName) {
  return [
    ComposeDetail(content: "平时成绩", ratio: "20%", score: "92"),
    ComposeDetail(content: "实验/作业", ratio: "20%", score: "90"),
    ComposeDetail(content: "期中考试", ratio: "20%", score: "88"),
    ComposeDetail(content: "期末考试", ratio: "40%", score: "91"),
  ];
}

/// 演示用**考勤**数据（全部虚构）。
///
/// 用途：审核体验账号登录后「考勤查询」页要有数据。同样沿用演示课表的课程名。
///
/// 刻意造出三种状态，好让审核员一眼看到页面的全部呈现：
/// - 正常到课（到课率 ≥ 80%）；
/// - **预警**（到课率 < 80%，`attendanceStatus` 会判为 `warning`）；
/// - **不合格**（`isWarning: true`，直接判为 `ineligible`）。
///
/// 注意 `attendanceRate` 的格式必须带 `" %"`（含空格），
/// 因为 `ClassAttendance.attendanceStatus` 是 `double.tryParse(rate.replaceAll(" %", ""))`，
/// 格式不对会退化成 `unknown`（显示成"未知"）。
List<ClassAttendance> buildDemoClassAttendances() {
  return const [
    ClassAttendance(
      courseName: "高等数学（下）",
      className: "高等数学（下）-01班",
      checkInCount: "15",
      personalLeave: "1",
      sickLeave: "0",
      officialLeave: "0",
      absenceCount: "0",
      requiredCheckIn: "16",
      attendanceRate: "93.75 %",
      readCount: "42",
      unreadCount: "3",
      accessCount: "58",
      taskProgress: "8/9",
      homeworkProgress: "6/6",
      examProgress: "1/2",
      discussionCount: "5",
      materialCount: "12",
      courseId: "DEMO-ATT-1",
      clazzId: "DEMO-ATT-1-C",
      cpi: "0",
    ),
    ClassAttendance(
      courseName: "大学物理",
      className: "大学物理-02班",
      checkInCount: "14",
      personalLeave: "0",
      sickLeave: "2",
      officialLeave: "0",
      absenceCount: "0",
      requiredCheckIn: "16",
      attendanceRate: "87.50 %",
      readCount: "31",
      unreadCount: "6",
      accessCount: "44",
      taskProgress: "6/8",
      homeworkProgress: "4/5",
      examProgress: "0/1",
      discussionCount: "3",
      materialCount: "9",
      courseId: "DEMO-ATT-2",
      clazzId: "DEMO-ATT-2-C",
      cpi: "0",
    ),
    ClassAttendance(
      courseName: "离散数学",
      className: "离散数学-01班",
      checkInCount: "11",
      personalLeave: "0",
      sickLeave: "0",
      officialLeave: "0",
      absenceCount: "5",
      requiredCheckIn: "16",
      attendanceRate: "68.75 %",
      readCount: "18",
      unreadCount: "11",
      accessCount: "29",
      taskProgress: "3/8",
      homeworkProgress: "2/5",
      examProgress: "0/1",
      discussionCount: "1",
      materialCount: "7",
      courseId: "DEMO-ATT-3",
      clazzId: "DEMO-ATT-3-C",
      cpi: "0",
    ),
    ClassAttendance(
      courseName: "概率论与数理统计",
      className: "概率论与数理统计-03班",
      checkInCount: "6",
      personalLeave: "0",
      sickLeave: "0",
      officialLeave: "0",
      absenceCount: "6",
      requiredCheckIn: "12",
      attendanceRate: "50.00 %",
      readCount: "9",
      unreadCount: "14",
      accessCount: "15",
      taskProgress: "1/6",
      homeworkProgress: "0/3",
      examProgress: "0/1",
      discussionCount: "0",
      materialCount: "5",
      courseId: "DEMO-ATT-4",
      clazzId: "DEMO-ATT-4-C",
      cpi: "0",
      isWarning: true,
    ),
  ];
}
