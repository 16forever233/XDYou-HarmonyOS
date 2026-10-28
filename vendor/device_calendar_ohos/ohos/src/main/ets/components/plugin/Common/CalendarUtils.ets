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

import { calendarManager } from '@kit.CalendarKit'

export default class CalendarUtils {

  static convertEventTypeToString(eventType: calendarManager.EventType): string | undefined {
    let eventTypeStr: string = "NORMAL";
    switch (eventType) {
      case calendarManager.EventType.NORMAL:
        eventTypeStr = "NORMAL";
        break;
      case calendarManager.EventType.IMPORTANT:
        eventTypeStr = "IMPORTANT"
        break;
    }
    return eventTypeStr;
  }

  static convertServiceTypeToString(serviceType: calendarManager.ServiceType | undefined): string {
    // 尝试将字符串转换为枚举成员
    let serviceTypeStr: string = "";
    switch (serviceType) {
      case calendarManager.ServiceType.MEETING:
        serviceTypeStr = "Meeting";
        break;
      case calendarManager.ServiceType.WATCHING:
        serviceTypeStr = "Watching";
        break;
      case calendarManager.ServiceType.REPAYMENT:
        serviceTypeStr = "Repayment";
        break;
      case calendarManager.ServiceType.LIVE:
        serviceTypeStr = "Live";
        break;
      case calendarManager.ServiceType.SHOPPING:
        serviceTypeStr = "Shopping";
        break;
      case calendarManager.ServiceType.TRIP:
        serviceTypeStr = "Trip";
        break;
      case calendarManager.ServiceType.CLASS:
        serviceTypeStr = "Class";
        break;
      case calendarManager.ServiceType.SPORTS_EVENTS:
        serviceTypeStr = "SportsEvents";
        break;
      case calendarManager.ServiceType.SPORTS_EXERCISE:
        serviceTypeStr = "SportsExercise";
        break;
    }
    return serviceTypeStr;
  }

  static convertFrequencyToNumber(recurrenceFrequency: calendarManager.RecurrenceFrequency): number {
      let frequency: number = 3;
      switch (recurrenceFrequency) {
        case calendarManager.RecurrenceFrequency.YEARLY:
          frequency = 0
          break
        case calendarManager.RecurrenceFrequency.MONTHLY:
          frequency = 1
          break
        case calendarManager.RecurrenceFrequency.WEEKLY:
          frequency = 2
          break
        case calendarManager.RecurrenceFrequency.DAILY:
          frequency = 3
          break
      }
      return frequency;
    }

  static parseAttendees(attendeesArg: Map<string, Object>[] | undefined): calendarManager.Attendee[] | undefined {
    let attendees: calendarManager.Attendee[] = [];
    attendeesArg?.forEach((attendeeArg) => {
      let name = attendeeArg.get("name") as string;
      let emailAddress = attendeeArg.get("emailAddress") as string;
      let role = attendeeArg.get("ohosRole") as number;
      let roleEnum: calendarManager.AttendeeRole = calendarManager.AttendeeRole.ORGANIZER
      switch (role) {
        case 0:
          roleEnum = calendarManager.AttendeeRole.ORGANIZER
          break;
        case 1:
          roleEnum = calendarManager.AttendeeRole.PARTICIPANT
          break;
      }
      let attendee: calendarManager.Attendee = {
        name: name,
        email: emailAddress,
        role: roleEnum
      }
      attendees?.push(attendee);
    })
    return attendees;
  }

  static parseFrequency(freqArg: string): calendarManager.RecurrenceFrequency {
    let recurrenceFrequency: calendarManager.RecurrenceFrequency = calendarManager.RecurrenceFrequency.DAILY;
    switch (freqArg) {
      case "YEARLY":
        recurrenceFrequency = calendarManager.RecurrenceFrequency.YEARLY;
        break;
      case "MONTHLY":
        recurrenceFrequency = calendarManager.RecurrenceFrequency.MONTHLY;
        break;
      case "WEEKLY":
        recurrenceFrequency = calendarManager.RecurrenceFrequency.WEEKLY;
        break;
      case "DAILY":
        recurrenceFrequency = calendarManager.RecurrenceFrequency.DAILY;
        break;
    }
    return recurrenceFrequency;
  }

  static parseAccountType(type: calendarManager.CalendarType): string {
    switch (type) {
      case calendarManager.CalendarType.LOCAL:
        return "Local"
      case calendarManager.CalendarType.EMAIL:
        return "Email"
      case calendarManager.CalendarType.BIRTHDAY:
        return "birthday"
      case calendarManager.CalendarType.CALDAV:
        return "Caldav"
      case calendarManager.CalendarType.SUBSCRIBED:
        return "Subscribed"
      default:
        return "Unknown";
    }
  }

  static parseServiceType(serviceTypeStr: string): calendarManager.ServiceType {
    let eventServiceType: calendarManager.ServiceType = calendarManager.ServiceType.MEETING;;
    switch (serviceTypeStr) {
      case "MEETING":
        eventServiceType = calendarManager.ServiceType.MEETING;
        break;
      case "WATCHING":
        eventServiceType = calendarManager.ServiceType.WATCHING;
        break;
      case "REPAYMENT":
        eventServiceType = calendarManager.ServiceType.REPAYMENT;
        break;
      case "LIVE":
        eventServiceType = calendarManager.ServiceType.LIVE;
        break;
      case "SHOPPING":
        eventServiceType = calendarManager.ServiceType.SHOPPING;
        break;
      case "TRIP":
        eventServiceType = calendarManager.ServiceType.TRIP;
        break;
      case "CLASS":
        eventServiceType = calendarManager.ServiceType.CLASS;
        break;
      case "SPORTS_EVENTS":
        eventServiceType = calendarManager.ServiceType.SPORTS_EVENTS;
        break;
      case "SPORTS_EXERCISE":
        eventServiceType = calendarManager.ServiceType.SPORTS_EXERCISE;
        break;
    }
    return eventServiceType;
  }

  static parseEventType(value: string): calendarManager.EventType {
    let status = calendarManager.EventType.NORMAL
    switch (value) {
      case "NORMAL":
        status = calendarManager.EventType.NORMAL
        break;
      case "IMPORTANT":
        status = calendarManager.EventType.IMPORTANT
        break;
    }
    return status
  }
}