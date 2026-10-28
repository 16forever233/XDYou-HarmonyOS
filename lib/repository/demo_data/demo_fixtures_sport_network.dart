// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/model/network_usage.dart';
import 'package:watermeter/model/xidian_sport/sport_class.dart';
import 'package:watermeter/model/xidian_sport/sport_score.dart';

/// 演示用**体育信息**数据（全部虚构）。
///
/// 用途：审核体验账号登录后，「体育信息」两个页签（体测成绩 / 体育课）都要有数据。
///
/// ⚠️ 两个**必须遵守的格式约定**（不遵守会直接崩或显示成"未知"）：
///
/// 1. **`SportScore.detail` 必须含一个反斜杠 `\`**。
///    `sport_score_window.dart` 用
///    `data.detail.substring(0, data.detail.indexOf("\\"))` 取反斜杠**之前**的部分当说明文字；
///    没有反斜杠时 `indexOf` 返回 -1，`substring(0, -1)` 会抛 RangeError。
/// 2. `SportScore.scoreRankI18nStr` 在 `list.length < 4` 时恒返回
///    `class_attendance.course_state.unknown`（界面显示「未知」）—— 这是应用原有逻辑
///    （体测总评要四年齐了才有意义），不是数据缺失。演示学生按「大二」造，
///    所以这里的 list 只有两学年，界面显示「未知」属预期。
SportScore buildDemoSportScore() {
  final toReturn = SportScore();
  toReturn.total = "88.5";
  toReturn.rank = "良好";
  toReturn.detail = "达到毕业要求\\本学年体测各单项均已完成，数据均为虚构";
  toReturn.list = [
    _year(
      year: "2025-2026",
      totalScore: "86.5",
      rank: "良好",
      gradeType: "大一年级体测",
      items: const [
        ["50米跑", "秒", "7.3", 84.0, "良好"],
        ["立定跳远", "厘米", "228", 86.0, "良好"],
        ["引体向上", "个", "10", 74.0, "及格"],
        ["1000米跑", "分·秒", "4'12\"", 80.0, "良好"],
        ["坐位体前屈", "厘米", "11.2", 78.0, "及格"],
      ],
    ),
    _year(
      year: "2026-2027",
      totalScore: "88.5",
      rank: "良好",
      gradeType: "大二年级体测",
      items: const [
        ["50米跑", "秒", "7.2", 85.0, "良好"],
        ["立定跳远", "厘米", "235", 90.0, "优秀"],
        ["引体向上", "个", "12", 78.0, "及格"],
        ["1000米跑", "分·秒", "4'05\"", 82.0, "良好"],
        ["坐位体前屈", "厘米", "12.5", 80.0, "良好"],
      ],
    ),
  ];
  return toReturn;
}

SportScoreOfYear _year({
  required String year,
  required String totalScore,
  required String rank,
  required String gradeType,
  required List<List<Object>> items,
}) {
  final toReturn = SportScoreOfYear(
    year: year,
    totalScore: totalScore,
    rank: rank,
    gradeType: gradeType,
  );
  for (final item in items) {
    toReturn.details.add(
      SportItems(
        examName: item[0] as String,
        examunit: item[1] as String,
        actualScore: item[2] as String,
        score: item[3] as double,
        rank: item[4] as String,
      ),
    );
  }
  return toReturn;
}

/// 演示用**体育课**数据（全部虚构）。
///
/// 用 [SportClassItem.demo] 而不是 `fromData`：后者要按正则解析服务端字符串，
/// 演示数据没有那个来源（原因见该构造器的注释）。
SportClass buildDemoSportClass() => [
  SportClassItem.demo(
    termToShow: "2026-2027学年第一学期",
    term: "2026-2027-1",
    score: "92",
    type: "必修",
    name: "体育（篮球）",
    teacher: "赵鹏",
    week: 3,
    start: 3,
    stop: 4,
    place: "南校区体育馆",
  ),
  SportClassItem.demo(
    termToShow: "2026-2027学年第一学期",
    term: "2026-2027-1",
    score: "待评定",
    type: "必修",
    name: "体质健康标准测试",
    teacher: "周敏",
    week: 5,
    start: 7,
    stop: 8,
    place: "田径场",
  ),
  SportClassItem.demo(
    termToShow: "2025-2026学年第二学期",
    term: "2025-2026-2",
    score: "91",
    type: "必修",
    name: "体育（篮球）",
    teacher: "赵鹏",
    week: 3,
    start: 3,
    stop: 4,
    place: "南校区体育馆",
  ),
  SportClassItem.demo(
    termToShow: "2025-2026学年第一学期",
    term: "2025-2026-1",
    score: "89",
    type: "必修",
    name: "体育（篮球）",
    teacher: "赵鹏",
    week: 3,
    start: 3,
    stop: 4,
    place: "南校区体育馆",
  ),
];

/// 演示用**网络套餐用量**（虚构）。
///
/// 单位都是**字节**：页面用 `_formatBytes` 格式化，并按
/// `sumBytes / (sumBytes + remainBytes)` 画进度条。
/// 这里造「40G 用了 32G」（80%），进度条才有看头。
GeneralNetworkUsage buildDemoGeneralNetworkUsage() => const GeneralNetworkUsage(
  ipList: [
    ("10.198.12.34", "2026-09-14 08:30:12", "32.00 GB"),
    ("10.198.12.87", "2026-09-13 21:04:55", "1.20 GB"),
  ],
  used: "33.20 GB",
  rest: "6.80 GB",
  charged: "¥0.00",
);

/// 演示用**当前在线信息**（虚构）。
///
/// ⚠️ 一律使用演示身份（学号 `2026112345` / 姓名 `张明`）和**虚构的 IP/MAC**，
/// 绝不能填任何真实值 —— 这份数据会被审核员看到并截图。
CurrentUserNetInfo buildDemoCurrentUserNetInfo() => CurrentUserNetInfo(
  serverFlag: 1,
  addTime: 1789000000,
  allBytes: 42949672960, // 40 GB
  billingName: "校园网计费",
  bytesIn: 12345678901,
  bytesOut: 2345678901,
  checkoutDate: 1791000000,
  domain: "xidian.edu.cn",
  error: "",
  groupId: "1",
  keepaliveTime: 300,
  onlineDeviceDetail: "1 台设备在线",
  onlineDeviceTotal: "1",
  onlineIp: "10.198.12.34",
  onlineIp6: "",
  packageId: "1001",
  pppoeDial: "2026112345",
  productsId: "1",
  productsName: "校园网包月套餐（40G）",
  realName: "张明",
  remainBytes: 8589934592, // 8 GB
  remainSeconds: 1234567,
  sumBytes: 34359738368, // 32 GB
  sumSeconds: 2345678,
  sysver: "1.0.0",
  userBalance: 32,
  userCharge: 0,
  userMac: "AA:BB:CC:DD:EE:FF",
  userName: "2026112345",
  walletBalance: 32,
);
