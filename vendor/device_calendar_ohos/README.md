# device_calendar_ohos

Flutter插件支持OpenHarmony平台，包括以下功能：访问是否有日历权限、获取日历权限、获取所有日历、获取日历的所有事件、创建日历、删除日历、创建日历事件或者更新日历事件、删除日历事件、删除日历的所有事件。

## Usage

```yaml
dependencies:
  device_calendar: 4.3.3
  device_calendar_ohos: 1.0.0
```

## Native features

Here's all native features that device_calendar provides to the flutter side.
| System                          | Android |  iOS  | OpenHarmony |
|:--------------------------------|:-------:| :---: |:---------:|
| hasPermissions                  |    ✅    |   ✅   |     ✅     |
| requestPermissions              |    ✅    |   ✅   |     ✅     |
| retrieveCalendars               |    ✅    |   ✅   |     ✅     |
| retrieveEvents                  |    ✅    |   ✅   |     ✅     |
| deleteCalendar                  |    ✅    |   ✅   |     ✅     |
| createOrUpdateEvent             |    ✅    |   ✅   |     ✅     |
| deleteEvent                     |    ✅    |   ✅   |     ✅     |
| deleteEventInstance             |    ✅    |   ✅   |     ⛔️     |

---

### 备注

 在设置日程事件时，全天日期存的时候时区是Asia/shanghai,取的时候获取到的是UTC,会导致日期往前一天

### Example

```pod
import 'package:device_calendar_ohos/device_calendar_ohos.dart';

DeviceCalendarOhosPlugin _deviceCalendarPlugin = DeviceCalendarOhosPlugin();

// 获取是否有日历权限
final permissionsGranted = await _deviceCalendarPlugin.hasPermissions();

// 请求日历权限 
final permissionsGranted = await _deviceCalendarPlugin.requestPermissions();

// 创建日历
final result = await _deviceCalendarPlugin.createCalendar(
              _calendarName,
              calendarColor: _color,
              localAccountName: _localAccountName);
// 获取所有日历
final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
        
// 等功能    

```