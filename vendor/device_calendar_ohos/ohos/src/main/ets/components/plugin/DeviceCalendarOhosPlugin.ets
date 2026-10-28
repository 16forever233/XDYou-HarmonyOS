/**
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * */

import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  Log,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';

import { calendarManager } from '@kit.CalendarKit'
import {
  abilityAccessCtrl,
  common,
  PermissionRequestResult,
  Permissions,
  bundleManager,
} from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import Calendar from './Models/Calendar'
import Event from './Models/Event'
import Attendee from './Models/Attendee'
import RecurrenceRule from './Models/RecurrenceRule'
import ErrorCodes from './Common/ErrorCodes'
import ErrorMessages from './Common/ErrorMessages'
import { CalMethodsName } from './Common/Constants'
import CalendarUtils from './Common/CalendarUtils'
import Reminder from './Models/Reminder'

/** DeviceCalendarOhosPlugin  **/
const permissions: Permissions[] = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];
export default class DeviceCalendarOhosPlugin  implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private static mContext: common.UIAbilityContext;
  private static calendarMgr: calendarManager.CalendarManager;

  constructor() {
  }

  onDetachedFromAbility(): void {
  }

  getUniqueClassName(): string {
    return "DeviceCalendarOhosPlugin "
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    DeviceCalendarOhosPlugin.mContext = binding.getAbility().context;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "plugins.builttoroam.com/device_calendar");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "getPlatformVersion") {
      result.success("OpenHarmony ^ ^ ")
    } else if (call.method == CalMethodsName.hasPermissions) {
      const hasAuth = this.hasPermissions();
      if (hasAuth) {
        DeviceCalendarOhosPlugin.calendarMgr = calendarManager.getCalendarManager(DeviceCalendarOhosPlugin.mContext);
      }
      result.success(hasAuth);
    } else if (call.method == CalMethodsName.requestPermissions) {
      this.requestPermissions(result)
    } else if (call.method == CalMethodsName.retrieveCalendars) {
      this.retrieveCalendars(result)
    } else if (call.method == CalMethodsName.retrieveEvents) {
      this.retrieveEvents(call.args, result);
    } else if (call.method == CalMethodsName.createCalendar) {
      this.createCalendar(call.args, result);
    } else if (call.method == CalMethodsName.deleteCalendar) {
      this.deleteCalendar(call.args, result)
    } else if (call.method == CalMethodsName.createOrUpdateEvent) {
      this.createOrUpdateEvent(call.args, result)
    } else if (call.method == CalMethodsName.deleteEvent) {
      this.deleteEvent(call.args, result);
    } else if (call.method == CalMethodsName.deleteEventInstance) {
      result.error(ErrorCodes.NOT_FOUND, "暂不支持该功能", '');
    } else {
      result.notImplemented()
    }
  }

  hasPermissions(): boolean {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    // 获取应用程序的accessTokenID
    let tokenId: number = 0;
    let bundleInfo: bundleManager.BundleInfo =
      bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
    tokenId = appInfo.accessTokenId;
    let grantStatus: abilityAccessCtrl.GrantStatus = atManager.checkAccessTokenSync(tokenId, permissions[1])
    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      return true;
    } else {
      return false;
    }
  }

  requestPermissions(result: MethodResult) {
    let atManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(DeviceCalendarOhosPlugin.mContext, permissions).then((requestResult: PermissionRequestResult) => {
      DeviceCalendarOhosPlugin.calendarMgr = calendarManager.getCalendarManager(DeviceCalendarOhosPlugin.mContext);
      if (requestResult.authResults.length > 0) {
        result.success(true);
      } else {
        result.success(false);
      }
    }).catch((error: BusinessError) => {
      result.error(ErrorCodes.GENERIC_ERROR, error.message, '');
    });
  }

  retrieveCalendars(result: MethodResult) {
    if (!this.hasPermissions()) {
      result.error(ErrorCodes.NOT_AUTHORIZED, ErrorMessages.NOT_AUTHORIZED_MESSAGE, '');
      return;
    }
    DeviceCalendarOhosPlugin.calendarMgr.getAllCalendars((err: BusinessError, data: calendarManager.Calendar[]) => {
      if (err) {
        result.error(ErrorCodes.GENERIC_ERROR, err.message, '');
      } else {
        let calendars: Array<Calendar> = [];
        data.forEach((element) => {
          let calendar = this.parseCalendar(element);
          calendars.push(calendar);
        })
        result.success(JSON.stringify(calendars))
      }
    });
  }

  retrieveEvents(args: Map<string, Object>, result: MethodResult) {
    // 获取参数
    const calendarId: string = args.get("calendarId") as string;
    const startDate: number = args.get("startDate") as number;
    const endDate: number = args.get("endDate") as number;
    const eventIds: string[] | undefined = args.get("eventIds") as string[] | undefined;
    if (!this.hasPermissions()) {
      result.error(ErrorCodes.INVALID_ARGUMENT, ErrorMessages.NOT_AUTHORIZED_MESSAGE, '');
      return;
    }
    if (!startDate && !endDate && !eventIds) {
      result.error(ErrorCodes.NOT_AUTHORIZED, ErrorMessages.RETRIEVE_EVENTS_ARGUMENTS_NOT_VALID_MESSAGE, '');
      return;
    }
    let allEvents: Event[] = [];
    DeviceCalendarOhosPlugin.calendarMgr.getAllCalendars(async (err: BusinessError, data: calendarManager.Calendar[]) => {
      if (err) {
        this.finishWithError(err, result);
      } else {
        let currentCalendar = data.find(item => item.id === Number(calendarId));
        let specifiedStartEndDates = startDate !== undefined && endDate !== undefined;
        if (currentCalendar) {
          if (specifiedStartEndDates) {
            let items: calendarManager.Event[] = await currentCalendar.getEvents(calendarManager.EventFilter.filterByTime(startDate, endDate),
              ['title', 'type', 'startTime', 'endTime', 'isAllDay','description','timeZone','location','service','attendee','reminderTime','recurrenceRule']);
            allEvents.push(...this.eventModelTransformation(items, calendarId));
          }
          if (!eventIds) {
            const results:string = JSON.stringify(allEvents);
            result.success(results);
            return;
          }
          if (specifiedStartEndDates) {
            allEvents = allEvents.filter((e) => {
              e.calendarId === calendarId && eventIds?.concat(e.eventId?.toString() ?? "")
            })
            result.success(JSON.stringify(allEvents));
            return;
          }
          // 根据eventIds获取Events
          let items: calendarManager.Event[] = await currentCalendar.getEvents(calendarManager.EventFilter.filterById(eventIds?.map(item => {
            return Number(item)
          })),['title', 'type', 'startTime', 'endTime', 'isAllDay','description','timeZone','location','service','attendee','reminderTime','recurrenceRule'])
          allEvents.push(...this.eventModelTransformation(items, calendarId));
          result.success(JSON.stringify(allEvents));
        } else {
          result.error(ErrorCodes.NOT_FOUND, `Couldn't retrieve the Calendar with ID ${calendarId}`, '');
        }
      }
    })
  }

  createCalendar(args: Map<string, Object>, result: MethodResult) {
    if (!this.hasPermissions()) {
      result.error(ErrorCodes.NOT_AUTHORIZED, ErrorMessages.NOT_AUTHORIZED_MESSAGE, '');
      return;
    }
    if (!args.get("calendarName")) {
      result.error(ErrorCodes.INVALID_ARGUMENT, ErrorMessages.RETRIEVE_EVENTS_ARGUMENTS_NOT_VALID_MESSAGE, '');
      return;
    }
    const calendarName = args.get("calendarName") as string;
    const localAccountName: string = args.get("localAccountName") as string;
    const calendarColor: string | undefined = args.get("calendarColor") as string | undefined;
    const calendarAccount: calendarManager.CalendarAccount = {
      name: calendarName,
      type: calendarManager.CalendarType.LOCAL,
      displayName: localAccountName
    };
    DeviceCalendarOhosPlugin.calendarMgr.createCalendar(calendarAccount, async (err: BusinessError, data: calendarManager.Calendar) => {
      if (err) {
        result.error(ErrorCodes.GENERIC_ERROR, err.message, '');
      } else {
        let colorStr: string | undefined = undefined;
        if (calendarColor) {
          colorStr = calendarColor.replace("0xff", "#");
        }
        let calendarConfig: calendarManager.CalendarConfig = {
          color: colorStr,
          enableReminder: true
        };
        await data.setConfig(calendarConfig,(err: BusinessError) => {
          // XDYou patch(2026-10-25): 原代码忽略 err、未判空 data.id，失败时同样会崩。
          if (err) {
            result.error(ErrorCodes.GENERIC_ERROR, err.message, '');
          } else {
            result.success(data?.id?.toString() ?? '');
          }
        });
      }
    });
  }

  deleteCalendar(args: Map<string, Object>, result: MethodResult) {
    if (!this.hasPermissions()) {
      result.error(ErrorCodes.NOT_AUTHORIZED, ErrorMessages.NOT_AUTHORIZED_MESSAGE, '');
      return;
    }
    if (!args.get("calendarId")) {
      result.error(ErrorCodes.INVALID_ARGUMENT, ErrorMessages.RETRIEVE_EVENTS_ARGUMENTS_NOT_VALID_MESSAGE, '');
      return;
    }
    const calendarId = args.get("calendarId") as string;
    DeviceCalendarOhosPlugin.calendarMgr.getAllCalendars((err: BusinessError, data: calendarManager.Calendar[]) => {
      if (err) {
        result.error(ErrorCodes.GENERIC_ERROR, err.message, '');
      } else {
        let currentCalendar = data.find(item => item.id === Number(calendarId));
        if (currentCalendar) {
          DeviceCalendarOhosPlugin.calendarMgr.deleteCalendar(currentCalendar, (error: BusinessError) => {
            if (error) {
              result.error(ErrorCodes.GENERIC_ERROR, error.message, '');
            } else {
              result.success(true);
            }
          });
        } else {
          result.error(ErrorCodes.NOT_FOUND, `The calendar with the ID ${calendarId} could not be found`, '');
        }
      }
    });
  }

  createOrUpdateEvent(args: Map<string, Object>, result: MethodResult) {
    if (!this.hasPermissions()) {
      result.error(ErrorCodes.NOT_AUTHORIZED, ErrorMessages.NOT_AUTHORIZED_MESSAGE, '');
      return;
    }
    if (!args.get("calendarId")) {
      result.error(ErrorCodes.INVALID_ARGUMENT, ErrorMessages.RETRIEVE_EVENTS_ARGUMENTS_NOT_VALID_MESSAGE, '');
      return;
    }
    const calendarId: string = args.get("calendarId") as string;
    const event: calendarManager.Event = this.parseEventArgs(args);
    DeviceCalendarOhosPlugin.calendarMgr.getAllCalendars((err: BusinessError, data: calendarManager.Calendar[]) => {
      if (err) {
        result.error(ErrorCodes.GENERIC_ERROR, err.message, '');
      } else {
        let currentCalendar = data.find(item => item.id === Number(calendarId));
        if (currentCalendar) {
          if (event.id) {
            currentCalendar.updateEvent(event, (err: BusinessError) => {
              if (err) {
                result.error(ErrorCodes.GENERIC_ERROR, err.message, '');
              } else {
                result.success(calendarId);
              }
            });
          } else {
            currentCalendar.addEvent(event, (error: BusinessError, data: number) => {
              // XDYou patch(2026-10-25): 原代码用外层 getAllCalendars 回调的 err 判断失败
              // （此处恒为 undefined），data 还遮蔽了外层变量；addEvent 失败时 data 为
              // undefined，直接 data.toString() → 进程崩溃（jscrash: Cannot read property
              // toString of undefined @ DeviceCalendarOhosPlugin.ts:281）。
              if (error) {
                result.error(ErrorCodes.GENERIC_ERROR, error.message, '');
              } else if (!data) {
                result.error(ErrorCodes.GENERIC_ERROR, 'Failed to create event', '');
              } else {
                result.success(data.toString());
              }
            });
          }
        } else {
          result.error(ErrorCodes.NOT_FOUND, `The calendar with the ID ${calendarId} could not be found`, '');
        }
      }
    });
  }

  deleteEvent(args: Map<string, Object>, result: MethodResult) {
    if (!this.hasPermissions()) {
      result.error(ErrorCodes.NOT_AUTHORIZED, ErrorMessages.NOT_AUTHORIZED_MESSAGE, '');
      return;
    }
    if (!args.get("calendarId") && !args.get("eventId")) {
      result.error(ErrorCodes.INVALID_ARGUMENT, ErrorMessages.RETRIEVE_EVENTS_ARGUMENTS_NOT_VALID_MESSAGE, '');
      return;
    }
    const calendarId: string = args.get("calendarId") as string;
    const eventId: string = args.get("eventId") as string;
    const startDateNumber: number | undefined = args.get("eventStartDate") as number | undefined;
    const endDateNumber: number | undefined = args.get("eventEndDate") as number;
    DeviceCalendarOhosPlugin.calendarMgr.getAllCalendars((err: BusinessError, data: calendarManager.Calendar[]) => {
      if (err) {
        result.error(ErrorCodes.GENERIC_ERROR, err.message, '');
      } else {
        let currentCalendar = data.find(item => item.id === Number(calendarId));
        if (currentCalendar) {
          if (!startDateNumber && !endDateNumber) {
            currentCalendar.deleteEvent(Number(eventId), (error: BusinessError) => {
              if (err) {
                result.error(ErrorCodes.GENERIC_ERROR, error.message, '');
              } else {
                result.success(true);
              }
            });
          } else {
            currentCalendar.getEvents(calendarManager.EventFilter.filterByTime(startDateNumber, endDateNumber),
              ['title', 'type', 'startTime', 'endTime', 'isAllDay','description','timeZone','location','service','attendee','reminderTime'])
              .then((events: calendarManager.Event[]) => {
                const eventFilter = events.filter((event) => event.id === Number(eventId));
                if (eventFilter) {
                  currentCalendar?.deleteEvent(eventFilter[0].id, (error: BusinessError) => {
                    if (err) {
                      result.error(ErrorCodes.GENERIC_ERROR, error.message, '');
                    } else {
                      result.success(true);
                    }
                  });
                } else {
                  result.error(ErrorCodes.GENERIC_ERROR, `The event with the ID ${eventId} could not be found`, '');
                }
              });
          }
        } else {
          result.error(ErrorCodes.NOT_FOUND, `The calendar with the ID ${eventId} could not be found`, '');
        }
      }
    });
  }

  eventModelTransformation(data: calendarManager.Event[], calendarId: string): Event[] {
    let events: Array<Event> = [];
    data.forEach((element) => {
      let recurrenceRule: RecurrenceRule | undefined
      if (element.recurrenceRule && element.recurrenceRule.recurrenceFrequency >= 0) {
        const recurrenceRuleE = element.recurrenceRule;
        let daysOfWeek: number[] | undefined = recurrenceRuleE.daysOfWeek != undefined ?
          Array.from(recurrenceRuleE.daysOfWeek, (value) => Number(value)) : undefined;
        let daysOfMonth: number[] | undefined = recurrenceRuleE.daysOfMonth != undefined ?
          Array.from(recurrenceRuleE.daysOfMonth, (value) => Number(value)) : undefined;
        const daysOfYear: number[] | undefined = recurrenceRuleE.daysOfYear != undefined ?
          Array.from(recurrenceRuleE.daysOfYear, (value) => Number(value)) : undefined;
        const weeksOfMonth: number[] | undefined = recurrenceRuleE.weeksOfMonth != undefined ?
        Array.from(recurrenceRuleE.weeksOfMonth, (value) => Number(value)) : undefined;
        const weeksOfYear: number[] | undefined = recurrenceRuleE.weeksOfYear != undefined ?
        Array.from(recurrenceRuleE.weeksOfYear, (value) => Number(value)) : undefined;
        let monthsOfYear: number[] | undefined = recurrenceRuleE.monthsOfYear != undefined ?
        Array.from(recurrenceRuleE.monthsOfYear, (value) => Number(value)) : undefined;
        const daysOfMonthFirst: number | undefined = daysOfMonth?.shift();
        const monthOfYear: number | undefined =  monthsOfYear?.shift() ;

        recurrenceRule = new RecurrenceRule(
          CalendarUtils.convertFrequencyToNumber(element.recurrenceRule.recurrenceFrequency!),
          element.recurrenceRule.count,
          element.recurrenceRule.interval,
          element.recurrenceRule.expire?.toString(),
          element.recurrenceRule.excludedDates?.map((e) => e.toString()),
          element.recurrenceRule.expire,
          daysOfWeek?.map( value => value === 7 ? 0 : value),
          daysOfMonthFirst,
          daysOfYear,
          weeksOfMonth != undefined ? weeksOfMonth.shift() : undefined,
          weeksOfYear,
          monthOfYear
        );
      }

      let event = new Event(
        element.title,
        element.id?.toString(),
        calendarId,
        element.description,
        element.startTime,
        element.endTime,
        element.timeZone,
        element.timeZone,
        element.isAllDay,
        element.location?.location,
        element.service?.uri,
        element.attendee?.map(item => {
          const emailAddress: string = item.email;
          const role: number = Number(item.role);
          const name: string = item.name;
          return new Attendee(emailAddress, role, role, name);
        }),
        recurrenceRule,
        undefined,
        element.reminderTime?.map((item) => {
          return new Reminder(item)
        }),
        CalendarUtils.convertEventTypeToString(element.type),
        CalendarUtils.convertServiceTypeToString(element.service?.type)
      );
      events.push(event);
    })
    return events;
  }

  getCalendarColor(calendarArg: calendarManager.Calendar) {
    let configColor = calendarArg.getConfig()?.color;
    let colorStr: string | undefined = undefined;
    if (configColor && typeof configColor === "string") {
      if (configColor.length > 7) {
        configColor = `#${configColor.slice(-6)}`;
      } else if (configColor == '#0') {
        return 0;
      }
      colorStr = configColor.replace("#", "0xFF");
      return Number(colorStr);
    } else {
      return configColor as number | undefined;
    }
  }

  parseCalendar(calendarArg: calendarManager.Calendar): Calendar {
    const account = calendarArg.getAccount();
    const color = this.getCalendarColor(calendarArg);
    let calendar = new Calendar(
      calendarArg.id.toString(),
      account.name,
      account.displayName ?? '',
      CalendarUtils.parseAccountType(account.type),
      false,
      false,
      color ?? 0,
      ''
    );
    return calendar;
  }

  parseEventArgs(args: Map<string, Object>): calendarManager.Event {
    const location: calendarManager.Location = {
      location: args.get("eventLocation") as string | undefined
    }
    //创建提醒时间
    const reminderTimes: number[] | undefined = this.parseReminderTimes(args.get("reminders") as Map<string, Object>[] | undefined);
    // 创建自定义间隔重复事件
    const recurrenceRule: calendarManager.RecurrenceRule | undefined = this.parseRecurrenceRule(args.get("recurrenceRule") as Map<string, Object> | undefined);
    const service: calendarManager.EventService | undefined = this.parseService(args);
    const event: calendarManager.Event = {
      id: Number(args.get("eventId")),
      title: args.get("eventTitle") as string | undefined,
      description: args.get("eventDescription") as string | undefined,
      type: CalendarUtils.parseEventType(args.get("eventType") as string), // calendarManager.EventType.NORMAL,
      location: location,
      startTime: args.get("eventStartDate") as number,
      endTime: args.get("eventEndDate") as number,
      isAllDay: args.get("eventAllDay") as boolean | undefined,
      timeZone: args.get("eventStartTimeZone") as string | undefined,
      reminderTime: reminderTimes,
      recurrenceRule: recurrenceRule,
      attendee: CalendarUtils.parseAttendees(args.get("attendees") as Map<string, Object>[] | undefined),
      service: service
    };
    return event;
  }

  parseService(args: Map<string, Object>): calendarManager.EventService | undefined {
    const eventURLArg: string | undefined = args.get("eventURL") as string | undefined;
    if (!eventURLArg) {
      return undefined;
    }
    const type = args.get("eventServiceType") as string;
    let service: calendarManager.EventService = {
      type: CalendarUtils.parseServiceType(type)!,
      uri: eventURLArg
    }
    return service;
  }

  parseReminderTimes(remindersArgs: Map<string, Object>[] | undefined): number[] {
    let reminderTimes: number[] = [];
    if (remindersArgs) {
      remindersArgs.forEach((e) => {
        let minutes = e.get("minutes") as number;
        reminderTimes.push(minutes);
      });
    }
    return reminderTimes;
  }

  parseRecurrenceRule(recurrenceRuleArguments: Map<string, Object> | undefined): calendarManager.RecurrenceRule | undefined {
    let recurrenceRule: calendarManager.RecurrenceRule | undefined;
    if (recurrenceRuleArguments && recurrenceRuleArguments.size > 0) {
      const freqArg = recurrenceRuleArguments.get("recurrenceFrequency") as number;
      const endDate: number | undefined = recurrenceRuleArguments.get("endDate") as number | undefined;
      const totalOccurrences: number | undefined = recurrenceRuleArguments.get("totalOccurrences") as number | undefined;
      const intervalArg: number | undefined = recurrenceRuleArguments.get("interval") as number | undefined;
      const untilArg: string | undefined = recurrenceRuleArguments.get("until") as string | undefined;
      let bydayArg: string[] | undefined = recurrenceRuleArguments.get("byday") as string[] | undefined;
      let daysOfWeek: number[] | undefined =  recurrenceRuleArguments.get("daysOfWeek") as number[] | undefined;
      const dayOfMonth: number | undefined =  recurrenceRuleArguments.get("dayOfMonth") as number | undefined;
      const daysOfYear: number[] | undefined =  recurrenceRuleArguments.get("daysOfYear") as number[] | undefined;
      const weekOfMonth: number | undefined =  recurrenceRuleArguments.get("weekOfMonth") as number | undefined;
      const weeksOfYear: number[] | undefined =  recurrenceRuleArguments.get("weeksOfYear") as number[] | undefined;
      const monthOfYear: number | undefined =  recurrenceRuleArguments.get("monthOfYear") as number | undefined;


      recurrenceRule = {
        recurrenceFrequency: freqArg,
        interval: intervalArg,
        count: totalOccurrences,
        expire: endDate,
        excludedDates: bydayArg == undefined ? undefined : bydayArg?.map((e) => Number(e)),
        daysOfWeek: daysOfWeek?.map(value => value === 0 ? 7 : value),
        daysOfMonth: dayOfMonth != undefined ? [dayOfMonth] : undefined,
        daysOfYear: daysOfYear,
        weeksOfMonth: weekOfMonth != undefined ? [weekOfMonth] : undefined,
        weeksOfYear: weeksOfYear,
        monthsOfYear: monthOfYear != undefined ? [monthOfYear] : undefined,
      }
    }
    return recurrenceRule;
  }

  finishWithError(err: BusinessError, result: MethodResult) {
    // XDYou patch(2026-10-25): err 可能为 undefined，原代码直接 err.code.toString() 会崩。
    result.error(err?.code?.toString() ?? ErrorCodes.GENERIC_ERROR, err?.message ?? '', '');
  }
}