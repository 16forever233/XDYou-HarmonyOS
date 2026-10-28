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

import { Freq } from '../Common/Enum'
import { LengthUnit } from '@kit.ArkUI';

export default class RecurrenceRule {
  recurrenceFrequency: number;
  totalOccurrences?: number;
  interval?: number;
  until?: string;
  byday?: string[];
  endDate?: number;
  daysOfWeek?: number[];
  dayOfMonth?: number;
  daysOfYear?: number[];
  weekOfMonth?: number;
  weeksOfYear?: number[];
  monthOfYear?: number;

  constructor(recurrenceFrequency: number, totalOccurrences?: number, interval?: number, until?: string,
    byday?: string[], endDate?: number, daysOfWeek?: number[], dayOfMonth?: number, daysOfYear?: number[],
    weekOfMonth?: number, weeksOfYear?: number[], monthOfYear?: number
  ) {

    this.recurrenceFrequency = recurrenceFrequency;
    this.totalOccurrences = totalOccurrences;
    this.interval = interval;
    this.until = until;
    this.byday = byday;
    this.endDate = endDate;
    this.daysOfWeek = daysOfWeek;
    this.dayOfMonth = dayOfMonth;
    this.daysOfYear = daysOfYear;
    this.weekOfMonth = weekOfMonth;
    this.weeksOfYear = weeksOfYear;
    this.monthOfYear = monthOfYear;
  }
}