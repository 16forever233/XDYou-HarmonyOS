// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:intl/intl.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/model/session_state.dart';
import 'package:watermeter/model/xidian_ids/empty_classroom.dart';
import 'package:watermeter/page/public_widget/public_widget.dart';
import 'package:watermeter/page/public_widget/safe_scroll_padding.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/ids_session/empty_classroom_session.dart';
import 'package:watermeter/repository/preference.dart' as preference;

class EmptyClassroomSearchWindow extends StatefulWidget {
  final List<EmptyClassroomPlace> places;

  const EmptyClassroomSearchWindow({super.key, required this.places});

  @override
  State<EmptyClassroomSearchWindow> createState() =>
      _EmptyClassroomSearchWindowState();
}

/// Dialog for building selection with auto-scroll to selected item
class _BuildingSelectionDialog extends StatefulWidget {
  final List<EmptyClassroomPlace> places;
  final EmptyClassroomPlace chosen;
  final ValueChanged<EmptyClassroomPlace> onChanged;

  const _BuildingSelectionDialog({
    required this.places,
    required this.chosen,
    required this.onChanged,
  });

  @override
  State<_BuildingSelectionDialog> createState() =>
      _BuildingSelectionDialogState();
}

class _BuildingSelectionDialogState extends State<_BuildingSelectionDialog> {
  final ScrollController _scrollController = ScrollController();

