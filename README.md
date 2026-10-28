<div align="center">
<img src="./assets/icon.png" style="border-radius:16px; margin:10px; width:120px" alt="XDYou">
<h1>XDYou（鸿蒙版）</h1>

[![AppGallery](https://img.shields.io/badge/AppGallery-%E4%B8%8B%E8%BD%BD-brightgreen.svg)](https://appgallery.huawei.com/app/detail?id=com.xdyou.hmos&channelId=SHARE&source=appshare) [![下载量](https://img.shields.io/badge/%E4%B8%8B%E8%BD%BD%E9%87%8F-969-blue.svg)](https://appgallery.huawei.com/app/detail?id=com.xdyou.hmos&channelId=SHARE&source=appshare) [![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](./LICENSE) ![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%2026-green)

</div>

## 简介

XDYou（代码名 Traintime PDA）是为西安电子科技大学学生设计的开源信息查询软件，功能包括课表与日程、成绩、考试、体育、宿舍电量与水机、空闲教室、图书馆、校园卡、校园网、考勤、睿思论坛、上课提醒，并支持完整的国际化（简体 / 繁体中文与 English）。

本仓库是 XDYou 的**鸿蒙（HarmonyOS NEXT）移植版**仓库，**只包含鸿蒙版本所需的源码**：Flutter-OH 应用代码（`lib/`）、鸿蒙工程（`ohos/`）、资源（`assets/`）、测试（`test/`）、鸿蒙适配的第三方依赖（`vendor/`）与根目录配置，**不含 Android、iOS、桌面等平台的代码**。

- 原项目仓库（Android / iOS / 桌面版本）：<https://github.com/BenderBlog/traintime_pda>
- 鸿蒙版下载：**华为应用市场**（搜索「XDYou」，或点上方下载链接）
- 当前版本：**1.6.6（26166300）**，基于 Flutter-OH 3.41.10 与 HarmonyOS 7（API 26）

## 开源授权信息

- 本仓库主体遵循 **Mozilla Public License 2.0（MPL-2.0）**，全文见 [LICENSE](./LICENSE)；个别文件按文件头 `SPDX-License-Identifier` 标注的许可（MIT / Apache-2.0 等）授权。
- `vendor/` 下为经过鸿蒙适配与修补的第三方开源库（`file_picker_ohos`、`catcher_2`、`flutter_local_notifications`、`talker_flutter`、`flutter_zxing_ohos`、`flex_color_scheme`、`device_calendar_ohos`），各自保留上游的 LICENSE 与版权声明，具体见各目录下的 `LICENSE`。
- 应用图标与开屏图仅用于标识 XDYou，不得挪作他用。
- 本仓库不含任何遥测、埋点或统计 SDK。

## 协议

- 源码的使用与分发遵循 **MPL-2.0**：修改本仓库中的文件并分发时，需按 MPL 的要求公开这些文件的修改。
- 本移植版**仅供学习交流使用**，请勿用于商业用途；因使用本软件产生的一切后果由使用者自行承担。
- 应用数据均来自学校相关系统的个人查询页面（本程序只是模拟浏览器访问），请遵守学校相关规定并合理使用。
