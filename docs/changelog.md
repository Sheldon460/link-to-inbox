# Changelog

link-to-inbox 的版本历史与重要变更。

## v1.7.0 (2026-08-24)

### 新增

- **知识星球支持** 🎉
  - URL 识别：`zsxq.com` / `wx.zsxq.com` / `articles.zsxq.com`
  - 抓取入口：`zsxq-cli topic +detail`（直连 API，无需网页抓取）
  - 归档目录：`15.知识星球/YYYY-MM-DD-作者-标题/`
  - frontmatter 专属字段：`topic_id`、`group_id`、`type`（talk/qa/task/solution）
  - JSON 字段映射表 + Python 附件下载脚本
  - 错误处理：401（token 过期）/ 403（不在目标星球）/ 主题删除

### 改动

- 总平台数：8 → 9（+1 通用网页 = 10 类）
- 工作流图新增 zsxq-cli 直连 API 分支
- URL 识别表新增 `zsxq-topic` content_type
- 错误处理表新增 3 行知识星球专属错误

### 文档

- README.md 平台支持表新增知识星球
- `examples/zsxq.md` 新增
- `docs/platform-matrix.md` 新增知识星球章节
- `docs/error-codes.md` 新增知识星球错误处理

---

## v1.6.1 (2026-08-18)

### 修复

- **dousnap React 同步问题**
  - 改用 `Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call()` 触发原生 setter
  - 按钮点击兼容 Vue/React 合成事件（`button.click()` + `dispatchEvent('mouse', click)`）
  - 等待 1.5 秒让 React 内部 state 更新（按钮 disabled → enabled）

### 改进

- 减少 dousnap 失败率（v1.6.0 偶发"no enabled btn"）

---

## v1.6.0 (2026-08-12)

### 新增

- **dousnap 统一入口** 🎉
  - 支持 7 个平台：抖音、小红书、快手、B站、视频号、TikTok、YouTube
  - 一次性拿到：标题 + 描述 + 【画面】【旁白】结构化文案 + 封面 + 视频下载
  - 完全免费、无需登录、无需人机验证
- **视频号优化**
  - 不再依赖 macOS 保存面板（远程无人值守）

### 改动

- 所有视频平台抓取流程统一为 dousnap 首选 + 平台兜底
- 移除过时的 `mpv` 强制依赖（改为可选）

---

## v1.5.0 (2026-07-xx)

### 新增

- **快手支持**：dousnap 入口

---

## v1.4.0 (2026-06-xx)

### 新增

- **YouTube 支持**：dousnap 入口
- **TikTok 支持**：dousnap 入口
- 归档目录新增 `14.海外/`

---

## v1.3.0 (2026-05-xx)

### 新增

- **视频号支持**（依赖 convry 解析）
  - 视频号场景痛点：macOS 保存面板导致远程无人值守失败
  - 兜底方案：浏览器自动操作
- 归档目录新增 `11.视频号/`

---

## v1.2.0 (2026-04-xx)

### 新增

- **B站支持**（yt-dlp + whisper.cpp）
  - B站默认 format 只有视频流，必须 `-f "bv*+ba"` 强制合并音轨
  - 复用本机 Chrome cookie 提升清晰度
- 归档目录新增 `13.B站/`

---

## v1.1.0 (2026-03-xx)

### 新增

- **抖音支持**（convry + Python）
  - 选最高清分辨率下载
  - 必须带 `Referer: https://www.douyin.com/` 否则 403
  - 用 `https://www.douyin.com/video/<视频ID>` 拿作者名
- 归档目录新增 `07.抖音视频/`

---

## v1.0.0 (2026-02-xx)

### 新增

- 公众号支持（WebFetch + curl）
- 小红书支持（chrome-direct 复用 Chrome 登录态）
- 通用网页支持（WebFetch 兜底）
- 归档目录：`02.微信文章/`、`03.小红书素材/`、`05.网页文字/`
- 飞书远程触发
- Obsidian frontmatter 标准

---

## 路线图（待规划）

- [ ] **微博**：dousnap 是否支持待验证
- [ ] **豆瓣**：文字为主，单独适配
- [ ] **Instagram**：海外平台，与 TikTok 类似
- [ ] **微信公众号视频**：iframe 嵌入，需要专门处理
- [ ] **本地优先模式**：用户可选择不抓视频，只抓文案
- [ ] **批量归档**：一次传入多个链接
- [ ] **AI 自动打标**：抓取后用 AI 自动生成 tags

---

## 反馈

提 Issue 或 PR：https://github.com/Sheldon460/link-to-inbox/issues