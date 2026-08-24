# 一个 link-to-inbox，把 9 个平台的链接都收进 Obsidian

> 这篇文章讲三件事：我为什么要做这个技能、它能给你带来什么、它需要什么环境。
> 最后我会发出邀请：希望我们都能用一个技能、统一处理所有外部链接。

---

## 我为什么做这个技能

每天我打开手机，会在五个 App 之间跳跃——

- 公众号看到一篇深度方法论，想存到 Obsidian 里慢慢消化
- 小红书刷到一个工具清单，截图太散，想抓正文 + 图片
- 抖音看到一个 2 分钟的口播干货，文案比视频本身更值得反复看
- B 站收藏了一个技术教程，需要的是字幕，不是 ASR 转写
- 知识星球里星主分享了一份精读笔记，想存档但又不能直接复制

每次处理这些链接，我都要切到不同的工具：

- 公众号 → 用某个抓 HTML 的小工具
- 小红书 → 短链 token 经常过期，要换工具
- 抖音 → 又一个视频下载器
- B 站 → yt-dlp 拉下来，再 whisper 转写
- 知识星球 → 网页版复制粘贴

**问题是：这些工具之间不互通。**

今天抓的文案在 A 工具的笔记里，明天抓的视频在 B 工具的下载目录里。下次想找的时候，我要在五个工具之间来回翻。

更麻烦的是格式不统一。有的存 Markdown 但不带 frontmatter，有的存 HTML 看不了，有的存了图片但 Markdown 里是远程链接——一旦原图失效就 404。

我在做折叠屏那几年，技术团队会为这种「系统割裂」专门开会。轮到我自己的笔记流被割裂成五块，我才意识到：**这是同一件事**。

---

## 我做了什么

最初只是想给自己减负——把「粘链接 → 选工具 → 下载 → 归档」这套动作压成一个入口。

后来发现一些外部依赖可以复用：

- **[dousnap.com](https://www.dousnap.com/)（抖虫）** 一个站点就能同时处理抖音、小红书、快手、B站、视频号、TikTok、YouTube——免费、无登录、还自带【画面】【旁白】结构化输出
- **zsxq-cli** 是知识星球的官方 CLI，OAuth 登录后能直接拿到 JSON，比网页抓取稳定得多

把这些拼起来，**9 个平台**（公众号、小红书、抖音、快手、B站、视频号、TikTok、YouTube、知识星球）就只有一个技能入口。

我把整个过程打包成了一个 WorkBuddy Skill：**link-to-inbox**。

---

## 它能给你带来什么

不讲抽象好处，讲具体场景。

### 1. 一条对话粘链接就完事

在 WorkBuddy 对话里发：

> 帮我归档 https://www.bilibili.com/video/BVxxxxxxxxxx

AI 识别 domain → 调 dousnap → 拉视频 + 字幕 + 封面 → 写 Obsidian Markdown。

不用选工具，不用切窗口。

### 2. 飞书远程也能用

不在电脑前？在飞书给 WorkBuddy 机器人发链接，机器人归档后会把摘要（含归档位置 + 附件数）回给你。

我远程评测新工具的时候经常这么干——地铁上刷到干货，发链接，落地后直接在 Obsidian 里看到。

### 3. 视频自动出文字稿

抖音、B站、知识星球的视频抓回来后，技能会用 ffmpeg 提音频 + whisper.cpp 转写，单独存为「转录文本.md」。

- B 站走的是官方字幕（dousnap 自带），比 Whisper ASR 准得多
- 其他平台走 ASR，10 分钟视频大约 90 秒

### 4. 统一 frontmatter

每条归档都带：

```yaml
---
title: "..."
source: "平台 - 作者"
date: 原文发布日期
tags: [素材收件箱, 平台, ...]
type: inbox-raw
---
```

以后用 Dataview 检索、按平台筛选、按作者聚合，全都直接 query。

### 5. 不会丢图

小红书图片 URL 2 小时就过期，公众号图片防盗链，技能全部本地下载到 `media/` 子目录，Markdown 用相对路径引用。

断网也能看。

### 6. 开源、可改、可复用

整仓库在 GitHub：**https://github.com/Sheldon460/link-to-inbox**（MIT License）。

想加新平台？照着 `skill/SKILL.md` 模板写一个 `### 2.X` 章节就行。

---

## 你需要的环境

先说硬门槛：

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 12+ 或 Linux（Ubuntu 22.04+） |
| Python | 3.10+ |
| Node.js | 18+（给 zsxq-cli 用） |
| Obsidian | 本地 vault 或 iCloud 同步 |
| 磁盘 | 至少 10 GB（视频文件大） |

再列必备 CLI（macOS 一行装齐）：

```bash
brew install python ffmpeg node
pip3 install -U yt-dlp
npm install -g browser-act zsxq-cli
```

各工具职责：

- **browser-act**：浏览器自动化，驱动 dousnap 和本机 Chrome（抓小红书要复用你 Chrome 里的登录态）
- **yt-dlp**：B站视频下载（合并音视频流）
- **ffmpeg**：从视频里抽音频给 whisper
- **whisper.cpp**：本地语音转写（无需联网）
- **zsxq-cli**：知识星球 CLI，OAuth 登录一次就永久有效

Whisper 模型推荐 `ggml-large-v3-turbo.bin`（中文友好），放 `~/Models/whisper/` 即可。

### 安装 skill 本身

```bash
mkdir -p ~/.workbuddy/skills/link-to-inbox
cp skill/SKILL.md ~/.workbuddy/skills/link-to-inbox/
# 重启 WorkBuddy 即可用
```

完整文档（前置条件、平台覆盖、错误处理、贡献指南）都在仓库 README：

👉 **https://github.com/Sheldon460/link-to-inbox**

---

## 一个邀请

我做 link-to-inbox，不是为了炫技。

是因为我真心相信：**所有外部链接，都应该有自己的去处。**

你收藏了一篇文章、一个视频、一条星球笔记，是因为你相信它将来对你有用。

但如果这个「将来」来临时，你找不到它——那收藏的动作就等于浪费。

我想要的未来是这样的：

1. 看到一个链接 → 粘到对话里 → 它就自动进 Obsidian
2. 打开 Obsidian → 所有外链都集中在一个地方
3. 想用某个素材 → 按平台、按作者、按日期筛 → 直接找到

不需要再装 9 个插件，不需要切换 9 个工具。

**一个技能、一个入口、一个 Obsidian 收件箱。**

如果你也有这个痛，欢迎体验：

- ⭐ 仓库：https://github.com/Sheldon460/link-to-inbox
- 📖 README：装一遍流程、平台覆盖、错误处理
- 💬 Issue：踩坑或想加新平台，提 Issue 或评论都可以

克隆下来照 README 装一遍，30 分钟内能跑通第一条归档。

希望 link-to-inbox 能帮你把「外链」真正变成「自己的素材」，而不只是躺在收藏夹里。

---

_本文同步发布于：WorkBuddy 实验室公众号 / 个人知识星球 / GitHub 仓库 README。_