// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:signals/signals_flutter.dart';
import 'package:watermeter/bridge/app_update.dart';
import 'package:watermeter/controller/update_notice_controller.dart';
import 'package:watermeter/page/public_widget/context_extension.dart';
import 'package:watermeter/page/public_widget/toast.dart';
import 'package:watermeter/page/setting/dialogs/update_dialog.dart';
import 'package:watermeter/page/setting/groups/section_setting_scaffold.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as preference;
import 'package:watermeter/routing/routes.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionSettingScaffold(
      title: FlutterI18n.translate(context, "setting.about_info"),
      items: [
        ListTile(
          title: Text(
            FlutterI18n.translate(context, "setting.about_this_program"),
          ),
          subtitle: Text(
            FlutterI18n.translate(
              context,
              "setting.version",
              translationParams: {
                "version":
                    "${preference.packageInfo.version}+"
                    "${preference.packageInfo.buildNumber}",
              },
            ),
          ),
          onTap: () => context.pushReplacementNamed(Routes.about),
          trailing: const Icon(Icons.navigate_next),
        ),
        ListTile(
          title: Text(FlutterI18n.translate(context, "setting.check_update")),
          // 鸿蒙端不显示
          subtitle: Platform.isOhos
              ? null
              : SignalBuilder(
                  builder: (context) {
                    final updateState =
                        UpdateNoticeController.i.updateMessageStateSignal.value;
                    return Text(
                      FlutterI18n.translate(
                        context,
                        "setting.latest_version",
                        translationParams: {
                          "latest":
                              updateState.value?.code ??
                              FlutterI18n.translate(context, "setting.waiting"),
                        },
                      ),
                    );
                  },
                ),
          onTap: () async {
            if (Platform.isOhos) {
              await _checkUpdateViaAppGallery(context);
              return;
            }
            showToast(
              context: context,
              msg: FlutterI18n.translate(context, "setting.fetching_update"),
            );
            UpdateNoticeController.i.reloadUpdateNoticeInfo().then((
              value,
            ) async {
              if (context.mounted) {
                if (UpdateNoticeController
                    .i
                    .updateMessageStateSignal
                    .value
                    .hasError) {
                  showToast(
                    context: context,
                    msg: FlutterI18n.translate(context, "setting.fetch_failed"),
                  );
                  return;
                }
                switch (UpdateNoticeController
                    .i
                    .isNewVersionAvaliableComputed
                    .value) {
                  case null:
                    showToast(
                      context: context,
                      msg: FlutterI18n.translate(
                        context,

                        "setting.current_testing",
                      ),
                    );
                  case true:
                    await showDialog(
                      context: context,
                      builder: (context) => SignalBuilder(
                        builder: (context) => UpdateDialog(
                          updateMessage: UpdateNoticeController
                              .i
                              .updateMessageStateSignal
                              .value
                              .value!,
                        ),
                      ),
                    );
                  case false:
                    showToast(
                      context: context,
                      msg: FlutterI18n.translate(
                        context,
                        "setting.current_stable",
                      ),
                    );
                }
              }
            });
          },
          trailing: const Icon(Icons.navigate_next),
        ),
      ],
    );
  }

  /// 鸿蒙：走华为应用市场（AppGalleryKit）检查更新。
  ///
  /// 流程：隐私合规（未同意则拉起华为标准隐私弹框）→ checkAppUpdate（拿错误码）
  /// → 有新版才弹系统更新弹窗 → 否则明确提示。
  Future<void> _checkUpdateViaAppGallery(BuildContext context) async {
    showToast(
      context: context,
      msg: FlutterI18n.translate(context, "setting.fetching_update"),
    );

    // ① 隐私合规：AppGalleryKit 的能力要求先同意隐私协议，
    //    否则 checkAppUpdate 直接报 1009400005（错在隐私而非更新服务）。
    final privacy = await checkPrivacyStatus();
    if (!context.mounted) return;
    if (privacy != null && (privacy.failed || !privacy.agreed)) {
      if (privacy.notConfigured) {
        // AGC 侧没配隐私政策：用户无从解决，直接说明并记录，避免误导成"网络问题"。
        log.error(
          '[AboutSection] 应用未接入隐私托管服务 code=${privacy.errorCode}'
          '（${appUpdateErrorHint(privacy.errorCode)}）',
        );
        showToast(
          context: context,
          msg:
              '${FlutterI18n.translate(context, "setting.fetch_failed")}'
              '（${privacy.errorCode}）',
        );
        return;
      }
      final consented = await requestPrivacyConsent();
      if (!context.mounted) return;
      if (consented == null || !consented.agreed) {
        log.error(
          '[AboutSection] 用户未同意隐私协议/隐私弹框失败 '
          'code=${consented?.errorCode ?? -1}',
        );
        showToast(
          context: context,
          msg: FlutterI18n.translate(context, "setting.ohos_privacy_required"),
        );
        return;
      }
    }

    // ② 检查更新。
    var result = await checkAppUpdate(force: true);
    if (!context.mounted) return;

    // ③ 隐私状态查询与实际不一致时（例如刚在系统侧撤销同意），再兜一次同意后重试。
    if (result != null && result.errorCode == 1009400005) {
      final consented = await requestPrivacyConsent();
      if (!context.mounted) return;
      if (consented != null && consented.agreed) {
        result = await checkAppUpdate(force: true);
        if (!context.mounted) return;
      }
    }

    // 把这次（可能是用户手动触发的）检查结果同步给首页的更新卡片，
    // 免得刚在设置里查到新版本、回到首页却什么都没显示。
    UpdateNoticeController.i.applyAppUpdateResult(result);

    if (result == null || result.failed) {
      final code = result?.errorCode ?? -1;
      log.error(
        '[AboutSection] 检查更新失败 code=$code（${appUpdateErrorHint(code)}）'
        ' msg=${result?.errorMessage ?? '无法调用应用市场服务'}',
      );
      showToast(
        context: context,
        msg:
            '${FlutterI18n.translate(context, "setting.fetch_failed")}'
            '（$code）',
      );
      return;
    }

    if (!result.hasUpdate) {
      showToast(
        context: context,
        msg: FlutterI18n.translate(context, "setting.current_stable"),
      );
      return;
    }

    final dialog = await showAppUpdateDialog();
    if (!context.mounted) return;
    if (!dialog.ok) {
      log.error(
        '[AboutSection] 更新弹窗展示失败 code=${dialog.displayCode}'
        '（${appUpdateErrorHint(dialog.displayCode)}）msg=${dialog.errorMessage}',
      );
      showToast(
        context: context,
        msg:
            '${FlutterI18n.translate(context, "setting.fetch_failed")}'
            '（${dialog.displayCode}）',
      );
    }
  }
}
