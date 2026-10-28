<p align="center">
  <h1 align="center"> <code>flutter_zxing</code> </h1>
</p>


本项目基于 [flutter_zxing@2.2.1](https://pub.dev/packages/flutter_zxing/versions/2.2.1) 开发。

## 1. 安装与使用

### 1.1 安装方式

进入到工程目录并在 pubspec.yaml 中添加以下依赖：

<!-- tabs:start -->

#### pubspec.yaml

```yaml
dependencies:
  flutter_zxing:
    git:
      url: https://gitcode.com/CPF-Flutter/fluttertpc_flutter_zxing.git
      # ref: 根据下方表格选择不同框架适配的TAG版本
      ref: TAG  # Select a TAG from the TAG version mapping table below

dev_dependencies:
  flutter_zxing_ohos:
    git:
      url: https://gitcode.com/CPF-Flutter/fluttertpc_flutter_zxing.git
      # ref: 根据下方表格选择不同框架适配的TAG版本
      ref: TAG  # Select a TAG from the TAG version mapping table below
      path: ohos
```

执行命令

```bash
flutter pub get
```
> TAG 命名规则：原库版本-ohos-版本号-betax，不同 TAG 之间的变更详见 CHANGELOG.OpenHarmony.md。实际使用时请将依赖示例中的 TAG 替换为下表选择的 TAG。

| Flutter 框架版本 | TAG 名称 | 分支名 |
|---|---|---|
| 3.7 | v1.1.0_ohos_1.0.0 | master |
| 3.27 | 2.1.0-ohos-1.0.0-beta.1 | br_v2.1.0_ohos |
| 3.35 | 2.2.1-ohos-1.0.0 | br_v2.2.1_ohos |

<!-- tabs:end -->

### 1.2 使用案例


使用案例详见 [ohos/example](./example/)

## 2. 约束与限制

### 2.1 兼容性

在以下版本中已测试通过

1. Flutter: 3.27.5-ohos-0.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;
2. Flutter: 3.35.7-ohos-0.0.1; SDK: 6.0.1(21); IDE: DevEco Studio: 6.0.1.260; ROM: 6.0.0.120 SP6;

## 3. API

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

| Name                | return          | Description                                                                                                             | Type     | ohos Support |
|---------------------|-------------------------------------------------------------------------------------------------------------------------|----------|-------------------|-------------------|
| startCameraProcessing() | Future<void> | 开始从相机读取条形码。 | function | yes               |
| stopCameraProcessing() | void | 停止从相机读取条形码。 | function | yes               |
| processCameraImage(CameraImage image,{DecodeParams? params,}) | Future<Code> | 从相机读取条形码。 | function | yes               |
| processCameraImageMulti(CameraImage image, {DecodeParams? params,}) | Future<Code> | 从相机读取条形码。 | function | yes               |
| readBarcodeImagePathString(String path, {DecodeParams? params,}) | Future<Code> | 从 String 图像路径读取条形码。 | function | yes               |
| readBarcodeImagePath(XFile path, {DecodeParams? params,}) | Future<Code> | 从 XFile 图像路径读取条形码。 | function | yes               |
| readBarcodeImageUrl(String url, {DecodeParams? params,}) | Future<Code> | 从图像 url 中读取条形码。 | function | yes               |
| readBarcodesImagePathString(String path, {DecodeParams? params,}) | Future<Codes> | 从 String 图像路径读取条形码。 | function | yes               |
| readBarcodesImagePath(XFile path, {DecodeParams? params,}) | Future<Codes> | 从 XFile 图像路径读取条形码。 | function | yes               |
| readBarcodesImageUrl(String url, {DecodeParams? params,}) | Future<Codes> | 从图像 url 中读取条形码。 | function | yes               |

## Parameters

| Name        | Type                  | Description       | ohos Support |
|-------------|------------------------------|------------|--------------|
| image | String | 条形码数据源。 | yes          |
| params | DecodeParams | 条形码解码参数。 | yes          |
| path | XFile | XFile图像路径。 | yes          |
| url | String | 图像的url。 | yes          |

## 4. 遗留问题

无

## 5. 其他

## 6. 开源协议

本项目基于 [MIT开源协议](https://gitcode.com/CPF-Flutter/fluttertpc_flutter_zxing/blob/master/LICENSE) ，请自由地享受和参与开源。



> 模板版本: v0.0.1
