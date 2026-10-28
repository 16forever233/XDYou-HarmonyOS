// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'package:signals/signals.dart';
import 'package:watermeter/model/xidian_ids/library.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/ids_session/library_session.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_campus_life.dart';

class LibraryController {
  static final LibraryController i = LibraryController._();
  final Map<int, Future<List<BookLocation>>> _bookLocationFutures = {};
  final LibrarySession session = LibrarySession();

  LibraryController._();

  final libraryBorrowStateSignal = signal<AsyncState<List<BorrowData>>>(
    const AsyncLoading(),
  );

  Future<void> reloadBorrowList() async {
    // 演示数据
    if (DemoDataMode.enabled) {
      applyDemoFixture();
      return;
    }
    final previous = libraryBorrowStateSignal.peek().value;
    libraryBorrowStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.getBorrowList();
      libraryBorrowStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      libraryBorrowStateSignal.value = AsyncState.error(e, s);
      log.handle(e, s, "[LibraryController][reloadBorrowList] Have issue");
    }
  }

  /// 演示数据
  void applyDemoFixture() {
    libraryBorrowStateSignal.set(
      AsyncState.data(buildDemoBorrowList()),
      force: true,
    );
  }

  Future<List<BookLocation>> loadBookLocations(BookInfo book) {
    final items = book.items;
    if (items != null) {
      return Future.value(items);
    }

    return _bookLocationFutures.putIfAbsent(book.docNumber, () async {
      try {
        return await session.bookLocations(book.docNumber);
      } catch (e, s) {
        _bookLocationFutures.remove(book.docNumber);
        log.handle(e, s, "[LibraryController][loadBookLocations] Have issue");
        rethrow;
      }
    });
  }
}
