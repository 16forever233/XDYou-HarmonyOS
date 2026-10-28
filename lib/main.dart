// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// Intro of the watermeter program.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:watermeter/bridge/app_info.dart';
import 'package:watermeter/bridge/platform_capability.dart';
import 'package:watermeter/repository/card_debug_store.dart';
import 'package:watermeter/repository/desktop_card_sync_service.dart';

import 'package:catcher_2/catcher_2.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:signals/signals_flutter.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watermeter/controller/theme_controller.dart';
import 'package:watermeter/controller/update_notice_controller.dart';
import 'package:watermeter/repository/network_client.dart' as repo_general;
import 'package:watermeter/repository/notification/notification_registrar.dart';
import 'package:watermeter/repository/preference.dart' as preference;
import 'package:watermeter/page/homepage/home.dart';
import 'package:watermeter/page/login/login_window.dart';
import 'package:watermeter/repository/ids_session/ids_session.dart';
import 'package:watermeter/themes/font_setting.dart';
import 'package:home_widget/home_widget.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_data_service.dart';
import 'package:watermeter/repository/demo_data/review_account.dart';
import 'package:watermeter/repository/ruisi_forum.dart';

void main() async {
  // Make sure the library is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  log.info(
    "Traintime PDA Codebase is written by BenderBlog Rodriguez and contributors",
  );

  // Load cookiejar and other stuff
  repo_general.supportPath = await getApplicationSupportDirectory();

  // Load shared preference. Per the migration guide
  // https://pub.dev/packages/shared_preferences#migrating-from-sharedpreferences-to-sharedpreferencesasyncwithcache
  const SharedPreferencesOptions sharedPreferencesOptions =
      SharedPreferencesOptions();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getKeys().isNotEmpty) {
    await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
      legacySharedPreferencesInstance: prefs,
      sharedPreferencesAsyncOptions: sharedPreferencesOptions,
      migrationCompletedKey: 'pdaMigrationCompleted',
    );
  }
  preference.prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );

  // 调试入口开关：只有调试签名的安装包才显示「设置 → 调试 → 考试调试」。
  // 正式签名包（应用市场）里一并清掉可能遗留的模拟考试数据。
  await resolveDebugProvisioned();
  if (!isDebugProvisioned) {
    await CardDebugStore.clear();
  }
  // 睿思论坛开关：默认一律隐藏，只有调试签名包允许用调试页的开关打开
  // （正式包若也能打开，就等于应用在提供该功能，违反监管要求）。
  await RuisiForum.resolve();
  // 设备实际 API 等级：用于按设备能力决定代理提醒的调度上限（见 reminder_quota.dart）。
  await resolveDeviceSdkApiVersion();
  // 审核体验账号：必须在 DemoDataMode.resolve() 之前解析 ——
  // 它是正式包里让演示数据"可用"的唯一途径（见 DemoDataMode.available）。
  await ReviewAccount.resolve();
  // 演示数据（截图模式）：未授权时强制关闭；调试包或审核体验模式下若上次开着，
  // 这里恢复内存标志，`isFirst` 随之按"已登录"处理。
  await DemoDataMode.resolve();
  // 演示/审核模式下把登录态直接标成已登录。
  //
  // 为什么必须这么做：`loginState` 是个进程内全局，默认 `none`，而
  // `IDSSession.dio` 在 `offline`（= 非 success 且非 manual）时**直接抛
  // DioException.requestCancelled**，首页那几个入口卡片（成绩 / 考勤 / 空闲教室 /
  // 校园卡）也各自用 `offline` 拦人、只弹「离线模式」不让进。
  // 审核账号是本地账号、没有西电凭据，重启后 loginState 会掉回 none ——
  // 表现就是"重启后好多东西打不开"。这里把它补回来，与首次审核登录保持一致。
  // 注意：只有在演示模式生效时才这么做，正常登录路径完全不受影响。
  if (DemoDataMode.enabled) {
    loginState = IDSLoginState.success;
    log.info('[main] 演示/审核模式：已将登录态标记为已登录（loginState=success）');
  }

  // 桌面卡片初始数据：根据本地课表缓存同步一次。
  // 注意：不能在此处同步执行——HomepageController 构造与 computed 求值
  // 都是主线程重活，debug 冷启动期叠加会导致 THREAD_BLOCK_6S 被系统杀掉
  // （表现为打开 App 白屏闪退）。延迟到首帧渲染后再执行。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 演示数据（截图模式）上次开着的话，首帧之后再注入 ——
    // 同样是为了避免冷启动期主线程干重活（THREAD_BLOCK_6S）。
    if (DemoDataMode.enabled) {
      unawaited(DemoDataModeService.applyAll());
    }
    unawaited(syncDesktopCard());
    // 鸿蒙端：每次启动自动检查一次更新（走华为应用市场），有新版本时首页/登录页的
    // 更新卡片会按上游同款样式（加粗 + warning 配色）提示。
    // 放在首帧之后：`checkAppUpdate` 要求应用在前台，也不该占用冷启动主线程；
    // 首页与登录页还会各调一次，重复调用由 bridge 的 10 分钟缓存兜住。
    // 其它平台的更新走上游服务，保持上游原有节奏（首页/登录页加载时各查一次），
    // 不为它在启动时多打一次别人的接口。
    if (Platform.isOhos) {
      unawaited(UpdateNoticeController.i.reloadUpdateNoticeInfo());
    }
  });


  // Load package info.
  preference.packageInfo = await PackageInfo.fromPlatform();

  // Have user registered?
  String username = preference.getString(preference.Preference.idsAccount);
  String password = preference.getString(preference.Preference.idsPassword);
  // 演示数据（截图模式）或审核体验账号下都不要求真实凭据：直接进主界面，
  // 期间各控制器都会走假数据分支出（**绝不写假凭据**）。
  bool isFirst = (username.isEmpty || password.isEmpty) && !DemoDataMode.enabled;
  log.info("isFirstLogin: $isFirst");

  Catcher2(
    rootWidget: MyApp(isFirst: isFirst),
    debugConfig: preference.catcherOptions,
    releaseConfig: preference.catcherOptions,
    navigatorKey: preference.debuggerKey,
  );

  // 鸿蒙端 catcher_2 的 PageReportMode 不支持 unknown platform，
  // 框架异常上报后会被静默丢弃（只有一条 warning，看不到错误详情）。
  // 这里链式挂接 FlutterError.onError，把框架异常同时写入 Talker 日志，
  // 便于真机排查时读取真实错误与堆栈。
  final void Function(FlutterErrorDetails)? previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    log.handle(
      details.exception,
      details.stack ?? StackTrace.current,
      '[FlutterError] ${details.context ?? ""}',
    );
    previousOnError?.call(details);
  };

  // Initialize notification services
  if (supportsSystemNotifications) {
    try {
      await NotificationServiceRegistrar().initializeAllServices();

      // Handle app launch from notification
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final services = NotificationServiceRegistrar().getAllServices();
        await Future.wait(
          services.map((service) => service.handleAppLaunchFromNotification()),
        );
      });
    } catch (e) {
      log.error('Failed to initialize notification services', e);
    }
  }
}

