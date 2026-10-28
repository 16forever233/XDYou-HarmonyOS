import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const CARD_PREF_NAME = 'xdyou_card';
const CARD_DATA_KEY = 'card_data';
const FORM_IDS_KEY = 'card_form_ids';
const FORM_DIMS_KEY = 'card_form_dims';
/**
 * 卡片端轮询间隔：App 写入新数据 / 课程结束 / 跨天，最多 15s 上屏（进程存活时）。
 *
 * 取 15s（而非 60s）是因为注入/切天后用户会盯着卡片看，等一分钟体感就是"没反应"；
 * 轮询只做「读一个小文件 + 比较签名字符串」，进程通常也只被系统短暂拉起，代价可忽略。
 */
const POLL_INTERVAL_MS = 15000;
/**
 * 「下次刷新」兜底上限（分钟）：App 写入新数据而卡片进程已退出时，
 * 靠 setFormNextRefreshTime 到点唤醒，最长这么久自愈。
 */
const NEXT_REFRESH_FALLBACK_MINUTES = 90;
/** setFormNextRefreshTime 允许的最小值（分钟）。 */
const NEXT_REFRESH_MIN_MINUTES = 5;

interface CardItem {
  type: string;
  name: string;
  teacher: string;
  place: string;
  seat: string;
  startTime: string;
  endTime: string;
  colorIndex: number;
}

interface CardDayData {
  date: string;
  week: string;
  items: CardItem[];
}

interface CardData {
  isLoggedIn: boolean;
  isTomorrow: boolean;
  /** 多天窗口：yyyy-MM-dd → 当天全部日程（未做时间过滤）。 */
  days: Map<string, CardDayData>;
  errorType: string;
  error: string;
  updatedAt: string;
  /** 演示数据（截图模式）：true 时**不按当前时间过滤已结束日程**。 */
  isDemo: boolean;
}

/** 写回 Preferences 的持久化结构（ArkTS 要求对象字面量对应已声明的 interface）。 */
interface CardPayload {
  isLoggedIn: boolean;
  isTomorrow: boolean;
  days: Record<string, CardDayData>;
  errorType: string;
  error: string;
  updatedAt: string;
  isDemo: boolean;
}

/** 传给卡片的 binding data 字段。 */
interface CardBindingFields {
  title: string;
  date: string;
  week: string;
  isLoggedIn: boolean;
  isTomorrow: boolean;
  itemsJson: string;
  errorType: string;
  error: string;
  formDimension: number;
  stale: boolean;
  allFinished: boolean;
}

