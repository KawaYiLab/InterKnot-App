<!--
╔══════════════════════════════════════════════════════════════════════╗
║  DreamSeed 种梦计划 — AI创造者大赛  官方 README 模板                ║
║                                                                      ║
║  使用说明：                                                          ║
║  1. 将本模板放在参赛仓库根目录 README.md 的顶部                       ║
║  2. 头图使用 DreamField 官方公开活动图片地址                         ║
║  3. 请保留 DREAMFIELD_README_HEADER_START / END 标识                 ║
║  4. 分割线以下供创作者自由编写项目内容                               ║
╚══════════════════════════════════════════════════════════════════════╝
-->

<!-- DREAMFIELD_README_HEADER_START -->

<p align="center">
  <a href="https://www.dreamfield.top">
    <img src="https://www.dreamfield.top/dream-field/contest-readme/assets/dreamseed-readme-banner.png" alt="DreamSeed 种梦计划参赛作品" width="100%" />
  </a>
</p>

<!-- DREAMFIELD_README_HEADER_END -->

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
## 🤝 贡献指南

欢迎提交 Issue 或 Pull Request，一起完善绳网。

---


## ❤️ 致谢

本项目从零开始开发，在实现过程中参考了许多优秀的开源项目与社区资源。

特别感谢：

* share121 开源的 Inter-Knot 项目
  https://github.com/share121/inter-knot

* ChrisChan13 开发的 zenless-ui 组件库
  https://github.com/ChrisChan13/zenless-ui

* Alver 提供的部分 UI 设计参考与图片资源
  https://zenless.tools/

* 所有提交 Issue、Pull Request、反馈问题或提供建议的开发者与用户

同时感谢开源社区以及 AI 工具在开发过程中提供的帮助与支持。

