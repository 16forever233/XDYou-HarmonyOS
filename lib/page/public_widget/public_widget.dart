// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0 OR MIT

// Useful weights to simplify watermeter programming.

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:styled_widget/styled_widget.dart';

/// Check the width
bool isPhone(BuildContext context) => MediaQuery.of(context).size.width < 480;
bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width > 840;
const double sheetMaxWidth = 600;

/// 底部手势导航条（小白条）的避让高度。
///
/// 沉浸式布局下 `MediaQuery.padding.bottom` 为 0，但
/// `MediaQuery.viewPadding.bottom` 仍保留系统手势区高度；
/// 引擎未上报时用 16 逻辑像素兜底。
/// 仅用于给贴底控件加安全间距，不影响页面整体布局。
double bottomGestureBarInset(BuildContext context) {
  final double inset = MediaQuery.viewPaddingOf(context).bottom;
  return inset > 0 ? inset : 16.0;
}

/// Use it to show the small items.
class TagsBoxes extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  const TagsBoxes({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.all(Radius.circular(9)),
      ),
      child: Text(
        text,
        textScaler: const TextScaler.linear(0.9),
        style: TextStyle(
          color:
              textColor ??
              (Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Colors.black),
        ),
      ),
    );
  }
}

/// A listview widget. First is the type, second is the list...
class DataList<T> extends StatelessWidget {
  final List<T> list;
  final Widget Function(T toUse) initFormula;
  final ScrollPhysics? physics;
  const DataList({
    super.key,
    required this.list,
    required this.initFormula,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: physics,
      itemCount: list.length,
      itemBuilder: (context, index) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: sheetMaxWidth),
            child: initFormula(list[index]),
          ),
        );
      },
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12.5, vertical: 9.0),
    );
  }
}

class InformationWithIcon extends StatelessWidget {
  final IconData icon;
  final String text;
  const InformationWithIcon({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Expanded(child: Text(text)),
      ],
    );
  }
}

/// Switch page with animation.
Route createRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      final curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

/// Used with a card inside a card.
class InfoDetailBox extends StatelessWidget {
  final Widget child;
  const InfoDetailBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Container(padding: const EdgeInsets.all(8), child: child),
    );
  }
}

/// A reload widget/page
class ReloadWidget extends StatelessWidget {
  final void Function() function;
  // Stands for Exception...
  final Object? errorStatus;
  final StackTrace? stackTrace;
  final String? buttonName;
  const ReloadWidget({
    super.key,
    required this.function,
    this.buttonName,
    this.errorStatus,
    this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return [
          [
                Text(
                  FlutterI18n.translate(context, "error_detected"),
                  style: const TextStyle(fontSize: 16),
                ).center().padding(bottom: 8),
                if (errorStatus != null)
                  Text("Description: $errorStatus").padding(bottom: 8),
                if (stackTrace != null)
                  Text("Stacktrace: \n$stackTrace", textAlign: TextAlign.left),
              ]
              .toColumn(crossAxisAlignment: CrossAxisAlignment.start)
              .scrollable()
              .expanded(),
          SafeArea(
            top: false,
            left: false,
            right: false,
            child: FilledButton(
              onPressed: function,
              child: Text(
                buttonName ??
                    FlutterI18n.translate(context, "click_to_refresh"),
              ),
            ).padding(top: 8),
          ),
        ]
        .toColumn(mainAxisAlignment: MainAxisAlignment.center)
        // 底部留出小白条避让间距：按钮浮于手势条上方，页面背景仍延伸到底边（沉浸保持）
        .padding(
          horizontal: 20,
          top: 8,
          bottom: 8 + bottomGestureBarInset(context),
        )
        .constrained(maxWidth: 600)
        .center();
  }
}
