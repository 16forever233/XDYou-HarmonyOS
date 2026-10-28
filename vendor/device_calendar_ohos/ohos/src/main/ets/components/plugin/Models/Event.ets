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

import Attendee from './Attendee';
import RecurrenceRule from './RecurrenceRule';
import Reminder from './Reminder';
import { EventStatus, Availability } from '../Common/Enum';

export default class Event {
  eventTitle?: string;
  eventId?: string;
  calendarId?: string;
  eventDescription?: string;
  eventStartDate?: number;
  eventEndDate?: number;
  eventStartTimeZone?: string;
  eventEndTimeZone?: string;
  eventAllDay: boolean = false;
  eventLocation?: string;
  eventURL?: string;
  attendees: Attendee[] = [];
  recurrenceRule?: RecurrenceRule;
  organizer?: Attendee;
  reminders: Reminder[] = [];
  eventType?: string;
  eventServiceType?: string

  constructor(
    eventTitle?: string,
    eventId?: string,
    calendarId?: string,
    eventDescription?: string,
    eventStartDate?: number,
    eventEndDate?: number,
    eventStartTimeZone?: string,
    eventEndTimeZone?: string,
    eventAllDay: boolean = false,
    eventLocation?: string,
    eventURL?: string,
    attendees?: Attendee[],
    recurrenceRule?: RecurrenceRule,
    organizer?: Attendee,
    reminders?: Reminder[],
    eventType?: string,
    eventServiceType?: string
  ) {
    this.eventTitle = eventTitle;
    this.eventId = eventId;
    this.calendarId = calendarId;
    this.eventDescription = eventDescription;
    this.eventStartDate = eventStartDate;
    this.eventEndDate = eventEndDate;
    this.eventStartTimeZone = eventStartTimeZone;
    this.eventEndTimeZone = eventEndTimeZone;
    this.eventAllDay = eventAllDay;
    this.eventLocation = eventLocation;
    this.eventURL = eventURL;
    this.attendees = attendees || [];
    this.recurrenceRule = recurrenceRule;
    this.organizer = organizer;
    this.reminders = reminders || [];
    this.eventType = eventType;
    this.eventServiceType = eventServiceType;
  }
}