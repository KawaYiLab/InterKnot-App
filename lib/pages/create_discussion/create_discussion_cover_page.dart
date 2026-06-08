import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/helpers/upload_task.dart';

typedef DroppedImageFile = ({
  String filename,
  Uint8List bytes,
  String mimeType
});

class CreateDiscussionCoverPage extends StatelessWidget {
  const CreateDiscussionCoverPage({
    super.key,
    required this.uploadTasks,
    required this.onPickImages,
    required this.onRemoveImageAt,
    required this.onRetryAt,
  });

  final RxList<UploadTask> uploadTasks;
  final VoidCallback onPickImages;
  final void Function(int index) onRemoveImageAt;
  final void Function(UploadTask task) onRetryAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            final tasks = uploadTasks;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: tasks.length + (tasks.length < 9 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == tasks.length) {
                  return _AddButton(onTap: onPickImages);
                }

                final task = tasks[index];
                return _UploadTaskTile(
                  task: task,
                  index: index,
                  allTasks: tasks,
                  onRemove: () => onRemoveImageAt(index),
                  onRetry: () => onRetryAt(task),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xff313132),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xff1E1E1E),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: Colors.grey),
            SizedBox(height: 4),
            Text(
              '添加图片',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTaskTile extends StatelessWidget {
  const _UploadTaskTile({
    required this.task,
    required this.index,
    required this.allTasks,
    required this.onRemove,
    required this.onRetry,
  });

  final UploadTask task;
  final int index;
  final List<UploadTask> allTasks;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = task.status.value;
      final progress = task.progress.value;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _buildPreview(status),
          ),
          // Overlay for non-done states
          if (status != UploadStatus.done)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: _buildStatusIndicator(status, progress),
                ),
              ),
            ),
          // Remove button (top-right)
          Positioned(
            right: 4,
            top: 4,
            child: _CircleButton(
              icon: Icons.close,
              onTap: onRemove,
            ),
          ),
          // Retry button for errors (center-bottom)
          if (status == UploadStatus.error)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xffD7FF00),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '重试',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildPreview(UploadStatus status) {
    // Done — show server URL
    if (status == UploadStatus.done && task.serverUrl != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            final doneUrls = allTasks
                .where((t) =>
                    t.status.value == UploadStatus.done && t.serverUrl != null)
                .map((t) => t.serverUrl!)
                .toList();
            final doneIndex = allTasks
                .where((t) =>
                    t.status.value == UploadStatus.done && t.serverUrl != null)
                .toList()
                .indexOf(task);
            if (doneUrls.isNotEmpty) {
              ImageViewer.show(
                Get.context!,
                imageUrls: doneUrls,
                initialIndex: doneIndex >= 0 ? doneIndex : 0,
              );
            }
          },
          child: Image.network(
            task.serverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Pending/compressing/uploading/error — show local preview
    if (task.localPreviewBytes != null) {
      return Image.memory(
        task.localPreviewBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xff1E1E1E),
          child: const Center(
            child: Icon(Icons.image, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xff1E1E1E),
      child: const Center(
        child: Icon(Icons.image, color: Colors.grey),
      ),
    );
  }

  Widget _buildStatusIndicator(UploadStatus status, int progress) {
    switch (status) {
      case UploadStatus.pending:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xffD7FF00),
          ),
        );
      case UploadStatus.compressing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xffFBC02D),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '压缩中',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        );
      case UploadStatus.uploading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress / 100,
                    strokeWidth: 3,
                    backgroundColor: Colors.white24,
                    color: const Color(0xffD7FF00),
                  ),
                  Center(
                    child: Text(
                      '$progress%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case UploadStatus.error:
        return const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
          size: 28,
        );
      case UploadStatus.done:
        return const SizedBox.shrink();
    }
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
