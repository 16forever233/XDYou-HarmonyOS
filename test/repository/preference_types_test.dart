// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:watermeter/repository/preference.dart';

/// 偏好 key 的类型声明必须与 `preference.dart` 里的类型守卫一致。
///
/// 背景（真实踩过的坑）：`getBool/setBool` 的守卫是
/// `if (key.type != 'bool') throw WrongTypeException`，
/// 而 `getString` 要 `'String'`、`getInt` 要 `'int'`、`getDouble` 要 `'double'`。
/// 只要某个 key 的 `type` 少写或多写一个字母（例如写成 `"Bool"`），
/// 读取时就会抛异常 —— 如果这次读取发生在 `runApp` 之前（启动流程里），
/// 整个 App 会**直接停在启动页**（表现为"打不开/蓝屏"），排查成本极高。
void main() {
  test('所有偏好 key 的 type 都在受支持的取值里', () {
    const supported = {'String', 'bool', 'int', 'double'};
    for (final key in Preference.values) {
      expect(
        supported.contains(key.type),
        isTrue,
        reason:
            'Preference.${key.name} 的 type="${key.type}" 不被支持；'
            'bool 必须是小写 "bool"（守卫要求），否则读取时抛 WrongTypeException',
      );
    }
  });

  test('偏好 key 名不与枚举名冲突且非空', () {
    final seen = <String>{};
    for (final key in Preference.values) {
      expect(key.key, isNotEmpty, reason: 'Preference.${key.name} 的 key 不能为空');
      expect(
        seen.add(key.key),
        isTrue,
        reason: '偏好 key "${key.key}" 重复声明',
      );
    }
  });
}
