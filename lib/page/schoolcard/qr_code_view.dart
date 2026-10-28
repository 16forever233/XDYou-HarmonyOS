// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:watermeter/controller/school_card_controller.dart';

class QRCodeView extends StatefulWidget {
  const QRCodeView({super.key});

  @override
  State<QRCodeView> createState() => _QRCodeViewState();
}

class _QRCodeViewState extends State<QRCodeView> {
  Future<Uint8List> qrCode = SchoolCardController.i.session.getQRCode();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(FlutterI18n.translate(context, "school_card_window.qr_code")),
      content: FutureBuilder<Uint8List>(
        future: qrCode,
        builder: (context, snapshot) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(24),
                color: Colors.white.withValues(alpha: 0.85),
                // 固定 200×200，加载/错误/成功三态尺寸一致；
                // 用 AnimatedSwitcher 在状态切换时淡入淡出过渡。
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(
                            key: ValueKey('qr-loading'),
                            child: CircularProgressIndicator(),
                          )
                        : snapshot.hasError
                        ? Center(
                            key: const ValueKey('qr-error'),
                            child: Text(
                              FlutterI18n.translate(
                                context,
                                "school_card_window.qr_code",
                                translationParams: {
                                  "info": snapshot.error.toString(),
                                },
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Image.memory(
                            snapshot.data!,
                            key: const ValueKey('qr-success'),
                            width: 200,
                            height: 200,
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              qrCode = SchoolCardController.i.session.getQRCode();
            });
          },
          child: Text(
            FlutterI18n.translate(context, "school_card_window.reload"),
          ),
        ),
      ],
    );
  }
}
