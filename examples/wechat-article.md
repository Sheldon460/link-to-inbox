# 公众号归档示例

> 展示公众号文章归档后的标准 frontmatter + 正文结构。

## 归档后的文件结构

```
02.素材收件箱/02.微信文章/
├── 2026-08-15-WorkBuddy-Pinterest社媒作图Skill.md
└── images/
    └── 2026-08-15-WorkBuddy-Pinterest社媒作图Skill/
        ├── img_01.jpeg
        ├── img_02.jpeg
        └── img_03.jpeg
```

## Markdown 文件示例

```markdown
---
title: "Pinterest 社媒作图 Skill：从灵感到发布"
created: 2026-08-15
source: "公众号 - WorkBuddy 实验室"
source_url: "https://mp.weixin.qq.com/s/xxxxxxxxxxxxxxxx"
date: 2026-08-14
imported_at: 2026-08-15T10:32:18+08:00
tags:
  - 素材收件箱
  - 公众号
  - AI工具
  - 设计
type: inbox-raw
extraction_status: "WebFetch + curl; 8 张图片"
author: "松鼠AIGC"
images_path: "[[images/2026-08-15-WorkBuddy-Pinterest社媒作图Skill/]]"
---

# Pinterest 社媒作图 Skill：从灵感到发布

[正文内容...]

![img_01](images/2026-08-15-WorkBuddy-Pinterest社媒作图Skill/img_01.jpeg)

[正文继续...]
```

## 关键字段说明

- `source`：公众号名 + 作者名
- `images_path`：相对路径，所有图片都在同子目录
- `date`：原文发布日期（从微信文章头信息提取）

## 抓取流程

详见 [skill/SKILL.md 2.1 节](../skill/SKILL.md)：

1. WebFetch 拿正文（含标题、作者、发布日期、图片 URL）
2. curl 下载所有 `mmbiz.qpic.cn` 图片
3. 生成 .md + frontmatter + 内嵌图片引用

---

> **注意**：公众号图片链接有防盗链，本地下载后引用相对路径，不要保留远程 URL。