class MyApp extends StatefulWidget {
  final bool isFirst;

  const MyApp({super.key, required this.isFirst});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeController appTheme = ThemeController.i;
  ThemeData? _cachedLight;
  ThemeData? _cachedDark;
  FlexSchemeColor? _cachedLightColor;
  FlexSchemeColor? _cachedDarkColor;
  double? _cachedLightWeight;
  double? _cachedDarkWeight;

  /// ThemeData 按配色缓存，深浅色切换/重复切换时避免重复构建整棵主题树。
  /// 注意：colorSignal.value 每次都是新的 sublist（List 身份比较必 miss），
  /// 因此按列表元素 FlexSchemeColor 的实例身份做命中判断。
  /// 字体粗细（上游 1.6.6 新增的全局设置）会改变整棵主题树，必须一并参与
  /// 命中判断，否则在设置页调完粗细后主题不会重建。
  ThemeData _lightTheme(List<FlexSchemeColor> color) {
    final FlexSchemeColor element = color.first;
    final double weight = appTheme.fontWeightSignal.value;
    if (_cachedLight != null &&
        identical(_cachedLightColor, element) &&
        _cachedLightWeight == weight) {
      return _cachedLight!;
    }
    _cachedLightColor = element;
    _cachedLightWeight = weight;
    return _cachedLight = FlexThemeData.light(

            colors: color.first,
            usedColors: 1,
            surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
            blendLevel: 2,
            tabBarStyle: FlexTabBarStyle.forAppBar,
            subThemesData: const FlexSubThemesData(
              interactionEffects: true,
              tintedDisabledControls: true,
              blendOnLevel: 8,
              useM2StyleDividerInM3: true,
              defaultRadius: 12.0,
              elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
              elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
              outlinedButtonOutlineSchemeColor: SchemeColor.primary,
              toggleButtonsBorderSchemeColor: SchemeColor.primary,
              segmentedButtonSchemeColor: SchemeColor.primary,
              segmentedButtonBorderSchemeColor: SchemeColor.primary,
              unselectedToggleIsColored: true,
              sliderValueTinted: true,
              inputDecoratorSchemeColor: SchemeColor.primary,
              inputDecoratorIsFilled: true,
              inputDecoratorContentPadding: EdgeInsetsDirectional.fromSTEB(
                12,
                16,
                12,
                12,
              ),
              inputDecoratorBackgroundAlpha: 7,
              inputDecoratorBorderSchemeColor: SchemeColor.primary,
              inputDecoratorBorderType: FlexInputBorderType.outline,
              inputDecoratorRadius: 8.0,
              inputDecoratorUnfocusedBorderIsColored: true,
              inputDecoratorBorderWidth: 1.0,
              inputDecoratorFocusedBorderWidth: 2.0,
              inputDecoratorPrefixIconSchemeColor:
                  SchemeColor.onPrimaryFixedVariant,
              inputDecoratorSuffixIconSchemeColor: SchemeColor.primary,
              fabUseShape: true,
              fabAlwaysCircular: true,
              fabSchemeColor: SchemeColor.secondary,
              popupMenuRadius: 8.0,
              popupMenuElevation: 3.0,
              alignedDropdown: true,
              dialogBackgroundSchemeColor: SchemeColor.secondaryContainer,
              drawerIndicatorRadius: 12.0,
              drawerIndicatorSchemeColor: SchemeColor.primary,
              bottomNavigationBarMutedUnselectedLabel: false,
              bottomNavigationBarMutedUnselectedIcon: false,
              menuRadius: 8.0,
              menuElevation: 3.0,
              menuBarRadius: 0.0,
              menuBarElevation: 2.0,
              menuBarShadowColor: Color(0x00000000),
              searchBarElevation: 1.0,
              searchViewElevation: 1.0,
              searchUseGlobalShape: true,
              navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
              navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
              navigationBarIndicatorSchemeColor: SchemeColor.primary,
              navigationBarIndicatorRadius: 12.0,
              navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
              navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
              navigationRailUseIndicator: true,
              navigationRailIndicatorSchemeColor: SchemeColor.primary,
              navigationRailIndicatorOpacity: 1.00,
              navigationRailIndicatorRadius: 12.0,
              navigationRailBackgroundSchemeColor: SchemeColor.surface,
              navigationRailLabelType: NavigationRailLabelType.all,
            ),
            keyColors: const FlexKeyColors(keepPrimary: true),
            tones: FlexSchemeVariant.jolly.tones(Brightness.light),
            visualDensity: FlexColorScheme.comfortablePlatformDensity,
            cupertinoOverrideTheme: const CupertinoThemeData(
              applyThemeToAll: true,
            ),
          ).useSystemChineseFont(Brightness.light).applyFontWeight(
            fontWeightFromSlider(weight),
          );
  }

