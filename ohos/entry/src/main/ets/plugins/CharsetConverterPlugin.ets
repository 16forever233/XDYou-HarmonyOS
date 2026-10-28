/*
 * Copyright 2026 XDYou HarmonyOS port authors.
 * SPDX-License-Identifier: MPL-2.0
 */

import { FlutterEngine, MethodChannel, MethodCall, MethodResult, StandardMethodCodec, StandardMessageCodec } from '@ohos/flutter_ohos';
import { util } from '@kit.ArkTS';

/**
 * 给第三方插件 `charset_converter` 补上鸿蒙实现。
 *
 * ## 为什么需要这个文件
 *
 * 物理实验系统（wlsy.xidian.edu.cn）是老的 ASP.NET 站点，页面用 **GB18030** 编码，
 * 而 Dart 没有内置 GBK/GB18030 解码器，所以上游用了 `charset_converter` 插件：
 * `physics_experiment_session.dart` 给 Dio 挂了一个自定义 `responseDecoder`，
 * 每个响应都先 `CharsetConverter.availableCharsets()` 再 `decode(...)`。
 * （`experiment_report_session.dart` 用法相同，即「实验报告」也依赖它。）
 *
 * 但该插件的 pubspec 只声明了 `android / ios / windows / linux` —— **没有 ohos**，
 * 因此 Flutter-OH 的 `GeneratedPluginRegistrant` 不会注册它，通道无人应答：
 *
 * ```
 * MissingPluginException(No implementation found for method availableCharsets
 *                        on channel charset_converter)
 * ```
 *
 * 后果是物理实验与实验报告**永远加载失败**（真机日志实测，
 * 异常发生在 POST 的响应解码阶段，所以堆栈落在那次 POST 上）。
 *
 * ## 为什么不 fork 插件
 *
 * 插件的 Dart 侧用的就是 `MethodChannel('charset_converter')`，通道名与参数格式都是
 * 公开契约。在应用侧补上同名通道即可，**Dart 一行都不用改**，也不用维护一份 fork。
 * （同类先例：本仓库的 file_picker_ohos / talker_flutter 等 vendor 补丁。）
 *
 * ## 为什么鸿蒙这边做得到
 *
 * `@ohos.util` 的 `TextDecoder` 原生支持这些编码（见 `@ohos.util.d.ts` 中
 * `TextDecoder.encoding` 的说明）：utf-8、**gbk**、**gb18030**、big5、euc-jp 等。
 *
 * ## 对齐的插件契约（读自 charset_converter.dart）
 *
 * | 方法 | 参数 | 返回 | 本项目是否使用 |
 * | --- | --- | --- | --- |
 * | `availableCharsets` | — | `List<String>` | ✅ 会找列表里含 "18030" 的项 |
 * | `decode` | `{charset, data}` | `String` | ✅ |
 * | `encode` | `{charset, data}` | `Uint8List` | ❌ 未使用 |
 * | `check` | `{charset}` | `bool` | ❌ 未使用 |
 *
 * 未使用的两个**故意返回 notImplemented**（而不是静默给个错值），
 * 将来真有人调用会立刻暴露，而不是拿到一段乱码。
 *
 * 类型对接（读自引擎 `StandardMessageCodec.ets`）：
 * Dart `Map` → ArkTS `Map`（用 `call.argument(key)` 取）；
 * Dart `Uint8List` → ArkTS `Uint8Array`（`UINT8_ARRAY` 分支走 `readBytes`）。
 */

const CHANNEL_NAME: string = 'charset_converter';

/**
 * `availableCharsets()` 的返回值。
 *
 * 调用方是
 * `CharsetConverter.availableCharsets().then((v) => v.firstWhere((e) => e.contains("18030")))`，
 * 所以**列表里必须有一项含 "18030"**，`gb18030` 不能少。
 * 其余项与 TextDecoder 的实际能力对齐，便于将来别的编码场景直接复用。
 */
const SUPPORTED_CHARSETS: string[] = [
  'utf-8',
  'utf-16le',
  'utf-16be',
  'gbk',
  'gb18030',
  'big5',
  'iso-8859-1',
  'iso-8859-2',
  'iso-8859-3',
  'iso-8859-4',
  'iso-8859-5',
  'iso-8859-6',
  'iso-8859-7',
  'iso-8859-8',
  'iso-8859-8-i',
  'iso-8859-10',
  'iso-8859-13',
  'iso-8859-14',
  'iso-8859-15',
  'iso-8859-16',
  'koi8-r',
  'koi8-u',
  'macintosh',
  'windows-874',
  'windows-1250',
  'windows-1251',
  'windows-1252',
  'windows-1253',
  'windows-1254',
  'windows-1255',
  'windows-1256',
  'windows-1257',
  'windows-1258',
  'x-mac-cyrillic',
  'euc-jp',
  'iso-2022-jp',
  'shift_jis',
  'euc-kr'
];

/**
 * 把 Dart 侧传来的字节统一成 `Uint8Array`。
 *
 * 正常路径下 `Uint8List` 解出来就是 `Uint8Array`；这里额外兼容
 * `ArrayBuffer` 与普通数组，是因为标准编解码器在个别路径下会有差异 ——
 * 多写几行，避免将来某次引擎升级后这里莫名开始报错。
 */
function toUint8Array(value: ESObject): Uint8Array | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (value instanceof Uint8Array) {
    return value as Uint8Array;
  }
  if (value instanceof ArrayBuffer) {
    return new Uint8Array(value as ArrayBuffer);
  }
  if (Array.isArray(value)) {
    return Uint8Array.from(value as number[]);
  }
  return null;
}

export function registerCharsetConverterChannel(flutterEngine: FlutterEngine): void {
  const channel = new MethodChannel(
    flutterEngine.getDartExecutor().getBinaryMessenger(),
    CHANNEL_NAME,
    new StandardMethodCodec(new StandardMessageCodec()),
  )
  channel.setMethodCallHandler({
    onMethodCall: (call: MethodCall, result: MethodResult) => {
      if (call.method === 'availableCharsets') {
        result.success(SUPPORTED_CHARSETS);
        return;
      }

      if (call.method === 'decode') {
        // 用 typeof 判定而不是和 null 比较：Dart 侧若漏传，取到的是 undefined，
        // 而 `as string` 在 ArkTS 里不会替我们做运行期校验。
        const charsetValue: ESObject = call.argument('charset');
        const dataValue: ESObject = call.argument('data');
        if (typeof charsetValue !== 'string' || (charsetValue as string).length === 0) {
          console.error('[CharsetConverter] decode 缺少 charset 参数');
          result.error('bad_args', 'decode requires {charset: string, data: Uint8Array}', null);
          return;
        }
        const bytes: Uint8Array | null = toUint8Array(dataValue);
        if (bytes === null) {
          console.error('[CharsetConverter] decode 缺少 data 参数');
          result.error('bad_args', 'decode requires {charset: string, data: Uint8Array}', null);
          return;
        }
        const charset: string = charsetValue as string;
        try {
          // TextDecoder.create 对不支持的编码会抛 BusinessError(401)。
          const decoder = util.TextDecoder.create(charset);
          const text = decoder.decodeToString(bytes);
          result.success(text);
        } catch (err) {
          console.error('[CharsetConverter] decode 失败: charset=' + charset +
            ', err=' + JSON.stringify(err));
          result.error('decode_failed', 'charset=' + charset + ': ' + JSON.stringify(err), null);
        }
        return;
      }

      // encode / check 本项目未使用，明确报 notImplemented，别静默给错值。
      result.notImplemented();
    }
  })
}
