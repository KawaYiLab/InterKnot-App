/// 绳网等级累计绳网信用门槛（与后端 / Web 端一致，最高 Lv.7）
class LevelUtils {
  static const List<int> thresholds = [0, 500, 2000, 6000, 15000, 35000, 80000];

  static int get maxLevel => thresholds.length;

  static const Map<int, String> titles = {
    1: '新手绳匠',
    2: '见习绳匠',
    3: '正式绳匠',
    4: '资深绳匠',
    5: '精英绳匠',
    6: '传奇绳匠',
    7: '传说绳匠',
  };

  static int currentLevel(int exp) {
    var level = maxLevel;
    for (var i = 0; i < thresholds.length; i++) {
      if (exp < thresholds[i]) {
        level = i;
        break;
      }
    }
    return level.clamp(1, maxLevel);
  }

  static String titleFor(int level) {
    return titles[level] ?? titles[maxLevel]!;
  }

  /// 升到下一级在当前等级内还需要获得的绳网信用
  static int expNeededWithinLevel(int level) {
    if (level >= maxLevel) return 0;
    return thresholds[level] - thresholds[level - 1];
  }

  /// 当前等级的累计经验下限
  static int expAtLevel(int level) {
    if (level < 1) return 0;
    if (level > maxLevel) return thresholds.last;
    return thresholds[level - 1];
  }

  static int expToNextLevel(int currentExp) {
    final level = currentLevel(currentExp);
    if (level >= maxLevel) return 0;
    final currentThreshold = expAtLevel(level);
    final nextThreshold = expAtLevel(level + 1);
    return (nextThreshold - currentExp).clamp(0, nextThreshold - currentThreshold);
  }

  static double progress(int currentExp) {
    final level = currentLevel(currentExp);
    if (level >= maxLevel) return 1.0;
    final currentThreshold = expAtLevel(level);
    final nextThreshold = expAtLevel(level + 1);
    if (nextThreshold <= currentThreshold) return 1.0;
    return ((currentExp - currentThreshold) / (nextThreshold - currentThreshold))
        .clamp(0.0, 1.0);
  }

  static int nextLevelExp(int currentExp) {
    final level = currentLevel(currentExp);
    if (level >= maxLevel) return currentExp;
    return expAtLevel(level + 1);
  }
}