  ThemeData _darkTheme(List<FlexSchemeColor> color) {
    final FlexSchemeColor element = color.last;
    final double weight = appTheme.fontWeightSignal.value;
    if (_cachedDark != null &&
        identical(_cachedDarkColor, element) &&
        _cachedDarkWeight == weight) {
      return _cachedDark!;
    }
    _cachedDarkColor = element;
    _cachedDarkWeight = weight;
    return _cachedDark = FlexThemeData.dark(

            colors: color.last,
            usedColors: 1,
            surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
            blendLevel: 2,
            tabBarStyle: FlexTabBarStyle.forAppBar,
            subThemesData: const FlexSubThemesData(
              interactionEffects: true,
              tintedDisabledControls: true,
              blendOnLevel: 10,
              blendOnColors: true,
              useM2StyleDividerInM3: true,
              defaultRadius: 12.0,
              elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
              elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
              outlinedButtonOutlineSchemeColor: SchemeColor.primary,
              toggleButtonsBorderSchemeColor: SchemeColor.primary,
              segmentedButtonSchemeColor: SchemeColor.primary,
              segmentedButtonBorderSchemeColor: SchemeColor.primary,
              unselectedToggleIsColored: true,
              sliderValueTinted: true,
              inputDecoratorSchemeColor: SchemeColor.primary,
              inputDecoratorIsFilled: true,
              inputDecoratorContentPadding: EdgeInsetsDirectional.fromSTEB(
                12,
                16,
                12,
                12,
              ),
              inputDecoratorBackgroundAlpha: 40,
              inputDecoratorBorderSchemeColor: SchemeColor.primary,
              inputDecoratorBorderType: FlexInputBorderType.outline,
              inputDecoratorRadius: 8.0,
              inputDecoratorUnfocusedBorderIsColored: true,
              inputDecoratorBorderWidth: 1.0,
              inputDecoratorFocusedBorderWidth: 2.0,
              inputDecoratorPrefixIconSchemeColor: SchemeColor.primaryFixed,
              inputDecoratorSuffixIconSchemeColor: SchemeColor.primary,
              fabUseShape: true,
              fabAlwaysCircular: true,
              fabSchemeColor: SchemeColor.secondary,
              popupMenuRadius: 8.0,
              popupMenuElevation: 3.0,
              alignedDropdown: true,
              drawerIndicatorRadius: 12.0,
              drawerIndicatorSchemeColor: SchemeColor.primary,
              bottomNavigationBarMutedUnselectedLabel: false,
              bottomNavigationBarMutedUnselectedIcon: false,
              menuRadius: 8.0,
              menuElevation: 3.0,
              menuBarRadius: 0.0,
              menuBarElevation: 2.0,
              menuBarShadowColor: Color(0x00000000),
              searchBarElevation: 1.0,
              searchViewElevation: 1.0,
              searchUseGlobalShape: true,
              navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
              navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
              navigationBarIndicatorSchemeColor: SchemeColor.primary,
              navigationBarIndicatorRadius: 12.0,
              navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
              navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
              navigationRailUseIndicator: true,
              navigationRailIndicatorSchemeColor: SchemeColor.primary,
              navigationRailIndicatorOpacity: 1.00,
              navigationRailIndicatorRadius: 12.0,
              navigationRailBackgroundSchemeColor: SchemeColor.surface,
              navigationRailLabelType: NavigationRailLabelType.all,
            ),
            keyColors: const FlexKeyColors(),
            tones: FlexSchemeVariant.jolly.tones(Brightness.dark),
            visualDensity: FlexColorScheme.comfortablePlatformDensity,
            cupertinoOverrideTheme: const CupertinoThemeData(
              applyThemeToAll: true,
            ),
          ).useSystemChineseFont(Brightness.dark).applyFontWeight(
            fontWeightFromSlider(weight),
          );
  }

