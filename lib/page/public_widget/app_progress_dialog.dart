// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025-2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 应用内统一的进度弹窗配色。

import 'package:flutter/material.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';

/// 让进度弹窗的配色跟随应用主题。
///
/// 为什么不直接用 `pd.show()`：sn_progress_dialog 1.2.0 把颜色写死了 ——
/// `backgroundColor: Colors.white`、`msgColor`/`valueColor`: `Colors.black87`、
/// `barrierColor: Colors.transparent`。于是弹窗在浅色页面上和背景一样白
/// （登录时那句「登录后处理」就是这么来的），深色主题下又变成白底黑字；
/// 而应用里其它 `AlertDialog` 用的是主题里的 `dialogBackgroundSchemeColor`
/// （本项目在 main.dart 的 FlexSubThemesData 里设为 `SchemeColor.secondaryContainer`）。
///
/// 这里按 Material 3 的角色重新映射一遍，调用方**仍然持有同一个
/// [ProgressDialog] 实例**，所以 `update` / `isOpen` / `close` 的用法完全不变。
extension AppProgressDialogTheme on ProgressDialog {
  Future<void> showThemed(
    BuildContext context, {
    required String msg,
    Completed? completed,
    int max = 100,
    bool hideValue = true,
    ProgressType progressType = ProgressType.indeterminate,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return show(
      msg: msg,
      completed: completed,
      max: max,
      hideValue: hideValue,
      progressType: progressType,
      // 与其它 AlertDialog 取同一个背景色（本项目解析为 secondaryContainer）。
      backgroundColor:
          theme.dialogTheme.backgroundColor ?? colorScheme.surfaceContainerHigh,
      // 其它对话框走 showDialog 的默认遮罩（black54），这里同样补上，
      // 否则纯透明遮罩会让弹窗看起来"贴"在页面背景上。
      barrierColor: colorScheme.scrim.withValues(alpha: 0.54),
      msgColor: colorScheme.onSurface,
      valueColor: colorScheme.onSurfaceVariant,
      progressValueColor: colorScheme.primary,
      progressBgColor: colorScheme.surfaceContainerHighest,
    );
  }
}
