
import { FlutterAbility, FlutterEngine, MethodChannel, MethodCall, MethodResult, StandardMethodCodec, StandardMessageCodec, FlutterEnginePreload } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { registerCharsetConverterChannel } from '../plugins/CharsetConverterPlugin';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { bundleManager, common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { updateManager, privacyManager } from '@kit.AppGalleryKit';
import window from '@ohos.window';

/** Scan Kit：用户取消扫码时返回的错误码（@since 12）。 */
const SCAN_USER_CANCEL = 1000500002;

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    this.registerNativeScanChannel(flutterEngine)
    this.registerDesktopCardChannel(flutterEngine)
    this.registerAppUpdateChannel(flutterEngine)
    this.registerAppInfoChannel(flutterEngine)
    // `charset_converter` 插件没有 ohos 实现（其 pubspec 只声明了 android/ios/windows/linux），
    // 缺了它物理实验与实验报告会一直报 MissingPluginException。这里在应用侧补齐同名通道。
    registerCharsetConverterChannel(flutterEngine)
  }

  /**
   * 应用信息通道：目前只用来判断当前安装包是不是「调试签名」。
   * Dart 侧据此决定是否显示调试入口（测试包显示、应用市场正式包自动隐藏）。
   */
  private registerAppInfoChannel(flutterEngine: FlutterEngine) {
    const channel = new MethodChannel(
      flutterEngine.getDartExecutor().getBinaryMessenger(),
      'xdyou/app_info',
      new StandardMethodCodec(new StandardMessageCodec()),
    )
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        if (call.method === 'isDebugProvisioned') {
          try {
            const info = bundleManager.getBundleInfoForSelfSync(
              bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
            const provisionType = info.appInfo.appProvisionType;  // 'debug' | 'release'
            console.info('[EntryAbility] appProvisionType=' + provisionType);
            result.success(provisionType === 'debug');
          } catch (err) {
            console.error('[EntryAbility] read appProvisionType failed: ' + JSON.stringify(err));
            result.success(false);
          }
        } else if (call.method === 'sdkApiVersion') {
          // 设备实际 API 等级（@ohos.deviceInfo.sdkApiVersion，@since 6）。
          // 用于按设备能力决定「代理提醒」的调度上限：API 26+ 配额 64，API ≤25 为 30。
          // 注意读的是**设备**版本而不是应用的 targetSdkVersion（老设备装新包时两者不同）。
          try {
            const api = deviceInfo.sdkApiVersion;
            console.info('[EntryAbility] device sdkApiVersion=' + api);
            result.success(api);
          } catch (err) {
            console.error('[EntryAbility] read sdkApiVersion failed: ' + JSON.stringify(err));
            result.success(0);
          }
        } else {
          result.notImplemented();
        }
      }
    })
  }

  /**
   * 冷启动黑屏/白屏缓解：flutter_ohos 的 FlutterPage 在首个可上屏帧到达前
   * XComponent 保持透明，露出的就是窗口背景（系统默认白色）——这会让
   * 「首帧延迟/丢失」的冷启动表现为白屏。把窗口背景设为品牌蓝，与
   * startWindowBackground 一致，首帧到达前的观感从白屏变为启动色过渡。
   *
   * 注意：必须在窗口就绪（SHOWN 事件）后再设置——onWindowStageCreate
   * 阶段 loadContent 尚未完成，直接调用会失败（1300002，实测一直失败）。
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 启动画面期间预热 Flutter 引擎（FlutterLoader 初始化 + native 引擎创建，
    // 这是 debug 冷启动首帧 1~2s 空窗的主要耗时）。预热完成后再 loadContent，
    // Flutter 首帧立即可上屏，实现「启动画面 → Flutter UI」直接衔接。
    // 带超时兜底：预热异常卡住时 5s 后无论如何继续加载，避免窗口永不显示。
    let proceedCalled = false;
    const proceed = () => {
      if (proceedCalled) {
        return;
      }
      proceedCalled = true;
      super.onWindowStageCreate(windowStage);
      // 窗口背景品牌蓝兜底：首帧前 XComponent 透明，露出窗口背景；
      // 预热未覆盖的剩余空窗期也显示启动色（需窗口 SHOWN 后再设置，见 applyBrandColor）。
      const applyBrandColor = () => {
        try {
          windowStage.getMainWindowSync().setWindowBackgroundColor('#0089DC');
          console.info('[EntryAbility] setWindowBackgroundColor ok');
        } catch (e) {
          console.error('[EntryAbility] setWindowBackgroundColor failed: ' + JSON.stringify(e));
          setTimeout(() => {
            try {
              windowStage.getMainWindowSync().setWindowBackgroundColor('#0089DC');
              console.info('[EntryAbility] setWindowBackgroundColor ok (retry)');
            } catch (e2) {
              console.error('[EntryAbility] setWindowBackgroundColor failed (retry): ' + JSON.stringify(e2));
            }
          }, 500);
        }
      };
      try {
        windowStage.on('windowStageEvent', (data: window.WindowStageEventType) => {
          if (data === window.WindowStageEventType.SHOWN) {
            applyBrandColor();
          }
        });
      } catch (e) {
        console.error('[EntryAbility] register windowStageEvent failed: ' + JSON.stringify(e));
        applyBrandColor();
      }
    };

    FlutterEnginePreload.preloadEngine(this.context).then(() => {
      console.info('[EntryAbility] engine preloaded, proceed');
      proceed();
    }).catch((e: BusinessError) => {
      console.error('[EntryAbility] preloadEngine failed: ' + JSON.stringify(e));
      proceed();
    });
    setTimeout(() => {
      console.warn('[EntryAbility] preloadEngine timeout, proceed');
      proceed();
    }, 5000);
  }

  /**
   * 鸿蒙原生扫码（Scan Kit 默认界面扫码），供 Dart 侧水机/空调等场景调用。
   * 系统级接口：默认界面扫码直接调用即可，无需 AGC 配置
   * （相机权限已由系统预授权；AGC/App Linking 仅「扫码直达」场景必选）。
   */
  private registerNativeScanChannel(flutterEngine: FlutterEngine) {
    const channel = new MethodChannel(
      flutterEngine.getDartExecutor().getBinaryMessenger(),
      'xdyou/native_scan',
      new StandardMethodCodec(new StandardMessageCodec()),
    )
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        if (call.method === 'startScan') {
          const options: scanBarcode.ScanOptions = {
            scanTypes: [scanCore.ScanType.ALL],
            enableMultiMode: true,
            enableAlbum: false,
          }
          scanBarcode.startScanForResult(this.context, options)
            .then((res: scanBarcode.ScanResult) => {
              result.success(res.originalValue)
            })
            .catch((err: BusinessError) => {
              if (err.code === SCAN_USER_CANCEL) {
                // 用户取消/返回扫码界面：按“无结果”返回，
                // Dart 侧不会回退到应用内扫码（该界面在鸿蒙端已不再使用）。
                console.info('[EntryAbility] scan canceled by user');
                result.success(null);
              } else {
                console.error('[EntryAbility] scan failed: ' + JSON.stringify(err));
                result.error(String(err.code), err.message, null);
              }
            })
        } else {
          result.notImplemented()
        }
      }
    })
  }

  /**
   * 桌面卡片数据桥：Dart 侧把卡片要显示的 JSON 写入 Preferences，
   * FormExtensionAbility 在 onAddForm/onUpdateForm 时读取并展示。
   */
  private registerDesktopCardChannel(flutterEngine: FlutterEngine) {    const channel = new MethodChannel(
      flutterEngine.getDartExecutor().getBinaryMessenger(),
      'xdyou/desktop_card',
      new StandardMethodCodec(new StandardMessageCodec()),
    )
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        if (call.method === 'saveCardData') {
          const data = call.args as string;
          try {
            // 必须与卡片侧（EntryFormAbility）使用同一 context 类型读写：
            // getApplicationContext() → /data/storage/el2/base/preferences
            // （UIAbilityContext 的 this.context 带 haps/entry 层级，与卡片侧不一致）
            const appCtx = this.context.getApplicationContext();
            console.info('[EntryAbility] saveCardData, appCtxDir=' + appCtx.preferencesDir +
              ', dataLen=' + data.length);
            const pref = this.cardPref(appCtx);
            pref.putSync('card_data', data);
            pref.flushSync();
            result.success(true);
            console.info('[EntryAbility] saveCardData ok');
            // 数据写好后立即让桌面卡片刷新：用 reloadAllForms（主进程通知
            // FormExtension 进程批量刷新，异步、不会重入阻塞）。
            // 注意：**不要**直接在这里同步调 formProvider.updateForm ——
            // 同一进程内重入会触发 THREAD_BLOCK_6S 被系统杀掉（历史实测）。
            this.requestCardReload();
          } catch (e) {
            console.error('[EntryAbility] saveCardData failed: ' + JSON.stringify(e));
            result.error('save_card_failed', JSON.stringify(e), null);
          }
        } else if (call.method === 'getCardData') {
          // 供 Dart 侧同步前读回卡片当前 isTomorrow 等状态，避免覆盖卡片上的切换。
          try {
            const appCtx = this.context.getApplicationContext();
            const pref = this.cardPref(appCtx);
            const raw = pref.getSync('card_data', '') as string;
            result.success(raw);
          } catch (e) {
            console.error('[EntryAbility] getCardData failed: ' + JSON.stringify(e));
            result.error('get_card_failed', JSON.stringify(e), null);
          }
        } else if (call.method === 'refreshNow') {
          // 主动让桌面卡片立即刷新（调试入口/后续功能用）。
          this.requestCardReload();
          result.success(true);
        } else {
          result.notImplemented()
        }
      }
    })
  }

  /**
   * 取卡片数据用的 Preferences 实例（**强制重新读文件**）。
   *
   * Preferences 实例是进程内缓存的：第一次 getPreferencesSync 之后，后续调用只读缓存、
   * 不再读持久化文件（见 `@ohos.data.preferences.d.ts` 的
   * `removePreferencesFromCacheSync` 说明）。卡片侧的「今日/明日」切换是 FormExtension
   * **另一个进程**写进同一个文件的，不先移除缓存的话 App 读到的永远是旧值，
   * 下一次 saveCardData 就把用户在卡片上的切换覆盖掉了。
   */
  private cardPref(appCtx: common.Context): preferences.Preferences {
    try {
      preferences.removePreferencesFromCacheSync(appCtx, { name: 'xdyou_card' });
    } catch (e) {
      console.error('[EntryAbility] removePreferencesFromCache failed: ' + JSON.stringify(e));
    }
    return preferences.getPreferencesSync(appCtx, { name: 'xdyou_card' });
  }

  /**
   * 让本应用所有桌面卡片立即刷新。
   *
   * 用 `formProvider.reloadAllForms`（@since 22）：**在主进程调用，通知 FormExtension
   * 进程批量刷新**——是异步通知，不会像直接在 UIAbility 里调 `updateForm` 那样重入阻塞
   * （历史 THREAD_BLOCK_6S 就是那么来的）。
   * 延后到事件队列执行，避免占用 MethodCall 回调栈；API < 22 的设备没有该接口，忽略即可
   * （此时靠卡片侧 60s 轮询 + setFormNextRefreshTime 到点刷新兜底）。
   */
  private requestCardReload(): void {
    setTimeout(() => {
      try {
        formProvider.reloadAllForms(this.context)
          .then((count: number) => {
            console.info('[EntryAbility] reloadAllForms ok, count=' + count);
          })
          .catch((err: BusinessError) => {
            console.error('[EntryAbility] reloadAllForms failed: ' + JSON.stringify(err));
          });
      } catch (e) {
        console.error('[EntryAbility] reloadAllForms unsupported: ' + JSON.stringify(e));
      }
    }, 0);
  }

  /**
   * 应用市场更新检测/弹窗：使用 AppGalleryKit 的 updateManager。
   * Dart 侧通过 MethodChannel 调用，避免在 Flutter 层直接依赖 HMS API。
   *
   * **失败不能静默**：原先 `showUpdateDialog` 只把 BusinessError 交给 Dart，而 Dart 侧
   * 忽略了返回值 —— 用户点「检查更新」就是"完全没反应"。现在两个方法都把
   * **结果码 + 错误码 + 错误信息**放进返回的 map（不再用 result.error 抛出去），
   * 由 Dart 侧据此提示具体原因。常见错误码：
   * 1009400001 SA 连接失败 / 1009400002 服务请求失败 / 1009400003 网络异常 /
   * 1009400004 应用不在前台 / 1009400005 **未同意华为隐私协议** /
   * 1009400006 操作过于频繁 / 1009400007 其它错误。
   */
  private registerAppUpdateChannel(flutterEngine: FlutterEngine) {
    const channel = new MethodChannel(
      flutterEngine.getDartExecutor().getBinaryMessenger(),
      'xdyou/app_update',
      new StandardMethodCodec(new StandardMessageCodec()),
    )
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        if (call.method === 'checkAppUpdate') {
          updateManager.checkAppUpdate(this.context)
            .then((res) => {
              console.info('[EntryAbility] checkAppUpdate ok, updateAvailable=' + res.updateAvailable);
              result.success({
                updateAvailable: res.updateAvailable,
                versionName: res.versionName ?? '',
                versionCode: res.versionCode ?? 0,
                errorCode: 0,
                errorMessage: '',
              });
            })
            .catch((err: BusinessError) => {
              // 不抛给 Dart：把错误码放进结果，界面才能告诉用户"为什么没反应"。
              console.error('[EntryAbility] checkAppUpdate failed, code=' + err.code +
                ', msg=' + err.message);
              result.success({
                updateAvailable: 0,
                versionName: '',
                versionCode: 0,
                errorCode: err.code,
                errorMessage: err.message ?? '',
              });
            });
        } else if (call.method === 'showUpdateDialog') {
          updateManager.showUpdateDialog(this.context)
            .then((res) => {
              console.info('[EntryAbility] showUpdateDialog resultCode=' + res);
              result.success({
                resultCode: res,
                errorCode: 0,
                errorMessage: '',
              });
            })
            .catch((err: BusinessError) => {
              console.error('[EntryAbility] showUpdateDialog failed, code=' + err.code +
                ', msg=' + err.message);
              result.success({
                resultCode: 1,
                errorCode: err.code,
                errorMessage: err.message ?? '',
              });
            });
        } else if (call.method === 'privacyStatus') {
          // AppGalleryKit 隐私合规状态。
          //
          // 为什么需要它：updateManager.checkAppUpdate 在「未同意隐私协议」时会直接报
          // **1009400005**，必须先走 privacyManager 的标准化隐私弹框征得同意；
          // 而 privacyManager 又要求应用在 AGC（AppGallery Connect）配置好隐私政策
          // （自定义隐私政策网址 或 隐私声明托管服务），否则 getAppPrivacyMgmtInfo
          // 会抛 **1006700003**（应用未使用隐私管理服务）。
          try {
            const mgmtInfo = privacyManager.getAppPrivacyMgmtInfo();
            const results = privacyManager.getAppPrivacyResult();
            let agreed = false;
            let requiresResign = false;
            results.forEach((item: privacyManager.AppPrivacyResult) => {
              if (item.result === privacyManager.AppPrivacyResultType.FULL_MODE_AGREED) {
                agreed = true;
              }
              if (item.result ===
                privacyManager.AppPrivacyResultType.REQUIRE_RESIGNING_VERSION_UPDATE) {
                requiresResign = true;
              }
            });
            console.info('[EntryAbility] privacyStatus mgmtType=' + mgmtInfo.type +
              ', results=' + results.length + ', agreed=' + agreed +
              ', requiresResign=' + requiresResign);
            result.success({
              supported: mgmtInfo.type === privacyManager.AppPrivacyMgmtType.FULL_MODE,
              agreed: agreed && !requiresResign,
              requiresResign: requiresResign,
              errorCode: 0,
              errorMessage: '',
            });
          } catch (err) {
            const e = err as BusinessError;
            console.error('[EntryAbility] privacyStatus failed, code=' + e.code +
              ', msg=' + e.message);
            result.success({
              supported: false,
              agreed: false,
              requiresResign: false,
              errorCode: e.code,
              errorMessage: e.message ?? '',
            });
          }
        } else if (call.method === 'requestPrivacyConsent') {
          // 拉起华为标准化的隐私弹框征求同意（弹框由系统绘制，无需自己实现 UI）。
          privacyManager.requestAppPrivacyConsent(this.context)
            .then((res: privacyManager.ConsentResult) => {
              let agreed = false;
              res.results.forEach((item: privacyManager.AppPrivacyResult) => {
                if (item.result === privacyManager.AppPrivacyResultType.FULL_MODE_AGREED) {
                  agreed = true;
                }
              });
              console.info('[EntryAbility] requestAppPrivacyConsent ok, agreed=' + agreed);
              result.success({
                supported: true,
                agreed: agreed,
                requiresResign: false,
                errorCode: 0,
                errorMessage: '',
              });
            })
            .catch((err: BusinessError) => {
              console.error('[EntryAbility] requestAppPrivacyConsent failed, code=' + err.code +
                ', msg=' + err.message);
              result.success({
                supported: false,
                agreed: false,
                requiresResign: false,
                errorCode: err.code,
                errorMessage: err.message ?? '',
              });
            });
        } else {
          result.notImplemented();
        }
      }
    })
  }

}
