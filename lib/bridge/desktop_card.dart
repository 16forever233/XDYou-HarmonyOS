// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _desktopCardChannel = MethodChannel('xdyou/desktop_card');

/// 读回卡片当前保存的原始 JSON（调试/诊断用；无数据返回 null）。
Future<String?> readCardData() async {
  if (!Platform.isOhos) {
    return null;
  }
  try {
    return await _desktopCardChannel.invokeMethod<String>('getCardData');
  } catch (_) {
    return null;
  }
}

/// 让桌面卡片立即刷新。
///
/// 走原生 `formProvider.reloadAllForms`（主进程通知 FormExtension 进程批量刷新，
/// 异步、不重入），比等 60s 轮询或到点刷新快；API < 22 的设备调用会失败，返回 false。
Future<bool> refreshCardNow() async {
  if (!Platform.isOhos) {
    return false;
  }
  try {
    return await _desktopCardChannel.invokeMethod<bool>('refreshNow') ?? false;
  } catch (_) {
    return false;
  }
}

/// 桌面卡片中的一条日程。
class DesktopCardItem {
  final String type;
  final String name;
  final String teacher;
  final String place;

  /// 座位号（考试用，其它类型为空串）。
  final String seat;
  final String startTime;
  final String endTime;
  final int colorIndex;

  const DesktopCardItem({
    required this.type,
    required this.name,
    required this.teacher,
    required this.place,
    this.seat = '',
    required this.startTime,
    required this.endTime,
    required this.colorIndex,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'teacher': teacher,
    'place': place,
    'seat': seat,
    'startTime': startTime,
    'endTime': endTime,
    'colorIndex': colorIndex,
  };
}

/// 某一天的日程（卡片按设备日期从多天窗口里取用）。
class DesktopCardDayData {
  /// 展示用日期（9月8日 周一）。
  final String date;

  /// 第 N 周 / 假期中（无课表数据时为空）。
  final String week;

  /// 当天全部日程（**不做时间过滤**，由卡片按设备时间过滤已结束的条目）。
  final List<DesktopCardItem> items;

  const DesktopCardDayData({
    required this.date,
    required this.week,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'week': week,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

/// 把桌面卡片需要展示的数据写入鸿蒙 Preferences。
///
/// 写入**多天窗口**（`days`，key 为 `yyyy-MM-dd`，含今天起若干天），
/// 卡片端按设备日期取“今天/明天”并按当前时间过滤已结束条目，
/// 因此跨天、下课等变化都不需要用户打开 App。
///
/// 同时写一份旧的 `today`/`tomorrow` 兼容字段（旧版卡片仍可读）。
///
/// 非 OHOS 平台直接返回 false，不影响其他端。
Future<bool> saveDesktopCardData({
  required bool isLoggedIn,
  required bool isTomorrow,
  required Map<String, DesktopCardDayData> days,
  String errorType = '',
  String error = '',
  /// 演示数据（截图模式）：卡片端据此**跳过"已结束"过滤**，
  /// 否则晚上拍宣传图时卡片会显示「今日课程已结束」。
  bool isDemo = false,
}) async {
  if (!Platform.isOhos) {
    return false;
  }
  try {
    // 同步前读回卡片当前 isTomorrow，避免覆盖用户刚在卡片上做的今日/明日切换。
    var effectiveIsTomorrow = isTomorrow;
    try {
      final current = await _desktopCardChannel
          .invokeMethod<String>('getCardData');
      if (current != null && current.isNotEmpty) {
        final obj = jsonDecode(current) as Map<String, dynamic>;
        effectiveIsTomorrow = obj['isTomorrow'] as bool? ?? false;
      }
    } catch (_) {
      // 首次同步（无历史数据）时忽略，使用传入值。
    }
    final sortedDates = days.keys.toList()..sort();
    final anchorDate = sortedDates.isEmpty ? '' : sortedDates.first;
    final data = jsonEncode({
      'isLoggedIn': isLoggedIn,
      'isTomorrow': effectiveIsTomorrow,
      'anchorDate': anchorDate,
      'windowDays': sortedDates.length,
      'days': {
        for (final entry in days.entries) entry.key: entry.value.toJson(),
      },
      // 兼容字段：旧版卡片（只认 today/tomorrow）仍可显示。
      'today': _legacyDay(days, anchorDate, '今日课表'),
      'tomorrow': _legacyDay(days, _plusOneDay(anchorDate), '明日课表'),
      'errorType': errorType,
      'error': error,
      // 演示数据（截图模式）：卡片端据此跳过"已结束"过滤
      'isDemo': isDemo,
      // 卡片端轮询用：内容变化时该值变化，卡片才推送刷新。
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _desktopCardChannel.invokeMethod<void>('saveCardData', data);
    return true;
  } catch (e) {
    return false;
  }
}

String _plusOneDay(String isoDate) {
  if (isoDate.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) {
    return '';
  }
  final next = parsed.add(const Duration(days: 1));
  return '${next.year.toString().padLeft(4, '0')}-'
      '${next.month.toString().padLeft(2, '0')}-'
      '${next.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _legacyDay(
  Map<String, DesktopCardDayData> days,
  String isoDate,
  String title,
) {
  final day = days[isoDate];
  return {
    'title': title,
    'date': day?.date ?? '',
    'isoDate': isoDate,
    'week': day?.week ?? '',
    'items': day?.items.map((e) => e.toJson()).toList() ?? <dynamic>[],
  };
}
