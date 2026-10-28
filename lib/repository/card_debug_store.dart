// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:watermeter/model/xidian_ids/exam.dart';
import 'package:watermeter/repository/preference.dart' as preference;

/// 一条「模拟考试」日程（卡片调试用）。
///
/// 由「设置 → 调试 → 卡片考试调试」注入，`syncDesktopCard()` 会把它并进
/// 对应日期的卡片数据里，用来验证卡片的「考试」类型与座位号显示。
class CardDebugExam {
  /// yyyy-MM-dd
  final String isoDate;
  final String name;

  /// 考场
  final String place;

  /// 座位号
  final String seat;

  /// HH:mm
  final String startTime;

  /// HH:mm
  final String endTime;

  const CardDebugExam({
    required this.isoDate,
    required this.name,
    required this.place,
    required this.seat,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'isoDate': isoDate,
    'name': name,
    'place': place,
    'seat': seat,
    'startTime': startTime,
    'endTime': endTime,
  };

  static CardDebugExam? fromJson(Map<String, dynamic> json) {
    final isoDate = json['isoDate'];
    final name = json['name'];
    if (isoDate is! String || name is! String) {
      return null;
    }
    return CardDebugExam(
      isoDate: isoDate,
      name: name,
      place: json['place'] as String? ?? '',
      seat: json['seat'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }

  /// 转成应用内「考试安排」页使用的 [Subject]。
  ///
  /// `time` 用 `yyyy-MM-dd HH:mm-HH:mm` 格式，正好命中 [Subject.startTime] /
  /// [Subject.stopTime] 的正则，因此应用内考试页与桌面卡片都会把它当作真实考试处理
  /// （按时间排序、进「未结束/已结束」分组）。
  Subject toSubject() => Subject.generate(
    subject: name,
    typeStr: '期末考试',
    time: '$isoDate $startTime-$endTime',
    place: place,
    seat: seat,
  );
}

/// 调试用「模拟考试」的本地存储（Preferences，仅测试签名包使用）。
abstract final class CardDebugStore {
  /// 读取注入的模拟考试。
  ///
  /// **返回的列表一定可修改**：调用方 `add`/`remove` 会在它上面 `removeWhere`，
  /// 若这里返回 `const []`（const 列表不可修改）就会抛
  /// `Unsupported operation: Cannot remove from an unmodifiable list` ——
  /// 之前"注入不进去"就是这个原因：首次注入（prefs 还没写过、走 raw.isEmpty 分支）
  /// 直接抛异常，`save()` 从未执行，卡片自然永远不变。
  static List<CardDebugExam> load() {
    final raw = preference.getString(preference.Preference.cardDebugFakeExams);
    if (raw.isEmpty) {
      return <CardDebugExam>[];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CardDebugExam.fromJson)
          .whereType<CardDebugExam>()
          .toList();
    } catch (_) {
      return <CardDebugExam>[];
    }
  }

  static Future<void> save(List<CardDebugExam> exams) async {
    await preference.setString(
      preference.Preference.cardDebugFakeExams,
      jsonEncode(exams.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> add(CardDebugExam exam) async {
    // List.of：显式复制成可增长列表，不依赖 load() 返回值的可变性。
    final list = List<CardDebugExam>.of(load())
      ..removeWhere(
        (e) => e.isoDate == exam.isoDate && e.name == exam.name,
      )
      ..add(exam);
    await save(list);
  }

  static Future<void> remove(CardDebugExam exam) async {
    final list = List<CardDebugExam>.of(load())
      ..removeWhere(
        (e) =>
            e.isoDate == exam.isoDate &&
            e.name == exam.name &&
            e.startTime == exam.startTime,
      );
    await save(list);
  }

  static Future<void> clear() async {
    await preference.setString(
      preference.Preference.cardDebugFakeExams,
      '',
    );
  }
}
