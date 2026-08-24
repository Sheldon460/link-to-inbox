# link-to-inbox 📥

> **跨平台链接自动归档到 Obsidian 素材收件箱**
> 粘一个链接（公众号/小红书/抖音/快手/B站/视频号/TikTok/YouTube/知识星球），自动识别平台、抓取完整内容（标题+描述+口播文案+封面+视频）、按格式归档到 Obsidian。

[![Platforms](https://img.shields.io/badge/platforms-9-blue)](#-平台支持)
[![Obsidian](https://img.shields.io/badge/Obsidian-兼容-7c3aed)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![WorkBuddy Skill](https://img.shields.io/badge/WorkBuddy-Skill-green)](#)

---

## ✨ 特性

- **9 平台一键归档**：公众号、小红书、抖音、快手、B站、视频号、TikTok、YouTube、知识星球
- **结构化输出**：统一 frontmatter（title / source / date / tags / type）+ 正文
- **附件自动下载**：图片、视频、音频全部抓到本地，Markdown 内嵌引用
- **智能入口选择**：
  - 7 个视频/图文平台走 [dousnap.com](https://www.dousnap.com/)（免费、无登录、带【画面】【旁白】结构）
  - 公众号走 WebFetch + curl（结构化 HTML 抓取）
  - 知识星球走 `zsxq-cli` 直连 API（最稳定）
- **飞书远程触发**：在飞书发链接给机器人即可归档，回复摘要到飞书
- **可重复执行**：相同链接二次抓取覆盖原文件，便于刷新内容

---

## 📦 平台支持

| 平台 | Domain 识别 | 主路径 | 兜底路径 | 归档目录 |
|------|------------|--------|---------|---------|
| 公众号 | `mp.weixin.qq.com` | WebFetch + curl | — | `02.微信文章/` |
| 小红书 | `xhslink.com` / `xiaohongshu.com` | dousnap | chrome-direct | `03.小红书素材/` |
| 抖音 | `douyin.com` / `v.douyin.com` | dousnap | convry + whisper.cpp | `07.抖音视频/` |
| 快手 | `v.kuaishou.com` / `kuaishou.com` | dousnap | — | `12.快手/` |
| 视频号 | `channels.weixin.qq.com` | dousnap（绕开 macOS 保存面板） | convry | `11.视频号/` |
| B站 | `bilibili.com` / `b23.tv` | dousnap（官方字幕更准） | yt-dlp + whisper.cpp | `13.B站/` |
| TikTok | `tiktok.com` | dousnap | — | `14.海外/` |
| YouTube | `youtube.com` / `youtu.be` | dousnap | — | `14.海外/` |
| 知识星球 | `zsxq.com` / `wx.zsxq.com` | `zsxq-cli topic +detail` | — | `15.知识星球/` |
| 通用网页 | 其他 | WebFetch | — | `05.网页文字/` |

---

## 🔧 前置条件

### 系统要求

- **操作系统**：macOS 12+ / Linux（Ubuntu 22.04+）
- **Python**：3.10+
- **Node.js**：18+（用于 zsxq-cli）
- **Obsidian**：本地 vault + iCloud 同步 或 本地 vault
- **磁盘空间**：≥ 10 GB（视频文件较大）

### 必备工具

| 工具 | 用途 | 安装 |
|------|------|------|
| `curl` | 下载图片、视频 | macOS/Linux 自带 |
| `python3` | 复杂下载逻辑、文件处理 | `brew install python` / `apt install python3` |
| `browser-act` | 浏览器自动化（dousnap、chrome-direct） | `npm install -g browser-act` |
| `yt-dlp` | B站视频下载 | `pip install -U yt-dlp` |
| `ffmpeg` | 音频提取（视频转写前置） | `brew install ffmpeg` |
| `whisper-cli` | Whisper.cpp 命令行（视频口播转写） | 见 [whisper.cpp 安装](#whisper-cpp-安装) |
| `zsxq-cli` | 知识星球 CLI（v0.5.0+） | 见 [zsxq-cli 安装](#zsxq-cli-安装) |

### 可选工具

| 工具 | 用途 | 安装 |
|------|------|------|
| `markitdown` | 把 Office/PDF 转 Markdown | `pip install markitdown` |
| `mpv` | 视频预览（归档前确认） | `brew install mpv` |

---

## 📥 安装教程

### 1. 克隆仓库

```bash
git clone https://github.com/Sheldon460/link-to-inbox.git
cd link-to-inbox
```

### 2. 安装必备 CLI 工具

#### macOS（推荐 Homebrew）

```bash
# 基础工具
brew install python ffmpeg

# Node.js（如未安装）
brew install node

# yt-dlp
pip3 install -U yt-dlp

# browser-act
npm install -g browser-act

# mpv（可选）
brew install mpv
```

#### Linux（Ubuntu/Debian）

```bash
sudo apt update
sudo apt install -y python3 python3-pip curl ffmpeg nodejs npm mpv
pip3 install -U yt-dlp
npm install -g browser-act
```

### 3. 安装 whisper.cpp（视频口播转写）

```bash
# macOS
brew install whisper-cpp

# 或源码编译
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
make -j
# 下载中文 large 模型（推荐 ggml-large-v3-turbo.bin）
bash ./models/download-ggml-model.sh large-v3-turbo
```

### 4. 安装 zsxq-cli（知识星球）

```bash
npm install -g zsxq-cli
zsxq-cli auth login   # 首次使用需 OAuth 设备码登录
```

### 5. 安装 Skill 到 WorkBuddy

将 `skill/SKILL.md` 复制到 WorkBuddy 的 skills 目录：

```bash
# WorkBuddy 全局 skills 目录
mkdir -p ~/.workbuddy/skills/link-to-inbox
cp skill/SKILL.md ~/.workbuddy/skills/link-to-inbox/

# 或项目级
mkdir -p /path/to/your/project/.workbuddy/skills/link-to-inbox
cp skill/SKILL.md /path/to/your/project/.workbuddy/skills/link-to-inbox/
```

重启 WorkBuddy 即可识别。

---

## 🚀 使用方法

### 基础用法

在 WorkBuddy 对话中发一个链接：

```
帮我归档这个视频到素材收件箱
https://www.bilibili.com/video/BVxxxxxxxxxx
```

或直接发链接（带"归档/抓取/存到收件箱"等关键词）：

```
归档 https://mp.weixin.qq.com/s/xxxxx
```

AI 会自动：
1. 识别 URL domain → 匹配平台
2. 调用对应平台的抓取流程（dousnap / WebFetch / zsxq-cli）
3. 下载附件到 `02.素材收件箱/<平台子目录>/`
4. 生成 `.md` 文件（带 frontmatter）
5. 回复摘要（标题/作者/归档位置/附件数量）

### 飞书远程触发

在飞书对话中把链接发给 WorkBuddy 机器人，机器人识别后自动归档，完成后回复摘要到飞书。

### 输出示例

```markdown
---
title: "WorkBuddy 入门指南：从灵感到发布"
created: 2026-08-24
source: "知识星球 - AI 提效圈 · 希尔顿"
source_url: "https://wx.zsxq.com/group/123456/topic/789012"
date: 2026-08-20
imported_at: 2026-08-24T17:58:00+08:00
tags:
  - 素材收件箱
  - 知识星球
  - AI 提效圈
  - talk
type: inbox-raw
extraction_status: "zsxq-cli topic +detail; 12/48 评论/点赞"
author: 希尔顿
topic_id: "789012"
group_id: "123456"
images_path: "[[media/]]"
---

# WorkBuddy 入门指南：从灵感到发布

[正文内容...]
```

---

## ⚙️ 配置

### Vault 路径

默认归档目录（macOS）：

```
/Users/<用户名>/Library/Mobile Documents/iCloud~md~obsidian/Documents/02.素材收件箱
```

可在 `skill/SKILL.md` 的 `## Vault 路径` 章节修改为本地 vault：

```
/Users/<用户名>/Documents/ObsidianVault/02.素材收件箱
```

### Chrome 登录态

- **小红书抓取**：本机 Chrome 必须已登录小红书（chrome-direct 模式复用登录态）
- **B站抓取**：本机 Chrome 必须已登录 B站（非会员只能下 480P）

### 文件名规范

```
<YYYY-MM-DD>-<作者/来源>-<标题截取30字以内>.md
```

- 日期：原文发布日期，取不到用抓取日期
- 标题：清理特殊字符（`/`、`\`、`:`、`*`、`?`、`<`、`>`、`|`）

---

## 🗂 项目结构

```
link-to-inbox/
├── README.md              # 本文件
├── LICENSE                # MIT 许可证
├── .gitignore             # Git 忽略配置
├── skill/
│   └── SKILL.md           # WorkBuddy Skill 主文件（核心）
├── examples/
│   ├── wechat-article.md  # 公众号归档示例
│   ├── xiaohongshu.md     # 小红书归档示例
│   ├── douyin.md          # 抖音归档示例
│   └── zsxq.md            # 知识星球归档示例
└── docs/
    ├── platform-matrix.md # 平台覆盖矩阵
    ├── error-codes.md     # 错误码处理表
    └── changelog.md       # 版本历史
```

---

## 🔍 故障排查

### 链接无法访问 / 403

- 公众号：可能被微信限制，用 WebFetch 失败时回退浏览器抓取
- 小红书：分享链接 `xsec_token` 过期（错误 300031），用站内搜索方案（详见 SKILL.md 2.2 节）

### 视频号无法下载（macOS 保存面板）

- 已通过 dousnap 入口绕过此问题，**确认链接是 `channels.weixin.qq.com` 域**
- 若走 convry 兜底仍弹保存面板，远程操作需手动点保存

### 知识星球 401/403

```bash
# 401 token 过期
zsxq-cli auth login

# 403 当前账户不在目标星球
# 切换账户或加入对应星球
```

### Whisper 转写失败

```bash
# 检查模型路径
ls -lh ~/Models/whisper/ggml-large-v3-turbo.bin

# 检查 ffmpeg
ffmpeg -version | head -1
```

### vault 目录不存在

skill 会自动 `mkdir -p`，但 iCloud vault 需先在 Obsidian 客户端打开过该目录。

---

## 🤝 贡献指南

欢迎提 PR 加新平台支持！新增平台需要修改：

1. `skill/SKILL.md` 的 frontmatter description 加入平台名
2. 工作流总览图加入分支
3. 归档目录映射表加入行
4. URL 识别表加入行
5. Python 判断逻辑加入分支
6. 新增 `### 2.X` 章节（抓取流程）
7. frontmatter 适配（如有专属字段）
8. 更新 README.md 平台覆盖表
9. 加示例到 `examples/`

提 PR 前请：

- 在本地用真实链接测试一遍抓取流程
- 更新 `docs/changelog.md` 版本号

---

## 📜 许可证

[MIT License](LICENSE) © 2026 Sheldon460

---

## 🙏 致谢

- [dousnap.com](https://www.dousnap.com/) — 统一的视频文案提取站点（核心依赖）
- [WorkBuddy](https://workbuddy.cn) — AI 工作伙伴平台
- [Obsidian](https://obsidian.md) — 本地优先的笔记工具
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — 本地语音转写
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — 视频下载工具

---

## 📊 统计

- **支持平台**：9 + 通用网页
- **核心入口**：dousnap + WebFetch + zsxq-cli 三入口协同
- **最新版本**：v1.7.0（2026-08-24 加入知识星球）

---

**如果这个 skill 对你有帮助，欢迎 Star ⭐️**