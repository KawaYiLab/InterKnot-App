import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/page_transition_helper.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/pages/profile_settings_page.dart';

void showEditProfileDialog(BuildContext context) {
  navigateWithSlideTransition(
    context,
    const ProfileSettingsPage(),
    routeName: '/profile/settings',
  );
}

void showLogoutDialog(BuildContext context) {
  showZZZDialog(
    context: context,
    pageBuilder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xff1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color.fromARGB(59, 255, 255, 255),
            width: 3,
          ),
        ),
        title: const Text('确认退出登录?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final user = c.user.value;
              return Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Avatar(
                      user?.avatar,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? '未知用户',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await c.setToken('');
              c.isLogin(false);
              showToast('已退出登录');
              Navigator.pop(context);
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}

class _AvatarHoverWrapper extends StatefulWidget {
  const _AvatarHoverWrapper();

  @override
  State<_AvatarHoverWrapper> createState() => _AvatarHoverWrapperState();
}

class _AvatarHoverWrapperState extends State<_AvatarHoverWrapper> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: c.pickAndUploadAvatar,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Obx(() {
              final currentUser = c.user.value;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Avatar(
                  currentUser?.avatar,
                  size: 100,
                ),
              );
            }),
            if (isHovering)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            Obx(() {
              if (c.isUploadingAvatar.value) {
                return const SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }
}
