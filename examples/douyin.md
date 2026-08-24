# 抖音归档示例

> 展示抖音视频归档后的标准 frontmatter + 转写结构。

## 归档后的文件结构

```
02.素材收件箱/07.抖音视频/
└── 2026-08-11-某账号-某视频标题/
    ├── 2026-08-11-某账号-某视频标题.md
    ├── 视频文件.mp4
    └── 转录文本.md
```

## Markdown 文件示例

```markdown
---
title: "如何用 WorkBuddy 半小时搞定一天的工作"
created: 2026-08-11
source: "抖音 - AI提效实验室"
source_url: "https://v.douyin.com/xxxxxxx"
date: 2026-08-09
imported_at: 2026-08-11T18:24:15+08:00
tags:
  - 素材收件箱
  - 抖音
  - AI工具
  - 效率
type: inbox-raw
extraction_status: "dousnap; 1 视频 + 1 封面; 8.2k 赞"
author: "AI提效实验室"
duration: "00:02:34"
images_path: "[[视频文件.mp4]]"
---

# 如何用 WorkBuddy 半小时搞定一天的工作

## 视频信息

- **时长**：2 分 34 秒
- **作者**：AI提效实验室
- **发布时间**：2026-08-09

## 视频文件

[下载文件](视频文件.mp4)

## 口播文案（Whisper 转写）

[00:00] 大家好，今天分享一个我用 WorkBuddy 半小时搞定一天工作的方法。
[00:15] 第一步是...

## 关键画面

- 00:00 - 开场白 + 工具 logo
- 00:15 - 第一步操作演示
- 02:00 - 成果展示
```

## 转录文本结构

```markdown
---
title: "如何用 WorkBuddy 半小时搞定一天的工作 - 转录"
generated_at: 2026-08-11T18:24:50+08:00
model: "whisper-large-v3-turbo"
language: "zh"
source_file: "视频文件.mp4"
duration: "00:02:34"
---

[00:00] 大家好...

[转录内容...]
```

## 抓取流程

详见 [skill/SKILL.md 2.3 节](../skill/SKILL.md)：

1. dousnap 首选（拿标题+描述+【画面】【旁白】+封面+视频）
2. convry 兜底解析视频地址
3. ffmpeg 提取音频 → whisper.cpp 转写 → 保存为 `转录文本.md`

---

> **关键发现**：dousnap 自带【画面】【旁白】结构化输出，可直接复用为口播稿，比 Whisper ASR 准确度更高。