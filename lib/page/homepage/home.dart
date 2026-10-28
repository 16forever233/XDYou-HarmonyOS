// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// Main page of this program.
import 'dart:async';

import 'package:watermeter/bridge/platform_capability.dart';
import 'package:signals/signals_flutter.dart';

import 'package:based_split_view/based_split_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:watermeter/external/ruisi_flutter/ruisi_flutter.dart';
import 'package:watermeter/page/pig/pig_page.dart';
import 'package:watermeter/page/public_widget/split_page_placeholder.dart';
import 'package:watermeter/page/toolbox/toolbox_page.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/page/public_widget/toast.dart';
import 'package:restart_app/restart_app.dart';
import 'package:watermeter/repository/network_client.dart';
import 'package:watermeter/repository/widget_state_sync.dart';
import 'package:watermeter/controller/homepage_controller.dart';
import 'package:watermeter/controller/update_notice_controller.dart';
import 'package:watermeter/page/homepage/homepage.dart';
import 'package:watermeter/page/setting/setting.dart';
import 'package:watermeter/repository/preference.dart';
import 'package:watermeter/repository/ids_session/ids_session.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';
import 'package:watermeter/page/login/jc_captcha.dart';
import 'package:watermeter/page/login/ids_reauth_dialog.dart';
import 'package:watermeter/repository/ids_session/ids_reauth_client.dart';
import 'package:watermeter/repository/ids_session/slider_captcha_client.dart';
import 'package:watermeter/repository/preference.dart' as preference;

/// 首页底部页签的身份。
///
/// 用身份而不是页号记录"当前在哪一页"：睿思入口默认隐藏（监管审批期间），
/// 它在「设置 → 调试」里的开关一动，页签数量就变、后面所有页号整体平移。
/// 记页号的话用户会被弹到隔壁页面；记身份时每次构建用 `indexOf` 重新求值，
/// 当前页自动跟着走。
enum HomeTab { home, ruisi, toolbox, dashboard, setting }

class PageInformation {
  final HomeTab tab;
  final String name;
  final IconData icon;
  final IconData iconChoice;

  PageInformation({
    required this.tab,
    required this.name,
    required this.icon,
    required this.iconChoice,
  });
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasedSplitView(
      navigatorKey: splitViewKey,
      leftWidget: HomePageMaster(key: leftKey),
      rightPlaceholder: const SplitPagePlaceholder(),
    );
  }
}

class HomePageMaster extends StatefulWidget {
  const HomePageMaster({super.key});

  @override
  State<HomePageMaster> createState() => _HomePageMasterState();
}

