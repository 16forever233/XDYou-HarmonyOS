// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:watermeter/repository/demo_data/review_account.dart';

/// 审核体验账号的回归测试。
///
/// 为什么要钉死这组凭据：它是**要写进 AGC 审核说明、交给应用市场审核员**的，
/// 一旦有人顺手改了 `ReviewAccount.account` / `password` 而没同步改提交材料，
/// 审核员就会登不进去 —— 而那种失败在开发机上完全看不出来（本地一直用调试包）。
/// 所以这里把值和匹配行为都固定下来：改凭据就必须同时改这个测试，
/// 逼着改动者去同步文档与 AGC 说明。
void main() {
  group('ReviewAccount.matches', () {
    test('这组凭据本身能通过（同时钉住要告知 AGC 的字面值）', () {
      expect(ReviewAccount.account, '2026112345');
      expect(ReviewAccount.password, 'xdyou2026');
      expect(ReviewAccount.matches(ReviewAccount.account, ReviewAccount.password), isTrue);
    });

    test('学号两端空白做宽松处理（手机输入法容易多打空格）', () {
      expect(ReviewAccount.matches('  2026112345  ', 'xdyou2026'), isTrue);
    });

    test('密码不做 trim：多一个空格就不算匹配', () {
      expect(ReviewAccount.matches('2026112345', ' xdyou2026'), isFalse);
      expect(ReviewAccount.matches('2026112345', 'xdyou2026 '), isFalse);
    });

    test('密码错误不匹配', () {
      expect(ReviewAccount.matches('2026112345', 'wrong-password'), isFalse);
      expect(ReviewAccount.matches('2026112345', ''), isFalse);
    });

    test('学号错误不匹配（含常见混淆写法）', () {
      expect(ReviewAccount.matches('2026112346', 'xdyou2026'), isFalse);
      expect(ReviewAccount.matches('202611234', 'xdyou2026'), isFalse);
      expect(ReviewAccount.matches('', 'xdyou2026'), isFalse);
    });

    test('大小写敏感：密码不区分大小写地"近似"也不放行', () {
      expect(ReviewAccount.matches('2026112345', 'XDYOU2026'), isFalse);
      expect(ReviewAccount.matches('2026112345', 'XdYou2026'), isFalse);
    });

    test('默认未启用（启动解析前不得处于体验模式）', () {
      expect(ReviewAccount.active, isFalse);
    });
  });
}