  @override
  void initState() {
    super.initState();
    if (supportsHomeWidgetAppGroup) HomeWidget.setAppGroupId(preference.appId);
    //HomeWidget.registerInteractivityCallback(backgroundCallback);

    if (widget.isFirst) {
      loginState = IDSLoginState.manual;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final screenWidth =
          PlatformDispatcher.instance.views.first.physicalSize.width /
          PlatformDispatcher.instance.views.first.devicePixelRatio;
      log.info("Screen width: $screenWidth.");
      if (screenWidth < 480) {
        log.info("Vertical vision mode disabled!");
        // 仅允许正向竖屏：去掉 portraitDown，避免手机倒置时界面 180° 翻转
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final color = appTheme.colorSignal.value;
        final themeMode = appTheme.colorStateSignal.value;
        final fontScale = appTheme.fontScaleSignal.value;
        final i18nDelegate = appTheme.i18nDelegateSignal.value;

        return MaterialApp(
          localizationsDelegates: [
            i18nDelegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('zh', 'TW'),
            Locale('en', 'US'),
          ],
          debugShowCheckedModeBanner: false,
          themeAnimationCurve: Curves.fastOutSlowIn,
          scrollBehavior: MyCustomScrollBehavior(),
          navigatorKey: preference.debuggerKey,
          title: usesXDYouAppTitle ? "XDYou" : 'Traintime PDA',
          theme: _lightTheme(color),
          darkTheme: _darkTheme(color),
          themeMode: themeMode,
          home: LaunchGate(
            child: DefaultTextStyle.merge(
              style: const TextStyle(textBaseline: TextBaseline.ideographic),
              child: widget.isFirst ? const LoginWindow() : const HomePage(),
            ),
          ),
          builder: (context, widget) {
            Catcher2.addDefaultErrorWidget(
              showStacktrace: true,
              title: "Unexpected problem:P",
              description: "An unexpected behaviour occured!",
              maxWidthForSmallMode: 150,
            );
            if (widget != null) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(fontScale)),
                child: widget,
              );
            }
            throw StateError('widget is null');
          },
        );
      },
    );
  }
}

