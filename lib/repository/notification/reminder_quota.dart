// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:watermeter/bridge/app_info.dart';
import 'package:watermeter/repository/logger.dart';

/// 鸿蒙「代理提醒」（reminderAgentManager）的调度配额。
///
/// 系统对每个应用能同时存在的提醒条数有硬上限，超了会返回错误码 **1700002**
/// （`exceeds the limit`）：
/// - **API 26+（HarmonyOS 7）：64 条**
/// - **API ≤ 25：30 条**
///
/// **只有鸿蒙有这个硬上限**（[enforced]）：Android/iOS 沿用上游"不截断"的行为，
/// 避免为了鸿蒙的系统限制给三端造成行为差异 —— 上限只在本模块内生效。
///
/// 这里只负责"上限"和"留多少余量"；**实际还能排多少条**由 [remaining]
/// 用系统里真实存在的提醒数算出来 —— 因为配额是和用户手动添加的自定义提醒、
/// "立即显示"测试共用的，只按上限截断仍可能撞 1700002。
abstract final class ReminderQuota {
  /// 设备 API 26 起的配额（HarmonyOS 7）。
  static const int _quotaApi26 = 64;

  /// 设备 API ≤ 25 的配额。
  static const int _quotaLegacy = 30;

  /// 预留给「用户手动添加的自定义提醒」和「快速测试」的条数：
  /// 课程/实验/考试提醒是自动批量调度的，不该把配额吃满。
  static const int _reserve = 8;

  /// "不限制"的返回值（非鸿蒙平台）。
  static const int unlimited = 1 << 30;

  /// 本平台是否受提醒条数限制（仅鸿蒙）。
  static bool get enforced => Platform.isOhos;

  /// 本机 reminderAgentManager 的提醒总上限（0 = 本平台无此限制）。
  ///
  /// 设备 API 读不到（[deviceSdkApiVersion] == 0，例如读取失败）时按保守值
  /// [_quotaLegacy] 处理。
  static int get total {
    if (!enforced) {
      return 0;
    }
    return deviceSdkApiVersion >= 26 ? _quotaApi26 : _quotaLegacy;
  }

  /// 自动调度可用的上限（总上限扣掉预留）。
  static int get capacity {
    if (!enforced) {
      return unlimited;
    }
    final value = total - _reserve;
    return value > 0 ? value : total;
  }

  /// 拿到"系统里当前已有 [pending] 条提醒"后，本次还能调度多少条（至少 0）。
  static int remaining(int pending) {
    if (!enforced) {
      return unlimited;
    }
    final value = capacity - (pending < 0 ? 0 : pending);
    return value > 0 ? value : 0;
  }

  /// 一行诊断信息（hilog/Talker 里看："设备 API 26 → 配额 64，已用 12，可再排 44"）。
  static String describe(int pending) =>
      '设备 API ${deviceSdkApiVersion == 0 ? "未知" : deviceSdkApiVersion} → '
      '提醒配额 $total（预留 $_reserve），系统内已有 $pending 条，'
      '本次可再排 ${remaining(pending)} 条';

  /// 设置页展示用的短摘要；非鸿蒙平台返回空串（不显示）。
  static String summary(int pending) => enforced
      ? '设备 API ${deviceSdkApiVersion == 0 ? "未知" : deviceSdkApiVersion}'
            ' · 提醒配额 $total'
            ' · 已用 $pending'
            ' · 自动调度上限 $capacity'
      : '';

  /// 把本次的调度预算写进日志，方便真机排查 1700002（非鸿蒙平台不打印）。
  static void logBudget(int pending) {
    if (enforced) {
      log.info('[ReminderQuota] ${describe(pending)}');
    }
  }
}
