import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:path_provider/path_provider.dart';

class DownloadHelper {
  static Future<void> downloadImage(String url) async {
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      final tempDir = await getTemporaryDirectory();
      String ext = 'jpg';
      if (url.contains('.png'))
        ext = 'png';
      else if (url.contains('.gif'))
        ext = 'gif';
      else if (url.contains('.webp')) ext = 'webp';

      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '${tempDir.path}/$fileName';

      showToast('正在下载...', duration: const Duration(seconds: 1));
      await Dio().download(url, path);

      await Gal.putImage(path);
      showToast('图片已保存到相册');
    } catch (e) {
      showToast('保存失败: $e', isError: true);
    }
  }
}
