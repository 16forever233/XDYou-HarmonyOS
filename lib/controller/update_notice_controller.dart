// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';
import 'dart:math' as math;

import 'package:signals/signals.dart';
import 'package:watermeter/bridge/app_update.dart';
import 'package:watermeter/model/pda_service/message.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/miscellaneous_session/pda_service_session.dart';
import 'package:watermeter/repository/preference.dart' as pref;

class UpdateNoticeController {
  static final PdaServiceSession session = PdaServiceSession();
  static UpdateNoticeController i = UpdateNoticeController._();

  UpdateNoticeController._();

  final updateMessageStateSignal = signal<AsyncState<UpdateMessage>>(
    const AsyncLoading(),
  );

  /// 鸿蒙端：最近一次华为应用市场检查的结果（null = 还没查过）。
  final appUpdateResultSignal = signal<AppUpdateResult?>(null);

  /// 鸿蒙端：是否已经拿到过市场检查的结果。

  final appUpdateCheckedSignal = signal<bool>(false);

  /// 鸿蒙端：市场是否有新版本，供首页/登录页的更新卡片使用。
  late final hasAppUpdateComputed = computed(
    () => appUpdateResultSignal.value?.hasUpdate ?? false,
  );

  /// 把一次应用市场检查结果并进来。
  ///
  /// 关于页的「检查软件更新」是直接调 `checkAppUpdate(force: true)` 的，结果也
  /// 走这里，这样手动查出来的新版本会同时反映到首页卡片上。
  void applyAppUpdateResult(AppUpdateResult? result) {
    if (!Platform.isOhos) {
      return;
    }
    appUpdateResultSignal.value = result;
    appUpdateCheckedSignal.value = true;
  }

  Future<void> reloadUpdateNoticeInfo() async {
    // 鸿蒙端查的是**华为应用市场**（AppGalleryKit），不是上游的更新接口。
    //
    // 为什么不查上游：`pda_service_session.dart` 打的是
    // `legacy.superbart.top/traintime_pda_backend` —— 那是**上游 Traintime PDA**
    // 的接口，返回的 code 是上游版本号，更新链接也指向
    // 上游的 App Store / F-Droid / GitHub。XDYou 的更新渠道是应用市场，拿上游版本号
    // 当"最新版本"会误导用户（
    //
    // 启动时（main.dart 首帧后）与首页/登录页加载时都会调到这里；重复调用由
    // `bridge/app_update.dart` 的 10 分钟缓存兜住，不会反复打市场接口（限流 1009400006）。
    if (Platform.isOhos) {
      try {
        applyAppUpdateResult(await checkAppUpdate());
      } catch (e, s) {
        applyAppUpdateResult(null);
        log.handle(e, s, "[UpdateNoticeController] AppGallery 检查更新失败");
      }
      return;
    }
    final previous = updateMessageStateSignal.peek().value;
    updateMessageStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.checkUpdate();
      updateMessageStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      updateMessageStateSignal.value = AsyncState.error(e, s);
      log.handle(
        e,
        s,
        "[UpdateNoticeController][reloadUpdateNoticeInfo] Have issue",
      );
    }
  }

  /// true: new version avaliable
  /// false: latest version
  /// null: testing version
  late final isNewVersionAvaliableComputed = computed(() {
    return updateMessageStateSignal.value.map(
      data: (updateMessage) {
        List<int> versionCode = updateMessage.code
            .split('.')
            .map((value) => int.parse(value))
            .toList();
        List<int> localCode = pref.packageInfo.version
            .split('.')
            .map((value) => int.parse(value))
            .toList();
        bool? isNewAvaliable = false;
        for (
          int i = 0;
          i < math.min(versionCode.length, localCode.length);
          i++
        ) {
          if (versionCode[i] > localCode[i]) {
            isNewAvaliable = true;
            break;
          } else if (versionCode[i] < localCode[i]) {
            isNewAvaliable = null;
            break;
          }
        }
        return isNewAvaliable;
      },
      error: (err, _) => false,
      loading: () => false,
    );
  });
}