class _HomePageMasterState extends State<HomePageMaster>
    with WidgetsBindingObserver {
  /// 当前页签（按身份记录，见 [HomeTab]）。
  HomeTab _currentTab = HomeTab.home;

  /// 上次构建时睿思入口是否可见，用来判断"页签数量变了，需要把 PageView 挪回当前页"。
  bool? _lastShowRuisi;
  static bool refreshAtStart = false;

  late StreamSubscription _intentSub;
  late PageController _controller;
  late final IDSReAuthHandler _idsReAuthHandler;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _idsReAuthHandler = (client) async {
      if (!mounted) throw const IDSReAuthRequiredException();
      return showIDSReAuthDialog(context, client);
    };
    activeIDSReAuthHandler = _idsReAuthHandler;
  }

  void _loginAsync() async {
    showToast(
      context: context,
      msg: FlutterI18n.translate(context, "homepage.login_message"),
    );

    try {
      await HomepageController.i.refresh(
        forceRetryLogin: true,
        sliderCaptcha: (String cookieStr) {
          return SliderCaptchaClientProvider(cookie: cookieStr).solve(
            manualSolver: (provider) =>
                solveSliderCaptchaManually(context, provider),
          );
        },
      );
    } finally {
      if (loginState == IDSLoginState.success) {
        if (mounted) {
          showToast(
            context: context,
            msg: FlutterI18n.translate(
              context,
              "homepage.successful_login_message",
            ),
          );
        }
      } else if (loginState == IDSLoginState.passwordWrong) {
        await preference.remove(preference.Preference.idsPassword);

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(
                FlutterI18n.translate(context, "homepage.password_wrong_title"),
              ),
              content: Text(
                FlutterI18n.translate(
                  context,
                  "homepage.password_wrong_content",
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await syncWidgetLoginState(false);
                    if (mounted) {
                      // HarmonyOS 适配版 restart_app(1.3.2) 不支持 RestartMode，
                      // iOS 也统一走无参数重启
                      Restart.restartApp();
                    }
                  },
                  child: Text(FlutterI18n.translate(context, "confirm")),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showOfflineModeNotice();
                  },
                  child: Text(
                    FlutterI18n.translate(
                      context,
                      "homepage.password_wrong_denial",
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      } else if (loginState != IDSLoginState.cancelled) {
        _showOfflineModeNotice();
      }
    }
  }

  void _showOfflineModeNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            FlutterI18n.translate(context, "homepage.offline_mode_title"),
          ),
          content: Text(
            FlutterI18n.translate(context, "homepage.offline_mode_content"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(FlutterI18n.translate(context, "confirm")),
            ),
          ],
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!refreshAtStart) {
      unawaited(UpdateNoticeController.i.reloadUpdateNoticeInfo());
      log.info(
        "[home][BackgroundFetchFromHome]"
        "Current loginstate: $loginState, if none will _loginAsync.",
      );
      if (loginState == IDSLoginState.none) {
        _loginAsync();
      } else {
        HomepageController.i.refresh(
          forceRetryLogin: true,
          sliderCaptcha: (String cookieStr) {
            return SliderCaptchaClientProvider(cookie: cookieStr).solve(
              manualSolver: (provider) =>
                  solveSliderCaptchaManually(context, provider),
            );
          },
        );
      }
      refreshAtStart = true;
    }
  }

  @override
  void dispose() {
    if (identical(activeIDSReAuthHandler, _idsReAuthHandler)) {
      activeIDSReAuthHandler = null;
    }
    if (supportsPlatformIntentSub) _intentSub.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 订阅睿思开关：它在「设置 → 调试」里被切换时，这个子树会重建，
    // 底部页签与 PageView 的页数跟着增减（见 repository/ruisi_forum.dart）。
    return SignalBuilder(
      builder: (context) => _buildScaffold(context, supportsRuisiForum),
    );
  }

  /// 当前可用的页签（固定顺序，睿思取决于开关）。
  List<HomeTab> _tabsFor(bool showRuisi) => [
    HomeTab.home,
    if (showRuisi) HomeTab.ruisi,
    HomeTab.toolbox,
    HomeTab.dashboard,
    HomeTab.setting,
  ];

  /// 页签的底部导航条目。页号即列表位置
  /// 与 PageView 的 page index 都是"在列表中的位置"，两者必须与 [HomeTab] 顺序一致。
  PageInformation _destinationFor(BuildContext context, HomeTab tab) {
    switch (tab) {
      case HomeTab.home:
        return PageInformation(
          tab: tab,
          name: FlutterI18n.translate(context, "homepage.homepage"),
          icon: Icons.school_outlined,
          iconChoice: Icons.school,
        );
      case HomeTab.ruisi:
        return PageInformation(
          tab: tab,
          name: FlutterI18n.translate(context, "homepage.ruisi"),
          icon: Icons.forum_outlined,
          iconChoice: Icons.forum,
        );
      case HomeTab.toolbox:
        return PageInformation(
          tab: tab,
          name: FlutterI18n.translate(context, "homepage.toolbox.toolbox"),
          icon: MingCuteIcons.mgc_tool_line,
          iconChoice: MingCuteIcons.mgc_tool_fill,
        );
      case HomeTab.dashboard:
        return PageInformation(
          tab: tab,
          name: FlutterI18n.translate(context, "homepage.dashboard"),
          icon: MingCuteIcons.mgc_pig_line,
          iconChoice: MingCuteIcons.mgc_pig_fill,
        );
      case HomeTab.setting:
        return PageInformation(
          tab: tab,
          name: FlutterI18n.translate(context, "homepage.setting"),
          icon: MingCuteIcons.mgc_user_2_line,
          iconChoice: MingCuteIcons.mgc_user_2_fill,
        );
    }
  }

  /// 页签对应的整页内容。顺序由 [HomeTab] 保证，页面与导航不可能错位。
  Widget _pageFor(HomeTab tab) {
    switch (tab) {
      case HomeTab.home:
        return MainPage(changePage: () => _selectTab(HomeTab.ruisi));
      case HomeTab.ruisi:
        return RuisiApp(
          prefs: preference.prefs,
          cookiePath: supportPath.path,
          talker: TalkerFlutter.init(),
        );
      case HomeTab.toolbox:
        return const ToolBoxPage();
      case HomeTab.dashboard:
        return const PigPage();
      case HomeTab.setting:
        return const SettingWindow();
    }
  }

  /// 切到某个页签（按身份）。目标页签当前不可用时（睿思被隐藏）什么都不做。
  void _selectTab(HomeTab tab) {
    final int index = _tabsFor(supportsRuisiForum).indexOf(tab);
    if (index < 0) return;
    setState(() => _currentTab = tab);
    if (_controller.hasClients) {
      _controller.jumpToPage(index);
    }
  }

  Widget _buildScaffold(BuildContext context, bool showRuisi) {
    final tabs = _tabsFor(showRuisi);
    final destinations = tabs
        .map((tab) => _destinationFor(context, tab))
        .toList();

    // 当前页签可能已不可用（睿思被隐藏）→ 回首页。
    if (!tabs.contains(_currentTab)) {
      _currentTab = HomeTab.home;
    }
    final int selectedIndex = tabs.indexOf(_currentTab);

    // PageView 的控制器是按"数字页号"记位置的：睿思开关会让页签数量变化，
    // 这时要把它挪到当前页签的新页号上，否则会显示成隔壁那一页。
    // 只改一个构建期的记忆字段，不触发 setState。
    if (_lastShowRuisi != null && _lastShowRuisi != showRuisi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(selectedIndex);
        }
      });
    }
    _lastShowRuisi = showRuisi;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: PageView(
        controller: _controller,
        children: tabs.map(_pageFor).toList(),
        onPageChanged: (int index) {
          if (index >= 0 &&
              index < tabs.length &&
              _currentTab != tabs[index]) {
            setState(() => _currentTab = tabs[index]);
          }
        },
      ),
      bottomNavigationBar: NavigationBar(
        destinations: [
          for (var i = 0; i < destinations.length; i++)
            NavigationDestination(
              icon: Icon(
                selectedIndex == i
                    ? destinations[i].iconChoice
                    : destinations[i].icon,
              ),
              label: destinations[i].name,
            ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) => _selectTab(tabs[index]),
      ),
    );
  }
}
