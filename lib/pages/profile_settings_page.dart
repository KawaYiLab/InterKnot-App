import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/utils/level_utils.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final c = Get.find<Controller>();
  final api = Get.find<Api>();

  late TextEditingController _nameController;
  late TextEditingController _bioController;

  bool _saving = false;
  bool _loading = true;

  List<Map<String, dynamic>> _avatars = [];
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _candidates = [];
  List<String> _pinned = [];

  String? _equippedAvatarId;
  String? _equippedCardId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = c.user.value;
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.getMyAvatars().then((r) => r),
        api.getMyBusinessCards().then((r) => r),
        api.getMyPinnedArticles().then((r) => r),
        _loadProfileBio(),
      ]);
      final avatarsResult = results[0] as AvatarListResult;
      final cardsResult = results[1] as BusinessCardListResult;
      final pinnedResult = results[2] as PinnedArticlesResult;

      _avatars = avatarsResult.data
          .map((e) => {
                'documentId': e.documentId,
                'name': e.name,
                'url': e.image?['url']?.toString() ?? '',
              })
          .toList();
      _equippedAvatarId = avatarsResult.equippedAvatarDocumentId;

      _cards = cardsResult.data
          .map((e) => {
                'documentId': e.documentId,
                'name': e.name,
                'url': e.image?['url']?.toString() ?? '',
              })
          .toList();
      _equippedCardId = cardsResult.equippedCardDocumentId;

      _candidates = pinnedResult.candidates;
      _pinned = pinnedResult.pinned?.toList() ?? [];
    } catch (e) {
      _error = e is ApiException ? e.message : '加载资料失败';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfileBio() async {
    final user = c.user.value;
    if (user == null || user.authorId == null || user.authorId!.isEmpty) {
      return;
    }
    try {
      final profile = await api.getProfile(user.authorId!);
      final bio = AuthorModel.extractBioText(profile['bio']);
      if (bio != null && bio.isNotEmpty) {
        user.bio = bio;
        _bioController.text = bio;
      }
    } catch (e) {
      // Ignore: bio is optional for editing.
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    final newBio = _bioController.text.trim();
    if (newName.isEmpty) {
      showToast('用户名不能为空', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final user = c.user.value;
      if (user != null && newName != user.name && newName != user.login) {
        final result = await api.updateMyName(newName);
        user.name = result;
        user.login = result;
      }
      if (user != null && newBio != (user.bio ?? '')) {
        await api.updateMyBio(newBio);
        user.bio = newBio;
      }
      c.user.refresh();
      await c.refreshMyExp();
      if (mounted) Navigator.of(context).pop();
      showToast('资料已保存');
    } catch (e) {
      showToast(e is ApiException ? e.message : '保存失败', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleVisibility(bool value) async {
    try {
      final result = await api.updateMyVisibility(value);
      final user = c.user.value;
      if (user != null) {
        user.profileHidden = result;
        c.user.refresh();
      }
      showToast(result ? '主页已隐身' : '主页已公开');
    } catch (e) {
      showToast(e is ApiException ? e.message : '设置失败', isError: true);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    await c.pickAndUploadAvatar();
    await _loadAll();
  }

  Future<void> _equipAvatar(String? documentId) async {
    try {
      final id = await api.equipAvatar(documentId);
      if (id != null) {
        _equippedAvatarId = id;
        final user = c.user.value;
        if (user != null) {
          final item = _avatars.firstWhere(
            (a) => a['documentId'] == id,
            orElse: () => {},
          );
          if (item.isNotEmpty && item['url'] != null) {
            user.avatar = item['url'].toString();
          }
          user.equippedAvatarDocumentId = id;
          c.user.refresh();
        }
        showToast('头像已更换');
      }
    } catch (e) {
      showToast(e is ApiException ? e.message : '更换头像失败', isError: true);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _equipCard(String? documentId) async {
    try {
      final id = await api.equipBusinessCard(documentId);
      if (id != null) {
        _equippedCardId = id;
        final user = c.user.value;
        if (user != null) {
          user.equippedCardDocumentId = id;
        }
        showToast('名片已更换');
      }
    } catch (e) {
      showToast(e is ApiException ? e.message : '更换名片失败', isError: true);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _savePinned() async {
    setState(() => _saving = true);
    try {
      await api.updateMyPinnedArticles(_pinned);
      final user = c.user.value;
      if (user != null) {
        user.profilePinnedArticles = _pinned.toList();
      }
      showToast('置顶已更新');
    } catch (e) {
      showToast(e is ApiException ? e.message : '保存置顶失败', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _togglePinned(String documentId) {
    setState(() {
      if (_pinned.contains(documentId)) {
        _pinned.remove(documentId);
      } else if (_pinned.length < 6) {
        _pinned.add(documentId);
      } else {
        showToast('最多置顶 6 篇文章', isError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = c.user.value;
    final level = user?.level ?? LevelUtils.currentLevel(user?.exp ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xff0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xff0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '编辑资料',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xffD7FF00),
                    ),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      color: Color(0xffD7FF00),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: _loading && _error == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xffD7FF00)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadAll,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showAvatarPicker,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xffD7FF00),
                                      width: 2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Avatar(user?.avatar, size: 80),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xffD7FF00),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lv.$level ${LevelUtils.titleFor(level)}',
                            style: const TextStyle(
                              color: Color(0xffD7FF00),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Name
                    TextField(
                      controller: _nameController,
                      maxLength: 20,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xffD7FF00)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Bio
                    TextField(
                      controller: _bioController,
                      maxLength: 100,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: '签名',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xffD7FF00)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Visibility
                    Obx(() => SwitchListTile(
                          title: const Text(
                            '主页隐身',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            '开启后他人无法查看你的主页内容',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          value: c.user.value?.profileHidden ?? false,
                          activeColor: const Color(0xffD7FF00),
                          onChanged: _toggleVisibility,
                        )),
                    const SizedBox(height: 16),
                    // Avatar library
                    _buildSectionTitle('头像'),
                    _buildAvatarGrid(),
                    const SizedBox(height: 16),
                    // Business card
                    _buildSectionTitle('名片'),
                    _buildCardGrid(),
                    const SizedBox(height: 24),
                    // Pinned
                    _buildSectionTitle('置顶文章'),
                    _buildPinnedList(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _savePinned,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffD7FF00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('保存置顶',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildAvatarGrid() {
    if (_avatars.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '暂无头像，可上传自定义头像',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _avatars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _avatars[index];
          final selected = item['documentId'] == _equippedAvatarId;
          return GestureDetector(
            onTap: () => _equipAvatar(item['documentId']?.toString()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xffD7FF00)
                          : const Color(0xff2A2A2A),
                      width: selected ? 3 : 1,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(item['url'].toString()),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['name']?.toString() ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardGrid() {
    if (_cards.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '暂无可选名片',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _cards[index];
          final selected = item['documentId'] == _equippedCardId;
          final url = item['url']?.toString();
          return GestureDetector(
            onTap: () => _equipCard(item['documentId']?.toString()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? const Color(0xffD7FF00)
                          : const Color(0xff2A2A2A),
                      width: selected ? 3 : 1,
                    ),
                    image: url != null && url.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(url),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: const Color(0xff1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['name']?.toString() ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinnedList() {
    if (_candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '暂无符合条件的文章',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }
    return Column(
      children: _candidates.map((item) {
        final docId = item['documentId']?.toString() ?? '';
        final title = item['title']?.toString() ?? '无标题';
        final selected = _pinned.contains(docId);
        return CheckboxListTile(
          value: selected,
          onChanged: (v) => _togglePinned(docId),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          activeColor: const Color(0xffD7FF00),
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }

  Future<void> _showAvatarPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1A1A),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.grey),
              title: const Text('上传自定义头像',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _pickAndUploadAvatar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.grey),
              title: const Text('头像库选择',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