/// 冷启动衔接画面：纯品牌蓝底 + 内容淡入。
///
/// 放在 MaterialApp 的 home 层（内部有 Directionality/Theme），配合 ArkUI
/// 占位画面（同为纯品牌蓝、无文字），实现「蓝色启动画面 → 应用内容淡入」
/// 的衔接。先让品牌蓝底明确停留（避免直接切到内容），再用 AnimatedOpacity
/// 让内容淡入覆盖。用 Timer + AnimatedOpacity（不依赖 AnimationController
/// 的 Ticker 时机，更稳）。
class LaunchGate extends StatefulWidget {
  final Widget child;

  const LaunchGate({super.key, required this.child});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 蓝盖短暂停留（仅防首帧抖动）后开始揭开。内容在首帧已构建就绪，
    // 蓝盖停留不需要等待内容；更短可到 50ms 甚至 0（首帧后立即淡出）。
    _timer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 单层蓝盖淡出：应用内容在底层（不透明、完整渲染），品牌蓝覆盖层在上方。
    // _shown 后蓝色覆盖层淡出（揭开），露出下面完整内容。只有覆盖层一层透明度
    // 在动，内容全程不透明，避免「半透明内容叠在饱和蓝上」产生的脏/闪。
    // 注意：必须 StackFit.expand + 让蓝盖铺满，否则 color Container 在 loose
    // 布局下尺寸坍缩为 0，蓝盖盖不住内容（表现为"没过渡"）。
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: _shown,
          child: AnimatedOpacity(
            opacity: _shown ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFF0089DC),
            ),
          ),
        ),
      ],
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
