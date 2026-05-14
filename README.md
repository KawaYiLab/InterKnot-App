# 绳网 (InterKnot)

<p align="center">
  <img src="icon.webp" alt="Inter-Knot Logo" width="120" />
</p>

<p align="center">
  <strong>模仿制作的「绝区零」世界观中的"绳网"——新艾利都最大的匿名委托中枢。</strong>
</p>

<p align="center">
  <a href="https://github.com/yinengbei/inter-knot/actions"><img src="https://img.shields.io/github/actions/workflow/status/yinengbei/inter-knot/android.yml?label=Android%20Build" alt="Android Build"></a>
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-≥3.4.4-0175C2?logo=dart" alt="Dart">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/yinengbei/inter-knot" alt="License"></a>
</p>

本项目基于 [share121/inter-knot](https://github.com/share121/inter-knot) 二开，采用自建 Strapi 后端提供数据服务，支持 **Android / iOS** 平台。

> ⚠️ **Web 端与桌面端（Windows / macOS / Linux）已停止维护，不再提供支持。**

> 📱 Web端请前往 [KawaYiLab/InterKnot-Web](https://github.com/KawaYiLab/InterKnot-Web)

---

## ✨ 功能

- **帖子系统** — 发帖、评论、回复，支持富文本 & Markdown
- **用户体系** — 注册登录、等级经验、个人主页
- **消息通知** — 实时通知提醒
- **图片处理** — 上传压缩、图片预览、瀑布流展示
- **应用更新** — 内置版本检测与更新提示

---

## 🛠️ 技术栈

| 层级 | 技术 |
|------|------|
| **框架** | [Flutter](https://flutter.dev/)（Dart SDK ≥ 3.4.4） |
| **状态管理 & 路由** | [GetX](https://pub.dev/packages/get) |
| **网络层** | [Dio](https://pub.dev/packages/dio) / [http](https://pub.dev/packages/http) |
| **富文本编辑** | [flutter_quill](https://pub.dev/packages/flutter_quill) |
| **Markdown 渲染** | [markdown_widget](https://pub.dev/packages/markdown_widget) |
| **本地存储** | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| **图片处理** | [cached_network_image](https://pub.dev/packages/cached_network_image) / [flutter_image_compress](https://pub.dev/packages/flutter_image_compress) |
| **后端** | [Strapi v5](https://strapi.io/)（RESTful API） |

---

## 🚀 快速开始

### 1. 环境准备

- Flutter SDK（stable channel）
- Android Studio 或 VS Code

### 2. 拉取代码

```bash
git clone https://github.com/yinengbei/inter-knot.git
cd inter-knot
```

### 3. 安装依赖

```bash
flutter pub get
```

### 4. 配置后端（可选）

默认连接到 `ik.tiwat.cn`，如需使用自建后端，请修改 `lib/constants/api_config.dart`：

```dart
class ApiConfig {
  static const String baseUrl = 'https://your-server.com';
}
```

### 5. 运行

```bash
# Android
flutter run -d android
```

---

## 📂 目录结构

```
lib/
├── api/            # API 接口封装
├── components/     # 可复用 UI 组件
├── constants/      # 常量与配置
├── controllers/    # 业务逻辑（GetX Controller）
├── gen/            # 自动生成资源（flutter_gen）
├── helpers/        # 工具函数
├── models/         # 数据模型
├── pages/          # 页面视图
├── services/       # 服务层（验证码、更新检测等）
└── main.dart       # 应用入口
```

---

## 🔄 CI / CD

| 工作流 | 说明 |
|--------|------|
| `android.yml` | 打 tag 时构建 Android APK 并上传 Artifact |

---

## ✅ 路线图

- [x] 用户经验 & 等级体系
- [x] 重构个人主页
- [ ] 前端整体风格向「绝区零 · 绳网」靠拢

---

## 🤝 贡献指南

欢迎提交 Issue 或 Pull Request，一起完善绳网。

> ⚠️ **注意**：本项目使用Claude Opus 4.6辅助开发，使用前请自行评估。

---

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。

```
Copyright (c) 2024 share121
Copyright (c) 2026 KawaYi
```
