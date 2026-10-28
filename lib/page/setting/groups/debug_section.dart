// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:watermeter/page/setting/card_debug_window.dart';
import 'package:watermeter/page/setting/demo_data_window.dart';
import 'package:watermeter/page/setting/groups/section_setting_scaffold.dart';
import 'package:watermeter/repository/ruisi_forum.dart';

/// 调试分组（**仅调试签名包可见**，见 `bridge/app_info.dart`）。
class DebugSection extends StatelessWidget {
  const DebugSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionSettingScaffold(
      title: '调试（测试签名专用）',
      items: [
        // 睿思论坛开关。默认**一律隐藏**（发布包与调试包都一样），
        // 这里只是审批期间本机自测的临时入口 —— 所以放在调试分组里，
        // 正式签名包连这个分组都看不到。用 SignalBuilder 包住，
        // 开关一动首页底部页签立刻跟着增减。
        SignalBuilder(
          builder: (context) => SwitchListTile(
            title: const Text('睿思论坛入口'),
            subtitle: Text(
              RuisiForum.enabled
                  ? '已显示。仅本机生效 —— 监管审批通过前请勿在正式包里提供该功能。'
                  : '默认隐藏（睿思属校园 UGC 社区，监管审批通过前不对外提供）。'
                        '打开后首页会多出「睿思论坛」页签，仅供本机自测。',
            ),
            value: RuisiForum.enabled,
            onChanged: (value) => RuisiForum.setEnabled(value),
          ),
        ),
        ListTile(
          title: const Text('考试调试'),
          subtitle: const Text('注入模拟考试，验证应用内考试页与桌面卡片（类型/考场/座位号）'),
          trailing: const Icon(Icons.navigate_next),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CardDebugWindow()),
          ),
        ),
        ListTile(
          title: const Text('演示数据（截图用）'),
          subtitle: const Text('首页 / 睿思 / 课表显示虚构数据，用于拍上架宣传图'),
          trailing: const Icon(Icons.navigate_next),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const DemoDataWindow()),
          ),
        ),
      ],
    );
  }
}
