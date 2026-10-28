// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025-2026 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// 进度弹窗配色的回归测试。
//
// 背景：sn_progress_dialog 1.2.0 把弹窗配色写死成 Colors.white / black87 /
// transparent，登录时那句「登录后处理」因此是纯白底、和页面背景糊在一起。
// 这里守住 showThemed() 的映射，防止有人改回 pd.show()。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:watermeter/page/public_widget/app_progress_dialog.dart';

const _message = '登录后处理';

void main() {
  /// 打开一个使用 [theme] 的应用，点按钮弹出进度弹窗。
  ///
  /// 注意：进度环是无限动画，**不能用 pumpAndSettle**（永远不 settle）；
  /// 这里用两拍 pump 走完弹窗入场动画。
  Future<void> openDialog(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  ProgressDialog pd = ProgressDialog(context: context);
                  pd.showThemed(context, msg: _message);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  AlertDialog dialogOf(WidgetTester tester) =>
      tester.widget<AlertDialog>(find.byType(AlertDialog));

  testWidgets('背景色取主题的对话框背景（与应用其它 AlertDialog 一致）', (tester) async {
    const dialogColor = Color(0xFF123456);
    final theme = ThemeData(
      dialogTheme: const DialogThemeData(backgroundColor: dialogColor),
    );

    await openDialog(tester, theme);

    expect(find.text(_message), findsOneWidget);
    expect(dialogOf(tester).backgroundColor, dialogColor);
  });

  testWidgets('主题未指定对话框背景时回落到 surfaceContainerHigh', (tester) async {
    final theme = ThemeData();
    expect(theme.dialogTheme.backgroundColor, isNull);

    await openDialog(tester, theme);

    expect(
      dialogOf(tester).backgroundColor,
      theme.colorScheme.surfaceContainerHigh,
    );
  });

  testWidgets('文案、进度环、轨道、遮罩都改用主题色', (tester) async {
    final theme = ThemeData();
    final colorScheme = theme.colorScheme;

    await openDialog(tester, theme);

    final text = tester.widget<Text>(find.text(_message));
    expect(text.style?.color, colorScheme.onSurface);

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.valueColor?.value, colorScheme.primary);
    expect(indicator.backgroundColor, colorScheme.surfaceContainerHighest);

    // 包默认是 Colors.transparent，会让弹窗看起来贴在页面背景上。
    final route = ModalRoute.of(tester.element(find.byType(AlertDialog)));
    expect(route?.barrierColor, isNotNull);
    expect(route?.barrierColor, isNot(Colors.transparent));
  });
}
