// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:watermeter/bridge/desktop_card.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/page/public_widget/toast.dart';
import 'package:watermeter/repository/card_debug_store.dart';
import 'package:watermeter/repository/desktop_card_sync_service.dart';

/// 考试调试页（**仅调试签名包可见**，见 `bridge/app_info.dart`）。
///
/// 用途：在没有真实考试安排时，注入「模拟考试」日程，一次验证两处界面：
/// ① 应用内「考试安排」页（`ExamController`）；
/// ② 桌面卡片（考试类型 + 考场 + 座位号）。
/// 注入数据只存在于本机的调试存储里，真实课表/考试成绩数据不受影响。
class CardDebugWindow extends StatefulWidget {
  const CardDebugWindow({super.key});

  @override
  State<CardDebugWindow> createState() => _CardDebugWindowState();
}

class _CardDebugWindowState extends State<CardDebugWindow> {
  List<CardDebugExam> _exams = CardDebugStore.load();
  bool _busy = false;
  String _status = '读取中…';

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStatus());
  }

  /// 读回真实数据，展示"到底写进去了没有、卡片到底会显示什么"。
  Future<void> _refreshStatus() async {
    final raw = await readCardData();
    if (!mounted) return;
    setState(() => _status = _describeStatus(raw));
  }

  String _describeStatus(String? raw) {
    final buffer = StringBuffer();

    // ① 注入的模拟数据本身。
    final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final tomorrowIso = DateFormat('yyyy-MM-dd').format(
      DateTime.now().add(const Duration(days: 1)),
    );
    final todayFake = _exams.where((e) => e.isoDate == todayIso).length;
    final tomorrowFake = _exams.where((e) => e.isoDate == tomorrowIso).length;
    buffer.writeln('注入的模拟考试：今日 $todayFake 条、明日 $tomorrowFake 条');

    // ② 应用内「考试安排」页会渲染的内容（含真实考试 + 模拟考试）。
    final exams = ExamController.i;
    final visible = exams.isNotFinished.value.length;
    final finished = exams.isFinished.value.length;
    buffer.writeln(
      '应用内考试页：进行中 $visible 条、已结束 $finished 条'
      '（数据源共 ${exams.subjects.value.length} 条）',
    );

    // ③ 桌面卡片数据 + 卡片实际会渲染的行。
    buffer.write(_describeCardData(raw, todayIso, tomorrowIso));
    return buffer.toString();
  }

  String _describeCardData(
    String? raw,
    String todayIso,
    String tomorrowIso,
  ) {
    if (raw == null || raw.isEmpty) {
      return '\n卡片数据：为空（App 还没写入过，打开一次首页即可）';
    }
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      final days = (obj['days'] as Map<String, dynamic>?) ?? const {};
      final isTomorrow = obj['isTomorrow'] as bool? ?? false;
      final isLoggedIn = obj['isLoggedIn'] as bool? ?? false;
      final errorType = obj['errorType'] as String? ?? '';
      final updatedAt = obj['updatedAt'] as String? ?? '?';

      String dayInfo(String iso) {
        final day = days[iso] as Map<String, dynamic>?;
        final items = (day?['items'] as List<dynamic>?) ?? const [];
        final fake = items
            .whereType<Map<String, dynamic>>()
            .where((e) => '${e['name']}'.contains('【测试】'))
            .length;
        return '$iso：${items.length} 条（模拟 $fake 条）';
      }

      /// 卡片端 ArkTS 的渲染规则：取目标日 → 状态位优先 → 今日按 endTime 过滤。
      String preview() {
        final targetIso = isTomorrow ? tomorrowIso : todayIso;
        if (!days.containsKey(targetIso)) {
          return '打开应用刷新（窗口里没有 $targetIso）';
        }
        if (!isLoggedIn) {
          return '未登录（卡片只显示「未登录」）';
        }
        if (errorType.isNotEmpty) {
          return '错误态：$errorType（会盖住日程）';
        }
        final day = days[targetIso] as Map<String, dynamic>?;
        final all = ((day?['items'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final nowHm = DateFormat('HH:mm').format(DateTime.now());
        final shown = isTomorrow
            ? all
            : all.where((e) => '${e['endTime']}'.compareTo(nowHm) > 0).toList();
        if (all.isEmpty) {
          return '暂无课程';
        }
        if (shown.isEmpty) {
          return '今日课程已结束（${all.length} 条都已结束）';
        }
        final lines = shown.take(4).map((e) {
          final seat = '${e['seat'] ?? ''}';
          return '    ${e['startTime']}-${e['endTime']} '
              '${e['name']} · ${e['place']}'
              '${seat.isEmpty ? '' : ' · 座位$seat'}';
        }).join('\n');
        final more = shown.length > 4 ? '\n    …共 ${shown.length} 条' : '';
        return '${shown.length} 条\n$lines$more';
      }

      return '\n卡片数据：写入 $updatedAt，卡片当前显示'
          '${isTomorrow ? "明日" : "今日"}\n'
          '  ${dayInfo(todayIso)}\n'
          '  ${dayInfo(tomorrowIso)}\n'
          '卡片当前会显示：${preview()}';
    } catch (e) {
      return '\n解析卡片数据失败：$e';
    }
  }

  Future<void> _apply(Future<void> Function() mutate, String toast) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await mutate();
      // 让应用内「考试安排」页立刻按新数据重算。
      ExamController.i.refreshDebugSubjects();
      // 写桌面卡片数据（写完后原生侧会 reloadAllForms 让卡片立即刷新）。
      await syncDesktopCard();
      if (mounted) {
        showToast(context: context, msg: toast);
      }
    } catch (e) {
      if (mounted) {
        showToast(context: context, msg: '操作失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _exams = CardDebugStore.load();
          _busy = false;
        });
        await _refreshStatus();
      }
    }
  }

  /// 今日模拟考试：起点 = 现在 +10 分钟（对齐 5 分钟），时长 60 分钟。
  /// 23 点后今日注入会马上过期（卡片按「未结束」过滤），自动改用明日 08:00。
  CardDebugExam _todayExam() {
    final now = DateTime.now();
    var start = now.add(const Duration(minutes: 10));
    start = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      (start.minute ~/ 5) * 5,
    );
    final end = start.add(const Duration(minutes: 60));
    final day = DateTime(now.year, now.month, now.day);

    if (start.hour >= 23 || end.day != start.day) {
      final tomorrow = day.add(const Duration(days: 1));
      return CardDebugExam(
        isoDate: DateFormat('yyyy-MM-dd').format(tomorrow),
        name: '【测试】模拟考试',
        place: 'A101',
        seat: '42',
        startTime: '08:00',
        endTime: '09:35',
      );
    }
    return CardDebugExam(
      isoDate: DateFormat('yyyy-MM-dd').format(day),
      name: '【测试】模拟考试',
      place: 'A101',
      seat: '42',
      startTime: DateFormat('HH:mm').format(start),
      endTime: DateFormat('HH:mm').format(end),
    );
  }

  CardDebugExam _tomorrowExam() => CardDebugExam(
    isoDate: DateFormat('yyyy-MM-dd').format(
      DateTime.now().add(const Duration(days: 1)),
    ),
    name: '【测试】模拟考试',
    place: 'B203',
    seat: '7',
    startTime: '08:00',
    endTime: '09:35',
  );

  /// 今日 + 明日各注入一条：不管卡片当前显示哪一天，都能看到效果。
  Future<void> _injectBoth() async {
    final today = _todayExam();
    final tomorrow = _tomorrowExam();
    await _apply(() async {
      await CardDebugStore.add(today);
      await CardDebugStore.add(tomorrow);
    }, '已注入模拟考试：${today.isoDate} ${today.startTime}-${today.endTime}、'
        '${tomorrow.isoDate} 08:00-09:35');
  }

  Future<void> _clearAll() async {
    await _apply(() => CardDebugStore.clear(), '已清除全部模拟数据');
  }

  Future<void> _removeOne(CardDebugExam exam) async {
    await _apply(() => CardDebugStore.remove(exam), '已删除该条模拟数据');
  }

  Future<void> _refreshCard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await refreshCardNow();
      if (mounted) {
        showToast(
          context: context,
          msg: ok ? '已请求卡片立即刷新' : '请求失败（设备 API < 22 时不支持）',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refreshStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('考试调试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '仅调试签名包可见。注入的模拟考试会同时出现在'
            '应用内「考试安排」页和桌面卡片上，不影响真实数据。',
            style: hintStyle,
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_status, style: theme.textTheme.bodySmall),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _injectBoth,
            icon: const Icon(Icons.add_task),
            label: const Text('注入模拟考试（今日 + 明日）'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _refreshCard,
            icon: const Icon(Icons.refresh),
            label: const Text('立即刷新卡片'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || _exams.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清除全部模拟数据'),
          ),
          const SizedBox(height: 24),
          Text('当前模拟数据（${_exams.length} 条）', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_exams.isEmpty)
            Text('暂无', style: hintStyle)
          else
            ..._exams.map(
              (exam) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${exam.isoDate} ${exam.startTime}-${exam.endTime}'),
                subtitle: Text(
                  '${exam.name} · 考场 ${exam.place} · 座位 ${exam.seat}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _busy ? null : () => _removeOne(exam),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
