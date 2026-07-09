import 'package:flutter/material.dart';
import 'package:inter_knot/components/zzz_desktop_action_button.dart';

class CreateDiscussionDesktopFooter extends StatelessWidget {
  const CreateDiscussionDesktopFooter({
    super.key,
    required this.isSavingDraft,
    required this.isPublishing,
    required this.onSubmit,
    this.isDeletingDraft = false,
    this.isDiscardingChanges = false,
    this.submitEnabled = true,
    this.showCompressionToggle = false,
    this.compressBeforeUpload = true,
    this.onCompressionChanged,
    this.showDeleteButton = false,
    this.onDeleteDraft,
    this.showDiscardButton = false,
    this.onDiscard,
    this.isEditingPublished = false,
  });

  final bool isSavingDraft;
  final bool isPublishing;
  final bool isDeletingDraft;
  final bool isDiscardingChanges;
  final VoidCallback onSubmit;
  final bool submitEnabled;
  final bool showCompressionToggle;
  final bool compressBeforeUpload;
  final ValueChanged<bool>? onCompressionChanged;
  final bool showDeleteButton;
  final VoidCallback? onDeleteDraft;
  final bool showDiscardButton;
  final VoidCallback? onDiscard;
  final bool isEditingPublished;

  @override
  Widget build(BuildContext context) {
    final isBusy = isSavingDraft || isPublishing || isDeletingDraft || isDiscardingChanges;
    final buttonEnabled = submitEnabled && !isBusy;
    final buttonLabel = isPublishing
        ? isEditingPublished ? '更新中' : '发布中'
        : isSavingDraft
            ? isEditingPublished ? '保存中' : '保存草稿中'
            : isEditingPublished ? '更新帖子' : '发布';
    final buttonIcon = isSavingDraft ? Icons.save_outlined : isEditingPublished ? Icons.check : Icons.add;
    final deleteEnabled = showDeleteButton && !isBusy && onDeleteDraft != null;
    final discardEnabled = showDiscardButton && !isBusy && onDiscard != null;

    return Container(
      margin: const EdgeInsets.only(
        left: 8,
        right: 16,
        bottom: 16,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff070707),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showCompressionToggle)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xff121212),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xff2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      _CompressionOption(
                        label: '图片压缩',
                        selected: compressBeforeUpload,
                        onTap: isPublishing
                            ? null
                            : () => onCompressionChanged
                                ?.call(!compressBeforeUpload),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDiscardButton) ...[
                ZzzDesktopActionButton(
                  icon: Icons.undo_outlined,
                  label: isDiscardingChanges ? '恢复中' : '放弃修改',
                  width: 188,
                  tone: ZzzDesktopActionButtonTone.danger,
                  enabled: discardEnabled,
                  isLoading: isDiscardingChanges,
                  onTap: discardEnabled ? () => onDiscard?.call() : null,
                ),
                const SizedBox(width: 12),
              ],
              if (showDeleteButton) ...[
                ZzzDesktopActionButton(
                  icon: Icons.delete_outline,
                  label: isDeletingDraft ? '删除中' : '删除草稿',
                  width: 188,
                  tone: ZzzDesktopActionButtonTone.danger,
                  enabled: deleteEnabled,
                  isLoading: isDeletingDraft,
                  onTap: deleteEnabled ? () => onDeleteDraft?.call() : null,
                ),
                const SizedBox(width: 12),
              ],
              ZzzDesktopActionButton(
                icon: buttonIcon,
                label: buttonLabel,
                width: 188,
                enabled: buttonEnabled,
                isLoading: isPublishing,
                onTap: buttonEnabled ? () => onSubmit() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompressionOption extends StatelessWidget {
  const _CompressionOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xffD7FF00) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
