import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:inter_knot/constants/api_config.dart';
import 'package:inter_knot/helpers/toast.dart';

class ShareHelper {
  static Future<void> sharePost(String documentId) {
    if (documentId.isEmpty) {
      showToast('帖子ID为空', isError: true);
      return Future.value();
    }
    return _share('${ApiConfig.baseUrl}/post/$documentId');
  }

  static Future<void> shareProfile(String authorDocumentId) {
    if (authorDocumentId.isEmpty) {
      showToast('作者ID为空', isError: true);
      return Future.value();
    }
    return _share('${ApiConfig.baseUrl}/profile/$authorDocumentId');
  }

  static Future<void> _share(String url) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(uri: Uri.parse(url)),
      );
      if (result.status == ShareResultStatus.dismissed) return;
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: url));
      showToast('链接已复制到剪贴板');
    }
  }
}
