import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

class ProgressShareService {
  const ProgressShareService._();

  static Future<Uint8List> captureBoundaryPng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
  }) async {
    RenderRepaintBoundary? boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null || boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
      boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
    }
    if (boundary == null) {
      throw StateError('Unable to locate export boundary');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image');
    }
    return byteData.buffer.asUint8List();
  }

  static Future<void> sharePngBytes({
    required Uint8List pngBytes,
    required String fileStem,
    String? text,
    String? subject,
  }) async {
    final safeStem = fileStem.toLowerCase().replaceAll(
      RegExp('[^a-z0-9_\\-]'),
      '_',
    );
    final tempDir = await Directory.systemTemp.createTemp('buddy_share_');
    final file = File('${tempDir.path}/$safeStem.png');
    await file.writeAsBytes(pngBytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text, subject: subject),
    );
  }
}
