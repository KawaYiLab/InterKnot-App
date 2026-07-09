import 'package:flutter/material.dart';
import 'package:inter_knot/helpers/smooth_scroll.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion/discussion_action_buttons.dart';
import 'package:inter_knot/pages/discussion/discussion_comment_section.dart';
import 'package:inter_knot/pages/discussion/discussion_cover.dart';
import 'package:inter_knot/pages/discussion/discussion_detail_box.dart';

class DiscussionDesktopBody extends StatelessWidget {
  const DiscussionDesktopBody({
    super.key,
    required this.discussion,
    required this.hData,
    required this.isDetailLoading,
    required this.isInitialLoading,
    required this.leftScrollController,
    required this.scrollController,
    required this.actionButtonsKey,
    required this.buildNewCommentNotification,
    required this.onCommentAdded,
    required this.onEditSuccess,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final bool isDetailLoading;
  final bool isInitialLoading;
  final ScrollController leftScrollController;
  final ScrollController scrollController;
  final GlobalKey<DiscussionActionButtonsState> actionButtonsKey;
  final Widget Function() buildNewCommentNotification;
  final VoidCallback onCommentAdded;
  final VoidCallback onEditSuccess;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 8,
              bottom: 16,
            ),
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xff070707),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AdaptiveSmoothScroll(
                    controller: leftScrollController,
                    scrollSpeed: 0.5,
                    builder: (context, physics) => SingleChildScrollView(
                      controller: leftScrollController,
                      physics: physics,
                      child: Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight - 120,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  foregroundDecoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xff313132),
                                      width: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: isDetailLoading
                                      ? const SizedBox.shrink()
                                      : Cover(discussion: discussion),
                                ),
                              ),
                            ),
                          ),
                          isDetailLoading
                              ? const SizedBox.shrink()
                              : DiscussionDetailBox(discussion: discussion),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.only(
              top: 16,
              left: 8,
              right: 16,
              bottom: 16,
            ),
            height: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xff070707),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        AdaptiveSmoothScroll(
                          controller: scrollController,
                          scrollSpeed: 0.5,
                          builder: (context, physics) => DiscussionCommentSection(
                            discussion: discussion,
                            isInitialLoading: isInitialLoading,
                            useListView: true,
                            controller: scrollController,
                            physics: physics,
                            padding: const EdgeInsets.all(16.0),
                            onReply: (
                              id,
                              userName, {
                              addPrefix = false,
                              authorDocumentId,
                            }) =>
                                actionButtonsKey.currentState?.replyTo(
                              id,
                              userName,
                              addPrefix: addPrefix,
                              authorDocumentId: authorDocumentId,
                            ),
                          ),
                        ),
                        buildNewCommentNotification(),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Color(0xff313132),
                        ),
                      ),
                    ),
                    child: DiscussionActionButtons(
                      key: actionButtonsKey,
                      discussion: discussion,
                      hData: hData,
                      onCommentAdded: onCommentAdded,
                      onEditSuccess: onEditSuccess,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
