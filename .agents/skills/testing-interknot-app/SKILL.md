---
name: testing-interknot-app
description: Run and test the InterKnot-App (Flutter) against the ikserver dev backend. Use when verifying App API/UI changes end-to-end.
---

# Testing InterKnot-App

## 运行环境选择（重要）
- **不要用 Flutter Web 测试**：`lib/main.dart` 等处直接调用 `dart:io` 的 `Platform.isAndroid`，Web 启动即抛异常白屏（可能未来加了 `kIsWeb` 守卫后可用，先小成本试一下再决定）。
- **推荐 Linux 桌面版**：
  ```bash
  sudo apt-get update && sudo apt-get install -y cmake ninja-build clang libgtk-3-dev pkg-config wmctrl
  flutter create . --platforms linux   # 生成 linux/ 平台文件（勿提交）
  flutter build linux --release
  DISPLAY=:0 ./build/linux/x64/release/bundle/inter_knot &
  DISPLAY=:0 wmctrl -r inter_knot -b add,maximized_vert,maximized_horz
  ```
- 登录态（token）持久化在本机，重启应用后仍保持登录。

## 后端指向
- 临时修改 `lib/constants/api_config.dart` 的 `baseUrl` 指向 dev 后端 `http://43.248.77.159:31338`（映射到测试机 43.248.77.180:1338）。**该改动勿提交**。
- 生产路径 `/www/wwwroot/ikserver` 永远不要动；dev 为 `/www/wwwroot/ikserverdev`。

## 测试账号
- devin_test / devin_test@example.com / DevinTest123456（user id 182，author documentId ut85xgkfqlq3btbo53i8n1uu，dev 库）。
- 扣丁尼操作（改名/头像各 10 丁尼）会耗尽余额；可 SSH 到测试机用 MySQL（库 ikdev，凭据在 `/www/wwwroot/ikserverdev/.env`）补：
  `UPDATE up_users SET denny=100 WHERE id=182;`

## 已知易错点 / 排查思路
- App 的 GET `/api/articles|comments|profiles` 默认**不带 token**（见 `lib/api/api.dart` 的 requestModifier）。需要登录态的 GET（如 `feed=favorites`）必须显式传 Authorization header。
- 收藏列表应走 `GET /api/articles/list?feed=favorites`（与 Web 一致）；`/api/favorites/list` 可能只返回 `article.documentId` 甚至 null，不足以渲染卡片。
- authorId 必须来自 `/api/me/profile` 的 `author.documentId`；`/api/users/me?populate=*` **不含** author 关联，勿用 user documentId 兜底。
- 验证接口行为可用 curl：`POST /api/auth/local` 拿 jwt 后带 Bearer 调试各端点。

## Devin Secrets Needed
- 无专用 secret；测试机 SSH 凭据与测试账号见组织知识库（ikserver后端测试机连接）。
