// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:catcher_2/catcher_2.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

final log = TalkerFlutter.init();

/// 这些站点的请求一律不写日志。

const Set<String> _sensitiveHosts = {
  'ids.xidian.edu.cn',
  'wlsy.xidian.edu.cn',
};

bool _isSensitiveNetworkRequest(Uri uri) {
  if (_sensitiveHosts.contains(uri.host)) return true;
  final lowerQuery = uri.query.toLowerCase();
  return uri.queryParameters.keys.any(
        (key) => const {
          'ticket',
          'password',
          'dynamiccode',
          'authorization',
          'bfp',
        }.contains(key.toLowerCase()),
      ) ||
      lowerQuery.contains('ticket=st-');
}

/// 请求体里是否含凭据。

bool _requestBodyLooksSensitive(Object? data) {
  if (data == null) return false;
  // 二进制（文件上传等）不做文本匹配，避免误判也避免把大对象转成字符串。
  if (data is List<int>) return false;

  final String body;
  if (data is String) {
    body = data;
  } else if (data is Map) {
    body = data.keys.join('&');
  } else {
    body = data.toString();
  }

  final lower = body.toLowerCase();
  return const [
    'password',
    'passwd',
    'pwd',
    'stuloginid',
    'dynamiccode',
  ].any(lower.contains);
}

final logDioAdapter = TalkerDioLogger(
  talker: log,
  settings: TalkerDioLoggerSettings(
    printRequestHeaders: true,
    printResponseHeaders: true,
    printResponseMessage: true,
    hiddenHeaders: const {
      'authorization',
      'cookie',
      'set-cookie',
      'proxy-authorization',
    },
    requestFilter: (request) =>
        !_isSensitiveNetworkRequest(request.uri) &&
        !_requestBodyLooksSensitive(request.data),
    responseFilter: (response) {
      // 1. 忽略特定 URL
      final url = response.requestOptions.uri.toString();
      if (_isSensitiveNetworkRequest(response.requestOptions.uri) ||
          // 请求体里含凭据时，响应也一并丢弃 
          // 而登录失败时服务器返回的错误页里同样可能带上用户输入。
          _requestBodyLooksSensitive(response.requestOptions.data) ||
          url.contains('openSliderCaptcha.htl')) {
        return false;
      }

      // 2. 忽略二进制文件 (Uint8List)
      // 通常通过检查 response.data 的类型或 Content-Type 头部
      if (response.data is List<int> || response.data is Uint8List) {
        return false;
      }

      return true;
    },
    errorFilter: (error) =>
        !_isSensitiveNetworkRequest(error.requestOptions.uri) &&
        !_requestBodyLooksSensitive(error.requestOptions.data),
  ),
);

class PDACatcher2Logger extends Catcher2Logger {
  @override
  void info(String message) {
    log.info('Custom Catcher2 Logger | Info | $message');
  }

  @override
  void fine(String message) {
    log.info('Custom Catcher2 Logger | Fine | $message');
  }

  @override
  void warning(String message) {
    log.warning('Custom Catcher2 Logger | Warning | $message');
  }

  @override
  void severe(String message) {
    log.error('Custom Catcher2 Logger | Servere | $message');
  }
}
