// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:watermeter/bridge/app_info.dart';
import 'package:watermeter/page/public_widget/toast.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_data_service.dart';

/// 演示数据（截图模式）页 —— **仅测试签名包可见**（见 `bridge/app_info.dart`）。
///
/// 用途：拍应用市场宣传图时，让「首页 / 睿思 / 课表」全部显示虚构数据：
/// 不暴露任何真实个人信息、不发业务网络请求、没有加载中与报错。
///
/// 关闭后会走真实路径重新加载，真实数据与首页卡片布局原样恢复
/// （演示数据全程只在内存里，不写业务缓存、不动真实凭据）。
class DemoDataWindow extends StatefulWidget {
  const DemoDataWindow({super.key});

  @override
  State<DemoDataWindow> createState() => _DemoDataWindowState();
}

class _DemoDataWindowState extends State<DemoDataWindow> {
  bool _busy = false;
  bool get _enabled => DemoDataMode.enabled;

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showToast(context: context, msg: done);
    } catch (e) {
      if (mounted) showToast(context: context, msg: '操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable() => _run(() async {
    await DemoDataModeService.applyAll();
    await DemoDataMode.persist(true);
  }, '演示数据已开启');

  Future<void> _disable() => _run(() async {
    await DemoDataModeService.clearAll();
    await DemoDataMode.persist(false);
  }, '演示数据已关闭，正在恢复真实数据');

  Future<void> _refresh() => _run(() async {
    DemoDataModeService.refreshAll();
  }, '演示数据已按当前时间重新生成');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('演示数据（截图用）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '仅测试签名包可见。开启后「首页 / 睿思 / 课表」全部显示虚构数据，'
            '用于拍摄应用市场宣传图；期间不会请求任何业务接口，'
            '也不会写入任何缓存或账号信息（只在内存里生效）。',
            style: hintStyle,
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前状态：${_enabled ? "已开启" : "未开启"}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '演示身份：${DemoDataMode.studentName}（${DemoDataMode.studentId}）\n'
                    '原型包：${isDebugProvisioned ? "调试签名（可开启）" : "正式签名（已禁用）"}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || _enabled ? null : _enable,
            icon: const Icon(Icons.slideshow),
            label: const Text('开启演示数据'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy || !_enabled ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('按当前时间重新生成（跨天后用）'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || !_enabled ? null : _disable,
            icon: const Icon(Icons.restore),
            label: const Text('关闭并恢复真实数据'),
          ),
          const SizedBox(height: 24),
          Text('演示数据覆盖范围', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '· 课表：20 周学期、周一到周五 17 个课次、第 9 周\n'
            '· 首页：今日日程（课程 + 考试 + 实验 + 自定义课程）、电量卡、图书馆卡\n'
            '· 睿思：7 个页签的帖子列表、帖子详情（主楼 + 6 楼回复、可翻页）\n'
            '· 隐藏：检查更新卡、校园卡账单卡（那两项拿不到可信的虚构数据）\n'
            '· 不受影响：真实账号密码、真实缓存、自定义课程存储、桌面卡片以外的设置',
            style: hintStyle,
          ),
          const SizedBox(height: 12),
          Text(
            '提示：\n'
            '· 拍完图记得点「关闭并恢复真实数据」；\n'
            '· 关闭后睿思若仍显示刚才的帖子，切一下页签或重启应用即可（列表是页面内缓存）；\n'
            '· 正式签名包启动时会自动关闭本开关。',
            style: hintStyle,
          ),
        ],
      ),
    );
  }
}
