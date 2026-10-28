// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'package:signals/signals.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_campus_life.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/ids_session/school_card_session.dart';

class SchoolCardController {
  static final SchoolCardController i = SchoolCardController._();
  final session = SchoolCardSession();

  SchoolCardController._();

  final moneyStateSignal = signal<AsyncState<String>>(const AsyncLoading());

  Future<void> reloadOverview() async {
    // 演示数据
    if (DemoDataMode.enabled) {
      applyDemoFixture();
      return;
    }
    log.info("[SchoolCardController] Ready to fetch school card overview.");
    final previous = moneyStateSignal.peek().value;
    moneyStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.getOverview();
      moneyStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      moneyStateSignal.value = AsyncState.error(e, s);
      log.handle(e, s, "[SchoolCardController][reloadOverview] Have issue");
    }
  }

  /// 演示数据
  void applyDemoFixture() {
    moneyStateSignal.set(AsyncState.data(demoSchoolCardBalance), force: true);
  }
}
