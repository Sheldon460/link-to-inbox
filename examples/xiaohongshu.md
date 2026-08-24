# 小红书归档示例

> 展示小红书帖子归档后的标准 frontmatter + 正文结构。

## 归档后的文件结构

```
02.素材收件箱/03.小红书素材/
└── AI工具/
    └── 2026-08-11-某博主-AI工具推荐/
        ├── 2026-08-11-某博主-AI工具推荐.md
        └── media/
            ├── img_1.webp
            ├── img_2.webp
            └── img_3.webp
```

## Markdown 文件示例

```markdown
---
title: "这 3 个 AI 工具让我效率翻倍"
created: 2026-08-11
source: "小红书 - AI工具推荐官"
source_url: "https://www.xiaohongshu.com/explore/xxxxxxxxxxxxx"
date: 2026-08-10
imported_at: 2026-08-11T16:42:33+08:00
tags:
  - 素材收件箱
  - 小红书
  - AI工具
  - 效率
type: inbox-raw
extraction_status: "dousnap; 9 张图片; 2.4k 赞"
author: "AI工具推荐官"
images_path: "[[media/]]"
---

# 这 3 个 AI 工具让我效率翻倍

![img_1](media/img_1.webp)
![img_2](media/img_2.webp)

[正文内容...]

标签：#AI工具 #效率提升 #干货分享
```

## 关键字段说明

- `source`：小红书用户名
- `tags`：含原始话题标签
- `images_path`：所有图片在 `media/` 子目录，按顺序命名 `img_1.webp`
- `extraction_status`：抓取摘要（含 dousnap / chrome-direct 标记 + 互动数据）

## 抓取流程

详见 [skill/SKILL.md 2.2 节](../skill/SKILL.md)：

1. dousnap 首选（拿到标题+正文+标签+封面）
2. chrome-direct 兜底（复用本机 Chrome 登录态）
3. 站内搜索方案处理 `xsec_token` 过期（错误 300031）
4. Python 下载图片到 `media/` 子目录

---

> **注意**：小红书短链 `xhslink.cn` 直接打开即可；图片 URL 有效期约 2 小时，下载要趁早。