  /// 列表视口高度（用于把选中项滚动到可视区中央），由 MediaQuery 计算。
  ///
  /// 本弹窗不能用 AlertDialog：AlertDialog 用 IntrinsicWidth 测量内容
  /// （material/dialog.dart AlertDialog.build），而 ListView 视口在 debug
  /// 构建下不支持 intrinsic 测量（rendering/viewport.dart
  /// debugThrowIfNotCheckingIntrinsics 直接抛 FlutterError），整棵弹窗
  /// 布局随之失败。因此改用 Dialog（内部无 IntrinsicWidth），高度由
  /// MediaQuery 计算。
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    log.info('[EmptyClassroom] building dialog initState');
    // Scroll to selected item after the dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedItem();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 视口高度在依赖变化时更新（initState 阶段不可读 MediaQuery）
    _viewportHeight = MediaQuery.sizeOf(context).height * 0.6;
  }

  void _scrollToSelectedItem() {
    try {
      // Find the index of the selected item
      final selectedIndex = widget.places.indexWhere(
        (place) => place.code == widget.chosen.code,
      );

      if (selectedIndex == -1 || !_scrollController.hasClients) return;
      // 首帧布局尚未完成时直接跳过，不强行滚动
      if (_viewportHeight <= 0) return;

      // Estimate item height (RadioListTile dense 约 48dp)
      const double estimatedItemHeight = 48.0;
      final double targetOffset = selectedIndex * estimatedItemHeight;

      // Calculate offset to center the selected item
      double scrollOffset =
          targetOffset - (_viewportHeight / 2) + (estimatedItemHeight / 2);

      // Clamp the offset to valid scroll range
      final ScrollPosition position = _scrollController.position;
      // 视口尚未完成布局（无尺寸）时跳过，避免 min/maxScrollExtent 空引用
      if (!position.hasContentDimensions) return;
      scrollOffset = scrollOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      // 直接跳转而非动画，避免与弹窗打开动画叠加
      if (scrollOffset > 0) {
        _scrollController.jumpTo(scrollOffset);
      }
    } catch (e, s) {
      log.handle(e, s, '[EmptyClassroom] building dialog scroll failed');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log.info('[EmptyClassroom] building dialog build');
    // 用 Dialog 而不是 AlertDialog：AlertDialog/SimpleDialog 会用
    // IntrinsicWidth 测量内容，而 ListView 视口不支持 intrinsic 测量，
    // debug 构建直接抛 FlutterError（框架官方文档也建议此类内容直接用
    // Dialog）。Dialog 内部只有 ConstrainedBox，不触发 intrinsic 测量。
    // 宽度收紧到 288：上游 AlertDialog 的 IntrinsicWidth 会把内容宽
    // 「收缩」到最小 280 左右，Dialog 无 intrinsic 测量，需显式定宽，
    // 否则视口会撑满可用宽度（376-48=328），显得过宽。
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 240,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              itemCount: widget.places.length,
              itemBuilder: (context, index) {
                final EmptyClassroomPlace place = widget.places[index];
                return _BuildingTile(
                  name: place.name,
                  selected: place.code == widget.chosen.code,
                  onTap: () {
                    log.info('[EmptyClassroom] building picked: ${place.name}');
                    widget.onChanged(place);
                    Navigator.pop(context, place);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 鸿蒙端 InkFeatures 在弹窗转场中存在布局断言问题
/// （RenderBox was not laid out），改用 GestureDetector + Row 自绘行规避。
class _BuildingTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _BuildingTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClassroomSearchWindowState
    extends State<EmptyClassroomSearchWindow> {
  final TextEditingController text = TextEditingController();
  List<EmptyClassroomData> fetchedData = [];
  late EmptyClassroomPlace chosen;

  late ColorScheme colorScheme;
  late DateTime time;

  SessionState state = SessionState.none;
  String semesterCode = preference.getString(
    preference.Preference.currentSemester,
  );

  DateFormat formatter = DateFormat("yyyy-MM-dd");

  List<EmptyClassroomData> get data {
    List<EmptyClassroomData> toReturn = [];
    for (var i in fetchedData) {
      if (i.name.contains(text.text)) toReturn.add(i);
    }
    return toReturn;
  }

  void updateData() async {
    try {
      state = SessionState.fetching;
      fetchedData.clear();
      int startYear = int.parse(semesterCode.substring(0, 4));
      fetchedData.addAll(
        await EmptyClassroomSession().searchData(
          buildingCode: chosen.code,
          date: formatter.format(time),
          semesterRange: "$startYear-${startYear + 1}",
          semesterPart: semesterCode[semesterCode.length - 1],
        ),
      );
      state = SessionState.fetched;
    } catch (e, s) {
      state = SessionState.error;
      log.error("Error occured while fetching empty classroom.", e, s);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    String lastChosenClassroom = preference.getString(
      preference.Preference.emptyClassroomLastChoice,
    );
    EmptyClassroomPlace? toGet;
    if (lastChosenClassroom.isNotEmpty) {
      for (var i in widget.places) {
        if (i.code == lastChosenClassroom) toGet = i;
      }
    }
    toGet ??= widget.places.first;
    chosen = toGet;
    time = DateTime.now();
    updateData();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    colorScheme = Theme.of(context).colorScheme;
    super.didChangeDependencies();
  }

  Widget getIcon(bool isUsed, {int? index}) =>
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: isUsed
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: index != null
            ? Text(
                index.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: isUsed
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                ),
              ).center()
            : null,
      ).decorated(
        border: Border.all(
          width: 1,
          color: Theme.of(context).colorScheme.primary,
        ),
        borderRadius: BorderRadius.circular(6),
      );

  void chooseBuilding() {
    log.info(
      '[EmptyClassroom] building button tapped, places=${widget.places.length}',
    );
    showDialog<EmptyClassroomPlace>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _BuildingSelectionDialog(
        places: widget.places,
        chosen: chosen,
        onChanged: (EmptyClassroomPlace value) {
          setState(() {
            chosen = value;
            preference.setString(
              preference.Preference.emptyClassroomLastChoice,
              chosen.code,
            );
            updateData();
          });
        },
      ),
    ).then((value) {
      if (value == null) {
        log.info('[EmptyClassroom] building dialog dismissed (back key)');
      } else {
        log.info('[EmptyClassroom] building dialog closed with ${value.name}');
      }
    }).catchError((Object e, StackTrace s) {
      log.handle(e, s, '[EmptyClassroom] building dialog failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        [
              TextField(
                controller: text,
                autofocus: false,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: FlutterI18n.translate(
                    context,
                    "empty_classroom.search_hint",
                  ),
                  isDense: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                onSubmitted: (String text) => setState(() {}),
              ).padding(bottom: 8),
              [
                    [
                      FilledButton(
                        onPressed: () {
                          // 延迟到下一帧再打开弹窗：避免本次点击事件被随后
                          // 建立的弹窗遮罩层接收而立即关闭（鸿蒙端事件时序差异）
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            showCalendarDatePicker2Dialog(
                              context: context,
                              config: CalendarDatePicker2WithActionButtonsConfig(
                                calendarType: CalendarDatePicker2Type.single,
                              ),
                              dialogSize: const Size(325, 400),
                              value: [time],
                            ).then((value) {
                              if (value?.length == 1 && value?[0] != null) {
                                setState(() {
                                  time = value![0]!;
                                  updateData();
                                });
                              }
                            });
                          });
                        },
                        child: Text(
                          FlutterI18n.translate(
                            context,
                            "empty_classroom.date",
                            translationParams: {"date": formatter.format(time)},
                          ),
                        ),
                      ).padding(right: 8),
                      FilledButton(
                        onPressed: () {
                          // 不清空输入框内容、不触发重建，避免干扰本次点击手势；
                          // 同样延迟到下一帧再打开弹窗，防止遮罩层吞掉本次点击
                          text.clear();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            chooseBuilding();
                          });
                        },
                        child: Text(
                          FlutterI18n.translate(
                            context,
                            "empty_classroom.building",
                            translationParams: {"building": chosen.name},
                          ),
                        ),
                      ),
                    ].toRow(),
                  ]
                  .toRow(mainAxisAlignment: MainAxisAlignment.center)
                  .padding(bottom: 8),
              [
                [
                  getIcon(true),
                  const SizedBox(width: 4.0),
                  Text(
                    FlutterI18n.translate(context, "empty_classroom.occupied"),
                  ),
                ].toRow().padding(right: 8.0),
                [
                  getIcon(false),
                  const SizedBox(width: 4.0),
                  Text(FlutterI18n.translate(context, "empty_classroom.empty")),
                ].toRow(),
              ].toRow(mainAxisAlignment: MainAxisAlignment.center),
            ]
            .toColumn()
            .padding(horizontal: 14, top: 8, bottom: 12)
            .constrained(maxWidth: 480),
        if (state == SessionState.fetching)
          const CircularProgressIndicator().center().expanded()
        else if (state == SessionState.error)
          ReloadWidget(
            function: () => setState(() {
              updateData();
            }),
          ).expanded()
        else
          ListView.separated(
            itemCount: data.length,
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ).withSafeBottom(context),
            itemBuilder: (context, index) {
              final item = data[index];
              return Row(
                children: [
                  Flexible(
                    flex: 3,
                    child: Text(
                      item.name,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ).center(),
                  ),
                  Flexible(
                    flex: 4,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4.0,
                      children: List.generate(
                        4,
                        (i) => getIcon(item.isUsed[i], index: i + 1),
                      ),
                    ).center(),
                  ),
                  Flexible(
                    flex: 4,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4.0,
                      children: List.generate(
                        4,
                        (i) => getIcon(item.isUsed[i + 4], index: i + 5),
                      ),
                    ).center(),
                  ),
                  Flexible(
                    flex: 3,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4.0,
                      children: List.generate(
                        3,
                        (i) => getIcon(item.isUsed[i + 8], index: i + 9),
                      ),
                    ).center(),
                  ),
                ],
              ).constrained(maxWidth: sheetMaxWidth).center();
            },
            separatorBuilder: (BuildContext context, int index) =>
                SizedBox(height: 12),
          ).expanded(),
      ],
    );
  }
}