export default class EntryFormAbility extends FormExtensionAbility {
  /** formId → FormDimension（2=2x2, 3=2x4, 4=4x4），用于卡片内尺寸适配。 */
  private formDimensions: Map<string, number> = new Map();
  /** formId → 上次推送内容签名，用于 60s 轮询时判断是否需要刷新。 */
  private lastPushed: Map<string, string> = new Map();
  private pollTimer: number = -1;

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;
    const dimension = want.parameters?.[formInfo.FormParam.DIMENSION_KEY] as number;
    if (formId !== undefined && formId !== null && formId.length > 0) {
      this.registerFormId(formId);
      if (dimension !== undefined && dimension !== null) {
        this.setDimension(formId, dimension);
      }
    }
    const data = this.loadCardData();
    const fields = this.buildBindingFields(data, formId);
    this.lastPushed.set(formId, JSON.stringify(fields));
    console.info('[EntryFormAbility] onAddForm, isLoggedIn=' + data.isLoggedIn +
      ', days=' + data.days.size + ', dimension=' + dimension);
    this.ensurePoll();
    if (formId !== undefined && formId !== null && formId.length > 0) {
      this.scheduleNextRefresh(formId, data);
    }
    return formBindingData.createFormBindingData(fields);
  }

  onCastToNormalForm(formId: string): void {
    // 临时卡片转常驻卡片时注册 formId，供后续主动推送更新。
    this.registerFormId(formId);
    this.ensurePoll();
  }

  onUpdateForm(formId: string, wantParams?: Record<string, Object>): void {
    // 系统定时刷新（form_config 的 updateDuration，30 分钟）时主动推送最新数据：
    // SDK 要求在该回调里调用 formProvider.updateForm，否则卡片内容不会变化。
    this.registerFormId(formId);
    const dimension = wantParams?.[formInfo.FormParam.DIMENSION_KEY] as number;
    if (dimension !== undefined && dimension !== null) {
      this.setDimension(formId, dimension);
    }
    this.pushToForm(formId, this.loadCardData());
    this.ensurePoll();
  }

  onSizeChanged(formId: string, newDimension: formInfo.FormDimension, newRect: formInfo.Rect): void {
    // 用户拖拽调整卡片尺寸（form_config 的 resizable）后按新尺寸重排内容。
    this.setDimension(formId, newDimension as number);
    this.pushToForm(formId, this.loadCardData());
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    // formVisibleNotify 仅对系统应用生效，这里保留空实现。
  }

  onFormEvent(formId: string, message: string): void {
    console.info('[EntryFormAbility] onFormEvent, formId=' + formId + ', message=' + message);
    this.registerFormId(formId);
    // 注意：postCardAction 的 message 动作会把整个 params JSON 字符串传给 onFormEvent，
    // 形如 {"message":"toggle_day","params":{...},"action":"message"}，需要解析后判断。
    let msg = message;
    try {
      const obj = JSON.parse(message) as Record<string, Object>;
      if (typeof obj['message'] === 'string') {
        msg = obj['message'] as string;
      }
    } catch (e) {
      // message 不是 JSON 时按原始字符串处理。
    }
    if (msg === 'toggle_day') {
      // 读改写用同一个实例，避免两次取实例之间被 App 侧的新数据覆盖。
      const pref = this.pref();
      const data = this.loadCardData(pref);
      data.isTomorrow = !data.isTomorrow;
      this.saveCardData(data, pref);
      this.pushToForm(formId, data);
    }
  }

  onRemoveForm(formId: string): void {
    // 卡片删除时从注册列表移除。
    this.unregisterFormId(formId);
    if (this.loadFormIds().length === 0) {
      this.stopPoll();
    }
  }

  onStop(): void {
    // 卡片提供方进程退出前清理定时器。
    this.stopPoll();
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  // ---------------------------------------------------------------- 轮询推送

  /**
   * App（UIAbility）与卡片在同一进程，但**不能在 UIAbility 侧调用 updateForm**
   * （实测 THREAD_BLOCK_6S 闪退）。改为在卡片侧轮询：把「当前应该显示的内容」
   * 算出来与上次推送比对，不同才 updateForm。这样以下变化都能在 60s 内上屏：
   * ① App 写入新数据；② 有课程刚结束（条目被过滤）；③ 跨天；④ 登录态/错误变化。
   */
  private ensurePoll(): void {
    if (this.pollTimer !== -1) {
      return;
    }
    this.pollTimer = setInterval(() => {
      this.pollAndPush();
    }, POLL_INTERVAL_MS);
  }

  private stopPoll(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  /**
   * 从系统查询「本应用已添加到桌面的卡片」，补齐本地 formId 登记。
   *
   * 背景：onAddForm 里的 `FormParam.IDENTITY_KEY` 未必总能拿到，而进程被系统重启后
   * 内存里的登记也会丢；查不到 formId 就没法主动推送（轮询/到点刷新都会哑掉）。
   */
  private recoverFormIds(): Promise<number> {
    return formProvider.getPublishedRunningFormInfos().then((infos: formInfo.RunningFormInfo[]) => {
      let count = 0;
      infos.forEach((info: formInfo.RunningFormInfo) => {
        if (info.formId !== undefined && info.formId !== null && info.formId.length > 0) {
          this.registerFormId(info.formId);
          count++;
        }
      });
      return count;
    });
  }

  private pollAndPush(): void {
    const ids = this.loadFormIds();
    if (ids.length === 0) {
      // 本进程还没登记过 formId（例如进程被系统重启后）：向系统查一次本应用已添加的卡片，
      // 查到就登记，查不到（用户没加卡片）就停表，避免空转。
      this.recoverFormIds().then((found: number) => {
        if (found === 0) {
          this.stopPoll();
        } else {
          console.info('[EntryFormAbility] recovered ' + found + ' formId(s) from system');
        }
      }).catch((err: BusinessError) => {
        console.error('[EntryFormAbility] recoverFormIds failed: ' + JSON.stringify(err));
        this.stopPoll();
      });
      return;
    }
    const data = this.loadCardData();
    ids.forEach((formId: string) => {
      const fields = this.buildBindingFields(data, formId);
      const signature = JSON.stringify(fields);
      if (this.lastPushed.get(formId) !== signature) {
        this.lastPushed.set(formId, signature);
        formProvider.updateForm(formId, formBindingData.createFormBindingData(fields))
          .then(() => {
            console.info('[EntryFormAbility] poll updateForm ok, formId=' + formId +
              ', items=' + EntryFormAbility.countItems(fields) +
              ', isTomorrow=' + data.isTomorrow);
            this.scheduleNextRefresh(formId, data);
          })
          .catch((err: BusinessError) => {
            console.error('[EntryFormAbility] poll updateForm failed, formId=' + formId +
              ', err=' + JSON.stringify(err));
          });
      }
    });
  }

  // ------------------------------------------------- 到点自刷新（下次刷新）

  /**
   * 计算「卡片下一次内容会变化的时刻」并交给系统到点唤醒（`setFormNextRefreshTime`）：
   * - 显示今日时：最近一条尚未结束日程的结束时间（到点该条会消失）；
   * - 跨天：次日 00:01（换天，今日/明日数据都会变）；
   * - 兜底：最长 {@link NEXT_REFRESH_FALLBACK_MINUTES} 分钟一次，
   *   这样即使卡片进程已退出、App 又写了新数据，也能自行恢复。
   *
   * 配额：每张卡片每天最多 50 次定时/下次刷新（0 点重置），
   * 本项目按"课程结束 + 跨天 + 90 分钟兜底"算，典型一天 ~20 次，安全。
   */
  private scheduleNextRefresh(formId: string, data: CardData): void {
    const minutes = this.minutesUntilNextChange(data);
    formProvider.setFormNextRefreshTime(formId, minutes).then(() => {
      console.info('[EntryFormAbility] next refresh in ' + minutes + ' min, formId=' + formId);
    }).catch((err: BusinessError) => {
      // 配额用尽（每天 50 次）等情况下会失败，只记录不影响卡片显示。
      console.error('[EntryFormAbility] setFormNextRefreshTime failed, formId=' + formId +
        ', err=' + JSON.stringify(err));
    });
  }

  private minutesUntilNextChange(data: CardData): number {
    const now = new Date();
    const nowMs = now.getTime();
    const today = EntryFormAbility.deviceToday();
    const target = data.isTomorrow ? EntryFormAbility.plusDays(today, 1) : today;

    // 跨天（次日 00:01）作为候选之一。
    let next = Math.ceil(
      (new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 1, 0).getTime() - nowMs) / 60000);
    if (next < NEXT_REFRESH_MIN_MINUTES) {
      next = NEXT_REFRESH_MIN_MINUTES;
    }

    const day: CardDayData | undefined = data.days.get(target);
    if (day !== undefined && target === today) {
      // 显示今日时：最近一条未结束日程的结束时间（+1 分钟错开边界）。
      day.items.forEach((item: CardItem) => {
        const end = EntryFormAbility.todayTimeToDate(item.endTime);
        if (end !== undefined && end.getTime() > nowMs) {
          const delta = Math.ceil((end.getTime() - nowMs) / 60000) + 1;
          if (delta < next) {
            next = delta;
          }
        }
      });
    }

    if (next < NEXT_REFRESH_MIN_MINUTES) {
      next = NEXT_REFRESH_MIN_MINUTES;
    }
    if (next > NEXT_REFRESH_FALLBACK_MINUTES) {
      next = NEXT_REFRESH_FALLBACK_MINUTES;
    }
    return next;
  }

  // ---------------------------------------------------------------- 数据读写

  /**
   * 取 Preferences 实例（**每次都强制重新读持久化文件**）。
   *
   * 这是本模块最容易踩的坑：Preferences 实例是**进程内缓存**的 —— 第一次
   * `getPreferencesSync` 之后，后续调用直接返回缓存实例，**不会重新读文件**
   * （见 `@ohos.data.preferences.d.ts` 对 `removePreferencesFromCacheSync` 的说明：
   * "the Preferences instance will be read from the cache instead of from the
   * persistent file. After this API is called to remove the instance from the cache,
   * calling getPreferences again will read data from the persistent file"）。
   *
   * 而 App 与卡片分属两个进程（UIAbility / FormExtension），App 写在文件里的新数据
   * 在卡片进程里因此**永远读不到** —— 表现就是"App 明明写了，卡片死活不更新"、
   * "必须手动点今日/明日才刷新"。所以每次读写前先移除缓存实例，强制从文件读。
   *
   * 注意：取到的实例用完即弃、不再复用（官方要求被移除缓存的实例不要再操作）。
   */
  private pref(): preferences.Preferences {
    const appCtx = this.context.getApplicationContext();
    try {
      preferences.removePreferencesFromCacheSync(appCtx, { name: CARD_PREF_NAME });
    } catch (e) {
      console.error('[EntryFormAbility] removePreferencesFromCache failed: ' + JSON.stringify(e));
    }
    return preferences.getPreferencesSync(appCtx, { name: CARD_PREF_NAME });
  }

  private loadCardData(pref?: preferences.Preferences): CardData {
    try {
      // 注意：必须用 getApplicationContext()（应用级共享目录）读写，
      // ExtensionAbility 自身沙箱（.../base/extension/EntryFormAbility/）与
      // UIAbility 沙箱（.../base/）相互隔离，直接读 this.context 读不到主应用写入的数据。
      const target = pref !== undefined ? pref : this.pref();
      const raw = target.getSync(CARD_DATA_KEY, '') as string;
      if (!raw) {
        console.info('[EntryFormAbility] loadCardData: empty, use default');
        return this.emptyCardData();
      }
      const obj = JSON.parse(raw) as Record<string, Object>;
      return {
        isLoggedIn: (obj['isLoggedIn'] as boolean) ?? false,
        isTomorrow: (obj['isTomorrow'] as boolean) ?? false,
        days: this.parseDays(obj),
        errorType: (obj['errorType'] as string) ?? '',
        error: (obj['error'] as string) ?? '',
        updatedAt: (obj['updatedAt'] as string) ?? '',
        isDemo: (obj['isDemo'] as boolean) ?? false,
      };
    } catch (e) {
      console.error('[EntryFormAbility] loadCardData failed: ' + JSON.stringify(e));
      return this.emptyCardData();
    }
  }

  private emptyCardData(): CardData {
    return {
      isLoggedIn: false,
      isTomorrow: false,
      days: new Map<string, CardDayData>(),
      errorType: '',
      error: '',
      updatedAt: '',
      isDemo: false,
    };
  }

  /** 解析多天窗口；旧格式（只有 today/tomorrow）时回退兼容。 */
  private parseDays(obj: Record<string, Object>): Map<string, CardDayData> {
    const days = new Map<string, CardDayData>();
    const rawDays = obj['days'] as Record<string, Object>;
    if (rawDays !== undefined && rawDays !== null) {
      Object.keys(rawDays).forEach((key: string) => {
        const day = this.parseDay(rawDays[key] as Record<string, Object>);
        if (day !== undefined) {
          days.set(key, day);
        }
      });
    }
    if (days.size === 0) {
      // 兼容旧格式：today/tomorrow 各自带 isoDate。
      const todayObj = obj['today'] as Record<string, Object>;
      const today = this.parseDay(todayObj);
      const todayIso = this.dayIso(todayObj);
      if (today !== undefined && todayIso.length > 0) {
        days.set(todayIso, today);
      }
      const tomorrowObj = obj['tomorrow'] as Record<string, Object>;
      const tomorrow = this.parseDay(tomorrowObj);
      const tomorrowIso = this.dayIso(tomorrowObj);
      if (tomorrow !== undefined && tomorrowIso.length > 0) {
        days.set(tomorrowIso, tomorrow);
      }
    }
    return days;
  }

  private dayIso(obj: Record<string, Object>): string {
    if (obj === undefined || obj === null) {
      return '';
    }
    return (obj['isoDate'] as string) ?? '';
  }

  private parseDay(obj: Record<string, Object>): CardDayData | undefined {
    if (obj === undefined || obj === null) {
      return undefined;
    }
    const items = (obj['items'] as CardItem[] ?? []) as CardItem[];
    return {
      date: (obj['date'] as string) ?? '',
      week: (obj['week'] as string) ?? '',
      items: items,
    };
  }

  private saveCardData(data: CardData, pref?: preferences.Preferences): void {
    try {
      const target = pref !== undefined ? pref : this.pref();
      const days: Record<string, CardDayData> = {};
      data.days.forEach((value: CardDayData, key: string) => {
        days[key] = value;
      });
      const payload: CardPayload = {
        isLoggedIn: data.isLoggedIn,
        isTomorrow: data.isTomorrow,
        days: days,
        errorType: data.errorType,
        error: data.error,
        updatedAt: data.updatedAt,
      isDemo: data.isDemo
      };
      target.putSync(CARD_DATA_KEY, JSON.stringify(payload));
      target.flushSync();
      console.info('[EntryFormAbility] saveCardData ok, isTomorrow=' + data.isTomorrow);
    } catch (e) {
      console.error('[EntryFormAbility] saveCardData failed: ' + JSON.stringify(e));
    }
  }

  // ------------------------------------------------------------ binding data

  /**
   * 组装卡片要显示的字段：按设备日期从窗口里取「今天/明天」，
   * 并在显示的是今天时过滤掉已结束的日程（时间跑动无需 App 参与）。
   */
  private buildBindingFields(data: CardData, formId: string): CardBindingFields {
    const today = EntryFormAbility.deviceToday();
    const target = data.isTomorrow ? EntryFormAbility.plusDays(today, 1) : today;
    const day: CardDayData | undefined = data.days.get(target);
    const stale = day === undefined;

    let items: CardItem[] = [];
    let date = '';
    let week = '';
    if (day !== undefined) {
      date = day.date;
      week = day.week;
      items = day.items;
    }

    let allFinished = false;
    // 演示数据（截图模式）：不按当前时间过滤，保证拍宣传图时卡片是满的
    if (!data.isDemo && day !== undefined && target === today) {
      const nowHm = EntryFormAbility.deviceHourMinute();
      const total = items.length;
      items = items.filter((item: CardItem) => item.endTime > nowHm);
      allFinished = total > 0 && items.length === 0;
    }

    return {
      title: data.isTomorrow ? '明日课表' : '今日课表',
      date: date,
      week: week,
      isLoggedIn: data.isLoggedIn,
      isTomorrow: data.isTomorrow,
      itemsJson: JSON.stringify(items),
      errorType: data.errorType,
      error: data.error,
      formDimension: this.getDimension(formId),
      stale: stale,
      allFinished: allFinished
    };
  }

  /** 推送内容里的日程条数（hilog 诊断用：一眼看出「数据到底进没进卡片」）。 */
  private static countItems(fields: CardBindingFields): number {
    try {
      return (JSON.parse(fields.itemsJson) as CardItem[]).length;
    } catch (e) {
      return -1;
    }
  }

  private pushToForm(formId: string, data: CardData): void {
    const fields = this.buildBindingFields(data, formId);
    this.lastPushed.set(formId, JSON.stringify(fields));
    formProvider.updateForm(formId, formBindingData.createFormBindingData(fields)).then(() => {
      console.info('[EntryFormAbility] updateForm ok, formId=' + formId +
        ', isTomorrow=' + data.isTomorrow +
        ', items=' + EntryFormAbility.countItems(fields) +
        ', stale=' + fields.stale + ', loggedIn=' + fields.isLoggedIn);
      this.scheduleNextRefresh(formId, data);
    }).catch((err: BusinessError) => {
      console.error('[EntryFormAbility] updateForm failed, formId=' + formId +
        ', err=' + JSON.stringify(err));
    });
  }

  // ------------------------------------------------------------ formId 登记

  private loadFormIds(): string[] {
    try {
      const pref = this.pref();
      const raw = pref.getSync(FORM_IDS_KEY, '[]') as string;
      try {
        return JSON.parse(raw) as string[];
      } catch (e) {
        return [];
      }
    } catch (e) {
      console.error('[EntryFormAbility] loadFormIds failed: ' + JSON.stringify(e));
      return [];
    }
  }

  private registerFormId(formId: string): void {
    if (formId === undefined || formId === null || formId.length === 0) {
      return;
    }
    try {
      const list = this.loadFormIds();
      if (!list.includes(formId)) {
        list.push(formId);
        // 写实例最后取：避免用到已被移出缓存的实例（官方要求）。
        const pref = this.pref();
        pref.putSync(FORM_IDS_KEY, JSON.stringify(list));
        pref.flushSync();
        console.info('[EntryFormAbility] registerFormId ok, total=' + list.length);
      }
    } catch (e) {
      console.error('[EntryFormAbility] registerFormId failed: ' + JSON.stringify(e));
    }
  }

  private unregisterFormId(formId: string): void {
    try {
      const list = this.loadFormIds().filter((id: string) => id !== formId);
      const pref = this.pref();
      pref.putSync(FORM_IDS_KEY, JSON.stringify(list));
      pref.flushSync();
      this.formDimensions.delete(formId);
      this.lastPushed.delete(formId);
      console.info('[EntryFormAbility] unregisterFormId ok, total=' + list.length);
    } catch (e) {
      console.error('[EntryFormAbility] unregisterFormId failed: ' + JSON.stringify(e));
    }
  }

  // ------------------------------------------------------------ 尺寸登记

  private getDimension(formId: string): number {
    if (formId === undefined || formId === null || formId.length === 0) {
      return formInfo.FormDimension.Dimension_2_2 as number;
    }
    const cached = this.formDimensions.get(formId);
    if (cached !== undefined) {
      return cached;
    }
    try {
      const pref = this.pref();
      const raw = pref.getSync(FORM_DIMS_KEY, '{}') as string;
      const obj = JSON.parse(raw) as Record<string, number>;
      const dim = obj[formId];
      if (dim !== undefined && dim !== null) {
        this.formDimensions.set(formId, dim);
        return dim;
      }
    } catch (e) {
      console.error('[EntryFormAbility] getDimension failed: ' + JSON.stringify(e));
    }
    return formInfo.FormDimension.Dimension_2_2 as number;
  }

  private setDimension(formId: string, dimension: number): void {
    if (formId === undefined || formId === null || formId.length === 0) {
      return;
    }
    this.formDimensions.set(formId, dimension);
    try {
      // 同一个实例里读改写，避免中间被其它进程的数据覆盖。
      const pref = this.pref();
      const raw = pref.getSync(FORM_DIMS_KEY, '{}') as string;
      let obj: Record<string, number> = {};
      try {
        obj = JSON.parse(raw) as Record<string, number>;
      } catch (e) {
        obj = {};
      }
      obj[formId] = dimension;
      pref.putSync(FORM_DIMS_KEY, JSON.stringify(obj));
      pref.flushSync();
    } catch (e) {
      console.error('[EntryFormAbility] setDimension failed: ' + JSON.stringify(e));
    }
  }

  // ------------------------------------------------------------ 时间工具

  private static deviceToday(): string {
    return EntryFormAbility.formatIsoDate(new Date());
  }

  /** 当前时间 HH:mm，用于过滤已结束日程（"HH:mm" 字符串可直接比较）。 */
  private static deviceHourMinute(): string {
    const now = new Date();
    const hour = now.getHours();
    const minute = now.getMinutes();
    return (hour < 10 ? '0' : '') + hour.toString() + ':' +
      (minute < 10 ? '0' : '') + minute.toString();
  }

  private static plusDays(isoDate: string, days: number): string {
    const parsed = new Date(isoDate + 'T00:00:00');
    parsed.setDate(parsed.getDate() + days);
    return EntryFormAbility.formatIsoDate(parsed);
  }

  /** 把 "HH:mm" 解析成今天的该时刻；格式非法返回 undefined。 */
  private static todayTimeToDate(hhmm: string): Date | undefined {
    const parts = hhmm.split(':');
    if (parts.length !== 2) {
      return undefined;
    }
    const hour = Number.parseInt(parts[0], 10);
    const minute = Number.parseInt(parts[1], 10);
    if (Number.isNaN(hour) || Number.isNaN(minute)) {
      return undefined;
    }
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0);
  }

  private static formatIsoDate(d: Date): string {
    const month = d.getMonth() + 1;
    const day = d.getDate();
    return d.getFullYear().toString() + '-' +
      (month < 10 ? '0' : '') + month.toString() + '-' +
      (day < 10 ? '0' : '') + day.toString();
  }
}
