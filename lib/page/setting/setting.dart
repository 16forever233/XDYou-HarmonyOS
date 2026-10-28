// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// Setting window.

import 'package:watermeter/bridge/app_info.dart';
import 'package:watermeter/bridge/platform_capability.dart';

import 'package:flutter/material.dart';
import 'package:watermeter/page/setting/groups/about_section.dart';
import 'package:watermeter/page/setting/groups/account_section.dart';
import 'package:watermeter/page/setting/groups/classtable_section.dart';
import 'package:watermeter/page/setting/groups/core_section.dart';
import 'package:watermeter/page/setting/groups/debug_section.dart';
import 'package:watermeter/page/setting/groups/notification_section.dart';
import 'package:watermeter/page/setting/groups/ui_section.dart';

class SettingWindow extends StatefulWidget {
  const SettingWindow({super.key});
  @override
  State<SettingWindow> createState() => _SettingWindowState();
}

class _SettingWindowState extends State<SettingWindow> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const AboutSection(),
          const UiSection(),
          const AccountSection(),
          if (supportsSystemNotifications)
            const NotificationSection(),
          const ClasstableSection(),
          const CoreSection(),
          // 调试入口只在调试签名包里出现
          if (isDebugProvisioned) const DebugSection(),
        ],
      ),
    );
  }
}
