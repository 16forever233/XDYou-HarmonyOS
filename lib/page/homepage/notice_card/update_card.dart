// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:signals/signals_flutter.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/bridge/app_update.dart';
import 'package:watermeter/controller/update_notice_controller.dart';
import 'package:watermeter/page/homepage/home_card_padding.dart';
import 'package:watermeter/page/setting/dialogs/update_dialog.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    // 演示数据不显示"检查更新"卡片
    // 调试签名包上华为应用市场的检查结果是错误码
    if (DemoDataMode.enabled) {
      return const SizedBox(height: 0);
    }
    if (Platform.isOhos) {
      return SignalBuilder(
        builder: (context) {
          final controller = UpdateNoticeController.i;
          if (!controller.appUpdateCheckedSignal.value) {
            return Text(
                  FlutterI18n.translate(context, "setting.fetching_update"),
                )
                .paddingDirectional(horizontal: 16, vertical: 14)
                .withHomeCardStyle(context);
          }
          if (!controller.hasAppUpdateComputed.value) {
            return const SizedBox(height: 0);
          }
          return Text(
                FlutterI18n.translate(context, "setting.new_version"),
                style: TextStyle(fontWeight: FontWeight.bold),
              )
              .paddingDirectional(horizontal: 16, vertical: 14)
              .withHomeCardStyle(
                context,
                onPressed: () => showAppUpdateDialog(),
                type: HomeCardType.warning,
              );
        },
      );
    }
    return SignalBuilder(
      builder: (context) {
        final state = UpdateNoticeController.i.updateMessageStateSignal.value;
        if (state.isLoading || state.isRefreshing) {
          return Text(FlutterI18n.translate(context, "setting.fetching_update"))
              .paddingDirectional(horizontal: 16, vertical: 14)
              .withHomeCardStyle(context);
        } else if (state.hasError) {
          return Text(FlutterI18n.translate(context, "setting.fetch_failed"))
              .paddingDirectional(horizontal: 16, vertical: 14)
              .withHomeCardStyle(context);
        } else {
          switch (UpdateNoticeController
              .i
              .isNewVersionAvaliableComputed
              .value) {
            case null:
              return Text(
                    FlutterI18n.translate(context, "setting.current_testing"),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                  .paddingDirectional(horizontal: 16, vertical: 14)
                  .withHomeCardStyle(context, type: HomeCardType.warning);
            case true:
              return Text(
                    FlutterI18n.translate(context, "setting.new_version"),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                  .paddingDirectional(horizontal: 16, vertical: 14)
                  .withHomeCardStyle(
                    context,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            UpdateDialog(updateMessage: state.value!),
                      );
                    },
                    type: HomeCardType.warning,
                  );
            case false:
              return SizedBox(height: 0);
          }
        }
      },
    );
  }
}
