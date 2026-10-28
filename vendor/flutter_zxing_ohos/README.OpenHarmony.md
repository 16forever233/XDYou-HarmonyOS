<p align="center">
  <h1 align="center"> <code>flutter_zxing</code> </h1>
</p>


This project is based on [flutter_zxing@2.2.1](https://pub.dev/packages/flutter_zxing/versions/2.2.1).

## 1. Installation and Usage

### 1.1 Installation

Go to the project directory and add the following dependencies in pubspec.yaml

<!-- tabs:start -->

#### pubspec.yaml

```yaml
dependencies:
  flutter_zxing:
    git:
      url: https://gitcode.com/CPF-Flutter/fluttertpc_flutter_zxing.git
      # ref: Select the TAG version that matches your Flutter framework version from the table below
      ref: TAG  # Select a TAG from the TAG version mapping table below

dev_dependencies:
  flutter_zxing_ohos:
    git:
      url: https://gitcode.com/CPF-Flutter/fluttertpc_flutter_zxing.git
      # ref: Select the TAG version that matches your Flutter framework version from the table below
      ref: TAG  # Select a TAG from the TAG version mapping table below
      path: ohos
```

Execute Command

```bash
flutter pub get
```
> TAG naming rule: original-version-ohos-version-betax. See CHANGELOG.OpenHarmony.md for changes between TAG versions. Replace TAG in the dependency example with the TAG selected from the table.

| Flutter framework version | TAG name | Branch |
|---|---|---|
| 3.7 | v1.1.0_ohos_1.0.0 | master |
| 3.27 | 2.1.0-ohos-1.0.0-beta.1 | br_v2.1.0_ohos |
| 3.35 | 2.2.1-ohos-1.0.0 | br_v2.2.1_ohos |
<!-- tabs:end -->

### 1.2 Usage

For use cases [ohos/example](./example/)

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

1. Flutter: 3.27.5-ohos-0.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;
2. Flutter: 3.35.7-ohos-0.0.1; SDK: 6.0.1(21); IDE: DevEco Studio: 6.0.1.260; ROM: 6.0.0.120 SP6;

## 3. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name                | return          | Description                                                                                                             | Type     | ohos Support |
|---------------------|-------------------------------------------------------------------------------------------------------------------------|----------|-------------------|-------------------|
| startCameraProcessing() | Future<void> | Starts reading barcode from the camera. | function | yes               |
| stopCameraProcessing() | void | Stops reading barcode from the camera. | function | yes               |
| processCameraImage(CameraImage image,{DecodeParams? params,}) | Future<Code> | Reads barcode from the camera. | function | yes               |
| processCameraImageMulti(CameraImage image, {DecodeParams? params,}) | Future<Code> | Reads barcodes from the camera. | function | yes               |
| readBarcodeImagePathString(String path, {DecodeParams? params,}) | Future<Code> | Reads barcode from String image path. | function | yes               |
| readBarcodeImagePath(XFile path, {DecodeParams? params,}) | Future<Code> | Reads barcode from XFile image path. | function | yes               |
| readBarcodeImageUrl(String url, {DecodeParams? params,}) | Future<Code> | Reads barcode from image url. | function | yes               |
| readBarcodesImagePathString(String path, {DecodeParams? params,}) | Future<Codes> |  Reads barcodes from String image path. | function | yes               |
| readBarcodesImagePath(XFile path, {DecodeParams? params,}) | Future<Codes> | Reads barcodes from XFile image path. | function | yes               |
| readBarcodesImageUrl(String url, {DecodeParams? params,}) | Future<Codes> | Reads barcodes from image url. | function | yes               |

## Parameters

| Name        | Type                  | Description       | ohos Support |
|-------------|------------------------------|------------|--------------|
| image | String | Barcode data source. | yes          |
| params | DecodeParams | Barcode decoding parameters. | yes          |
| path | XFile | XFile image path. | yes          |
| url | String | Image URL | yes          |

## 4. Known Issues

not

## 5. Others

## 6. License

This project is licensed under  [MIT License](https://gitcode.com/CPF-Flutter/fluttertpc_flutter_zxing/blob/master/LICENSE) .

> Template version: v0.0.1