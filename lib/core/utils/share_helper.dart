import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Gửi nội dung sang ứng dụng khác qua bảng chia sẻ của hệ điều hành.
class ShareHelper {
  const ShareHelper._();

  static Rect? _origin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  static Future<void> shareText(BuildContext context, String text, {String? subject}) {
    return SharePlus.instance.share(ShareParams(text: text, subject: subject, sharePositionOrigin: _origin(context)));
  }

  /// Ghi nội dung ra file tạm rồi chia sẻ. CSV được thêm BOM để Excel đọc đúng tiếng Việt.
  static Future<void> shareFile(BuildContext context, String fileName, String content, {String? mimeType}) async {
    final origin = _origin(context);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    final bom = fileName.endsWith('.csv') ? '﻿' : '';
    await file.writeAsString('$bom$content', encoding: utf8);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
      sharePositionOrigin: origin,
    ));
  }

  /// Tên file an toàn từ tên nhóm.
  static String safeFileName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return cleaned.isEmpty ? 'chiapay' : cleaned;
  }
}
