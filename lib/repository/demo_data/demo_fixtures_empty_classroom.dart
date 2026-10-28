// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/model/xidian_ids/empty_classroom.dart';

/// 演示用**空闲教室**数据（虚构教学楼名与占用情况）。
///
/// ## 为什么这里也必须造假数据
///
/// 空闲教室本身是**公共信息**（哪个教室哪节课空着），不含个人隐私 —— 从道理上讲，
/// 审核体验账号最该走这条路拿真数据。但它**技术上做不到**：
///
/// - 它的数据源是 `ehall.xidian.edu.cn/jwapp/sys/kxjas/...`，**必须带统一身份认证的
///   会话**才能访问。实测（2026-09-14，不带任何 Cookie 直接 POST `jxlcx.do`）：
///   服务端返回 **302，Location 指向
///   `https://ids.xidian.edu.cn/authserver/login?service=...`** —— 也就是被踢回登录页。
/// - 审核账号是**应用内置的本地账号**，本来就没有（也不该有）西电账号，
///   所以拿不到这个会话。
///
/// 结论：审核态下"连真数据"不可能，只有两条路 —— 给它假数据（当前做法），
/// 或者让审核员看到错误页。**如果哪天愿意给审核员一个真实测试账号，
/// 把 `EmptyClassroomSession` 里那两处 `DemoDataMode.enabled` 短路删掉即可恢复真实数据。**
///
/// 教学楼代码/名称与教室号都是虚构的（真实的西电南校区教学楼为 A~G 栋，
/// 这里沿用这个形制，看起来自然）。

/// 教学楼列表（对应真实接口的 `jxlcx.do`）。
///
/// 注意：`EmptyClassroomPlace` 的构造器不是 `const`，所以这里不能写成 `const [...]`。
List<EmptyClassroomPlace> buildDemoEmptyClassroomPlaces() => [
  EmptyClassroomPlace(name: "A楼", code: "A"),
  EmptyClassroomPlace(name: "B楼", code: "B"),
  EmptyClassroomPlace(name: "C楼", code: "C"),
  EmptyClassroomPlace(name: "D楼", code: "D"),
  EmptyClassroomPlace(name: "E楼", code: "E"),
  EmptyClassroomPlace(name: "F楼", code: "F"),
  EmptyClassroomPlace(name: "G楼", code: "G"),
];

/// 一天 11 个大节 —— 必须与 [EmptyClassroomData] 的 `assert(isUsed.length == 11)` 一致。
const int _periodCount = 11;

/// 某个教学楼里各教室的占用情况（对应真实接口的 `cxjsqk.do`）。
///
/// 占用是**确定性伪随机**算出来的（不是 `Random()`）：同一教学楼每次点都得到同样的
/// 结果，审核员来回切页面不会觉得数据在乱跳。
///
/// 注意真实接口是要传日期/学期/周次查的，这里**忽略这些参数**、恒返回一份课表占用 ——
/// 演示数据的目的是"页面有内容"，不是"这一天的真实排课"。
List<EmptyClassroomData> buildDemoEmptyClassroomData({
  required String buildingCode,
}) {
  // 每栋楼 5 层 × 每层 3 间，房间号形如 A-301。
  const List<int> floors = [2, 3, 4, 5, 6];
  const List<int> roomsPerFloor = [1, 2, 3];

  // 用它给不同教学楼一个不同的偏移，免得七栋楼长得一模一样。
  final int buildingSeed = buildingCode.isEmpty
      ? 0
      : buildingCode.codeUnitAt(0) % 7;

  final List<EmptyClassroomData> toReturn = [];
  var roomIndex = 0;
  for (final floor in floors) {
    for (final room in roomsPerFloor) {
      final String name = "$buildingCode-${floor}0$room";
      final List<bool> isUsed = List<bool>.generate(_periodCount, (int p) {
        // 落在 0..4 的循环里：<2 表示这节课被占用（约 40%）。
        // 再叠上"楼层越高越空"的倾向，让结果有层次。
        final int slot = (roomIndex * 3 + p + buildingSeed) % 5;
        final bool occupied = slot < 2;
        final bool upperFloorBonus = floor >= 5 && p >= 8;
        return occupied && !upperFloorBonus;
      }, growable: false);

      toReturn.add(EmptyClassroomData(name: name, isUsed: isUsed));
      roomIndex++;
    }
  }
  return toReturn;
}
