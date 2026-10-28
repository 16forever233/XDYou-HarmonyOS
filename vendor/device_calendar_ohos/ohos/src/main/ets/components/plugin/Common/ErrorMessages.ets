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

export default class ErrorMessages {
  static CALENDAR_ID_INVALID_ARGUMENT_NOT_A_NUMBER_MESSAGE: string =
    "Calendar ID is not a number";

  static EVENT_ID_CANNOT_BE_NULL_ON_DELETION_MESSAGE: string =
    "Event ID cannot be null on deletion";

  static RETRIEVE_EVENTS_ARGUMENTS_NOT_VALID_MESSAGE: string =
    "Provided arguments (i.e. start, end and event ids) are null or empty";

  static CREATE_EVENT_ARGUMENTS_NOT_VALID_MESSAGE: string =
    "Some of the event arguments are not valid";

  static NOT_AUTHORIZED_MESSAGE: string =
    "The user has not allowed this application to modify their calendar(s)";
}