import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/api/api_exception.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/cached_image.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/components/report_sheet.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/controllers/messaging_controller.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/share_helper.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/zzzui/zzzui.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion_page.dart';
import 'package:inter_knot/pages/dm_chat_page.dart';
import 'package:inter_knot/pages/profile_settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.authorDocumentId,
  });

  final String authorDocumentId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = Get.find<Api>();
  final _c = Get.find<Controller>();

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  final RxSet<HDataModel> _articles = <HDataModel>{}.obs;
  String _articlesEndCursor = '0';
  bool _hasMoreArticles = true;
  bool _isLoadingArticles = false;

  bool _isFollowingLoading = false;
  bool _dmStarting = false;
  bool _checkInLoading = false;

  final _checkInStatus = <String, dynamic>{
    'canCheckIn': false,
    'totalDays': 0,
    'consecutiveDays': 0,
    'rank': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await _api.getProfile(widget.authorDocumentId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
      await _loadArticles();
      if (_isSelf) {
        await _loadCheckInStatus();
      }
    } catch (e) {
      logger.e('Failed to load profile', error: e);
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadArticles() async {
    if (_isLoadingArticles || !_hasMoreArticles || _isHidden) return;

    setState(() => _isLoadingArticles = true);

    try {
      Map<String, dynamic>? authorData;
      if (_profile != null) {
        authorData = {
          'documentId': _profile!['documentId'],
          'name': _profile!['name'],
          'slug': _profile!['slug'],
          'avatar': _profile!['avatar'],
          'user': _profile!['user'],
        };
      }

      final result = await _api.getProfileArticles(
        widget.authorDocumentId,
        _articlesEndCursor,
        authorData: authorData,
      );

      if (mounted) {
        setState(() {
          _articles.addAll(result.nodes);
          _articlesEndCursor = result.endCursor ?? _articlesEndCursor;
          _hasMoreArticles = result.hasNextPage;
          _isLoadingArticles = false;
        });
      }
    } catch (e) {
      logger.e('Failed to load articles', error: e);
      if (mounted) {
        setState(() {
          _isLoadingArticles = false;
          _hasMoreArticles = false;
        });
      }
    }
  }

  Future<void> _loadCheckInStatus() async {
    try {
      final status = await _api.getCheckInStatus();
      if (mounted) {
        setState(() {
          _checkInStatus['canCheckIn'] = status.canCheckIn;
          _checkInStatus['totalDays'] = status.totalDays;
          _checkInStatus['consecutiveDays'] = status.consecutiveDays;
          _checkInStatus['rank'] = status.rank;
        });
      }
    } catch (e) {
      // Silent: check-in status is optional.
    }
  }

  Future<void> _doCheckIn() async {
    if (!(_checkInStatus['canCheckIn'] as bool? ?? false) || _checkInLoading) {
      return;
    }

    setState(() => _checkInLoading = true);
    try {
      final result = await _api.checkIn();
      if (mounted) {
        setState(() {
          _checkInStatus['canCheckIn'] = false;
          _checkInStatus['totalDays'] = result.totalDays;
          _checkInStatus['consecutiveDays'] = result.consecutiveDays;
          _checkInStatus['rank'] = result.rank;
        });
      }

      final user = _c.user.value;
      if (user != null) {
        if (result.currentExp != null) user.exp = result.currentExp;
        if (result.currentLevel != null) user.level = result.currentLevel;
        if (result.currentDenny != null) user.denny = result.currentDenny;
        user.lastCheckInDate = DateTime.now().toIso8601String();
        user.canCheckIn = false;
        _c.user.refresh();
      }

      final dennyAdded = result.dennyAdded ?? 10;
      final reward = result.reward ?? 0;
      final rank = result.rank ?? 0;
      final totalDays = result.totalDays ?? 0;
      final rewardParts = <String>['丁尼+$dennyAdded'];
      if (reward > 0) rewardParts.add('绳网信用+$reward');
      final rankText = rank > 0 ? '，今日第${rank}名' : '';
      final daysText = totalDays > 0 ? '，累计${totalDays}天' : '';

      showToast('签到成功！${rewardParts.join('，')}$daysText$rankText');
    } catch (e) {
      showToast(e is ApiException ? e.message : '签到失败', isError: true);
    } finally {
      if (mounted) setState(() => _checkInLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isSelf || _isHidden) return;

    if (!await _c.ensureLogin(context: context)) return;

    final documentId = _profile!['documentId']?.toString() ?? '';
    if (documentId.isEmpty) return;

    setState(() => _isFollowingLoading = true);
    try {
      final result = await _api.toggleFollow(documentId);
      if (mounted) {
        setState(() {
          _profile!['isFollowing'] = result.following;
          _profile!['followersCount'] = result.followersCount;
        });
      }
      showToast(result.following ? '已关注' : '已取消关注');
    } catch (e) {
      showToast(e is ApiException ? e.message : '关注操作失败', isError: true);
    } finally {
      if (mounted) setState(() => _isFollowingLoading = false);
    }
  }

  Future<void> _startDm() async {
    if (_profile == null || _isSelf || _isHidden || _uid == null) return;

    if (!await _c.ensureLogin(context: context)) return;

    final messaging = Get.find<MessagingController>();
    setState(() => _dmStarting = true);
    try {
      await messaging.openDirectChat(_uid!);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DmChatPage()),
        );
      }
    } catch (e) {
      showToast(e is ApiException ? e.message : '无法发起私聊', isError: true);
    } finally {
      if (mounted) setState(() => _dmStarting = false);
    }
  }

  Future<void> _shareProfile() async {
    await ShareHelper.shareProfile(widget.authorDocumentId);
  }

  Future<void> _reportUser() async {
    if (_profile == null || _isSelf || _isHidden) return;

    if (!await _c.ensureLogin(context: context)) return;

    final userId = _profile!['userId']?.toString() ?? '';
    if (userId.isEmpty) return;

    if (mounted) {
      await showReportSheet(
        context,
        targetType: 'user',
        targetId: userId,
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
    );
  }

  void _openAvatarSettings() => _openSettings();
  void _openCardSettings() => _openSettings();

  void _copyUid() {
    if (_uid == null) return;
    copyText(_uid.toString(), msg: 'UID 已复制');
  }

  void _showCheckInHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1a1a1a),
        title: const Text('签到说明', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('累计签到：${_checkInStatus['totalDays']} 天',
                style: const TextStyle(color: Colors.white70)),
            Text('连续签到：${_checkInStatus['consecutiveDays']} 天',
                style: const TextStyle(color: Colors.white70)),
            Text('今日排名：${_checkInStatus['rank'] ?? 0}',
                style: const TextStyle(color: Colors.white70)),
            Text(
              '今日${_checkInStatus['canCheckIn'] == true ? '可' : '已'}签到',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了',
                style: TextStyle(color: Color(0xffD7FF00))),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  bool get _isSelf => _profile?['isSelf'] == true;
  bool get _isHidden => _profile?['isHidden'] == true;
  bool get _profileHidden => _profile?['profileHidden'] == true;
  bool get _isFollowing => _profile?['isFollowing'] == true;

  int? get _uid {
    final raw = _profile?['userId'] ?? _profile?['uid'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String get _name =>
      (_profile?['name'] ?? _profile?['login'] ?? '匿名用户').toString();

  int get _level {
    final user = _profile?['user'] as Map?;
    final raw = user?['level'] ?? _profile?['level'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 1;
  }

  String get _bioText => AuthorModel.extractBioText(_profile?['bio']) ?? '';

  String? get _avatarUrl {
    final equipped =
        AuthorModel.extractAvatarUrl(_profile?['equippedAvatar']?['image']);
    if (equipped != null && equipped.isNotEmpty) return equipped;
    return AuthorModel.extractAvatarUrl(_profile?['avatar']);
  }

  String? get _bannerImageUrl {
    return AuthorModel.extractAvatarUrl(_profile?['equippedCard']?['image']);
  }

  Map<String, dynamic>? get _stats =>
      _profile?['stats'] as Map<String, dynamic>?;

  int _stat(String key) {
    final value = _stats?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get _followersCount {
    final value = _profile?['followersCount'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get _followingCount {
    final value = _profile?['followingCount'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _formatNumber(int n) {
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }

  Future<void> _openArticle(HDataModel item, DiscussionModel discussion) async {
    await showZZZDialog(
      context: context,
      pageBuilder: (context) => DiscussionPage(
        discussion: discussion,
        hData: item,
        reorderHistoryOnOpen: false,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xffD7FF00)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xff808080)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 640;
        final isDesktop = width >= 1024;
        final showBottomActions = isDesktop && _isSelf;

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopActionsRow(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 24,
                        vertical: isCompact ? 12 : 24,
                      ),
                      child: isCompact
                          ? _buildCompactContent()
                          : _buildDesktopContent(showBottomActions),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopActionsRow() {
    final canPop = Navigator.of(context).canPop();
    final isDialog = ModalRoute.of(context)?.barrierColor != null;
    final backButton = canPop
        ? IconButton(
            icon: Icon(
              isDialog ? Icons.close : Icons.arrow_back,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (!isDialog && backButton != null) backButton,
          const Spacer(),
          if (!_isSelf && !_isHidden)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xff1a1a1a),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'share', child: Text('分享主页')),
                const PopupMenuItem(value: 'report', child: Text('举报')),
              ],
              onSelected: (value) {
                if (value == 'share') _shareProfile();
                if (value == 'report') _reportUser();
              },
            ),
          if (isDialog && backButton != null) backButton,
        ],
      ),
    );
  }

  Widget _buildCompactContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: _buildFrame(isExpanded: false, isCompact: true),
    );
  }

  Widget _buildDesktopContent(bool showBottomActions) {
    return Column(
      children: [
        Expanded(child: _buildFrame(isExpanded: true, isCompact: false)),
        if (showBottomActions) ...[
          const SizedBox(height: 12),
          _buildBottomActions(),
        ],
      ],
    );
  }

  Widget _buildFrame({required bool isExpanded, required bool isCompact}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff2D2C2D),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _buildTabBar(isCompact),
              isExpanded
                  ? Expanded(
                      child: _buildAFrame(
                          isExpanded: true, isCompact: isCompact))
                  : _buildAFrame(isExpanded: false, isCompact: isCompact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAFrame({required bool isExpanded, required bool isCompact}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff010101), Color(0xff161616)],
        ),
      ),
      child: Column(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _buildBannerCard(isCompact),
          if (isExpanded)
            Expanded(
              child: _buildArticleGrid(
                isCompact: isCompact,
                isExpanded: true,
              ),
            )
          else
            _buildArticleGrid(
              isCompact: isCompact,
              isExpanded: false,
            ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────

  Widget _buildTabBar(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 20,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff161616), Color(0xff080808)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/tab-bg-point.webp',
              repeat: ImageRepeat.repeat,
              fit: BoxFit.none,
              alignment: Alignment.topLeft,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),
          Row(
            children: [
              _buildUidPill(isCompact),
              const Spacer(),
              _buildTabBarActions(isCompact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUidPill(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 14,
        vertical: isCompact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'UID:',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 12 : 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _uid?.toString() ?? '-',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 12 : 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 2),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _uid != null ? _copyUid : null,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy,
                  size: isCompact ? 13 : 14,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarActions(bool isCompact) {
    if (_isSelf) {
      return _buildActionButton(
        label: '更多操作',
        onTap: _openSettings,
        isCompact: isCompact,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isHidden)
          _buildActionButton(
            label: _isFollowing ? '已关注' : '关注',
            onTap: _isFollowingLoading ? null : _toggleFollow,
            isCompact: isCompact,
          ),
        if (!_isHidden) ...[
          const SizedBox(width: 8),
          _buildActionButton(
            label: '私信',
            onTap: _dmStarting ? null : _startDm,
            isCompact: isCompact,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onTap,
    required bool isCompact,
    bool isPrimary = false,
    bool highlight = false,
    bool loading = false,
  }) {
    return ZzzButton(
      size: isCompact ? ZzzButtonSize.small : ZzzButtonSize.defaults,
      type: isPrimary ? ZzzButtonType.success : ZzzButtonType.defaults,
      highlight: highlight,
      loading: loading,
      disabled: onTap == null,
      onPressed: onTap,
      label: label,
    );
  }

  // ── Banner Card ───────────────────────────────────────────────────

  Widget _buildBannerCard(bool isCompact) {
    return Container(
      margin: EdgeInsets.fromLTRB(isCompact ? 10 : 16, 12, isCompact ? 10 : 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xff2a2d33),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBanner(isCompact),
            _buildBannerFooter(isCompact),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(bool isCompact) {
    final avatarSize = isCompact ? 68.0 : 90.0;
    final borderWidth = isCompact ? 3.0 : 4.0;
    final badgeSize = isCompact ? 28.0 : 32.0;
    final nameFontSize = isCompact ? 22.0 : 30.0;

    return Stack(
      children: [
        Positioned.fill(child: _buildBannerBackground()),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: isCompact ? 220 : 240),
          padding: EdgeInsets.all(isCompact ? 18 : 36),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black,
                            width: borderWidth,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Avatar(_avatarUrl, size: avatarSize),
                      ),
                      Positioned(
                        top: -borderWidth,
                        left: -borderWidth,
                        child: Container(
                          constraints: BoxConstraints(minWidth: badgeSize),
                          height: badgeSize,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$_level',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 12 : 13,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: isCompact ? 14 : 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: isCompact ? 2 : 6),
                          child: Text(
                            _name,
                            style: TextStyle(
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: 0.5,
                              shadows: const [
                                Shadow(
                                  color: Color(0x66000000),
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: isCompact ? 8 : 10),
                        _buildTitleTag(isCompact),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isSelf && _profileHidden) ...[
                SizedBox(height: isCompact ? 12 : 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '个人资料已隐藏，仅自己可见',
                    style: TextStyle(
                      color: Color(0xffffcf3b),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              SizedBox(height: isCompact ? 18 : 24),
              _buildStatsRow(isCompact),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBannerBackground() {
    final url = _bannerImageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedImage(
        url: url,
        fit: BoxFit.cover,
        errorBuilder: (_) => Image.asset(
          'assets/images/pc-page-bg.png',
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      'assets/images/pc-page-bg.png',
      fit: BoxFit.cover,
    );
  }

  Widget _buildTitleTag(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        '暂无称号',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: isCompact ? 13 : 14,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isCompact) {
    final items = [
      ('浏览', _stat('totalViews')),
      ('评论', _stat('totalComments')),
      ('点赞', _stat('totalLikes')),
      ('关注', _followingCount),
      ('粉丝', _followersCount),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10),
                child: Text(
                  '-',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  items[i].$1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatNumber(items[i].$2),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                      Shadow(
                        color: Color(0x99000000),
                        offset: Offset(0, 0),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerFooter(bool isCompact) {
    final hasBio = _bioText.isNotEmpty;
    return ZzzPattern(
      type: ZzzPatternType.squares,
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 18 : 34,
          vertical: 8,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.black, width: 2),
          ),
        ),
        child: Text(
          hasBio ? _bioText : '这个人很神秘，什么都没有留下。',
          style: TextStyle(
            color: hasBio
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.35),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.5,
            fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ── Article Grid ──────────────────────────────────────────────────

  Widget _buildArticleGrid({
    required bool isCompact,
    required bool isExpanded,
  }) {
    if (_isHidden) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: const Text(
          '该用户已隐藏个人资料',
          style: TextStyle(
            color: Color(0xff555555),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (isCompact) {
      crossAxisCount = 2;
    } else if (width >= 1024) {
      crossAxisCount = 6;
    } else {
      crossAxisCount = 3;
    }

    return DiscussionGrid(
      list: _articles,
      hasNextPage: _hasMoreArticles,
      fetchData: _loadArticles,
      reorderHistoryOnOpen: false,
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: isCompact ? 10 : 12,
      crossAxisSpacing: isCompact ? 8 : 10,
      gridPadding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
      shrinkWrap: !isExpanded,
      physics: isExpanded ? null : const NeverScrollableScrollPhysics(),
      emptyMessage: '还没有发布任何内容哦',
      onOpenItem: (context, item, discussion) => _openArticle(item, discussion),
    );
  }

  // ── Bottom Actions (Desktop self) ─────────────────────────────────

  Widget _buildBottomActions() {
    final canCheckIn = _checkInStatus['canCheckIn'] == true;
    final totalDays = (_checkInStatus['totalDays'] as int?) ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _showCheckInHelp,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildActionButton(
              label: canCheckIn && !_checkInLoading
                  ? '今日签到${totalDays > 0 ? ' ($totalDays天)' : ''}'
                  : '已签到${totalDays > 0 ? ' ($totalDays天)' : ''}',
              onTap: _checkInLoading ? null : _doCheckIn,
              isCompact: false,
              highlight: true,
              loading: _checkInLoading,
            ),
          ],
        ),
        const SizedBox(width: 10),
        _buildActionButton(
          label: '修改头像',
          onTap: _openAvatarSettings,
          isCompact: false,
        ),
        const SizedBox(width: 10),
        _buildActionButton(
          label: '修改称号',
          onTap: null,
          isCompact: false,
        ),
        const SizedBox(width: 10),
        _buildActionButton(
          label: '修改勋章',
          onTap: null,
          isCompact: false,
        ),
        const SizedBox(width: 10),
        _buildActionButton(
          label: '修改名片',
          onTap: _openCardSettings,
          isCompact: false,
        ),
      ],
    );
  }
}
