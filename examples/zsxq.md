# 知识星球归档示例

> 展示知识星球主题归档后的标准 frontmatter + 正文结构（v1.7.0 新增）。

## 归档后的文件结构

```
02.素材收件箱/15.知识星球/
└── 2026-08-20-希尔顿-WorkBuddy入门指南从灵感到发布/
    ├── 2026-08-20-希尔顿-WorkBuddy入门指南从灵感到发布.md
    └── media/                          # 仅含图片时才有
        ├── img_1.jpg
        └── img_2.jpg
```

## Markdown 文件示例

```markdown
---
title: "WorkBuddy 入门指南：从灵感到发布"
created: 2026-08-24
source: "知识星球 - AI 提效圈 · 希尔顿"
source_url: "https://wx.zsxq.com/group/123456789/topic/789012345"
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
topic_id: "789012345"
group_id: "123456789"
images_path: "[[media/]]"
---

# WorkBuddy 入门指南：从灵感到发布

## 正文内容

从灵感捕捉到最终发布，WorkBuddy 提供 5 个核心环节的 AI 辅助...

![img_1](media/img_1.jpg)

## 主题元信息

- **主题 ID**：789012345
- **所属星球**：AI 提效圈（group_id: 123456789）
- **主题类型**：talk（普通图文帖）
- **发布时间**：2026-08-20 09:19
- **互动数据**：12 评论 / 48 点赞 / 200 阅读
- **是否精华**：false
```

## 关键字段说明

- `topic_id` / `group_id`：知识星球专属字段，便于后续按主题类型筛选
- `type`：talk / qa / task / solution（4 种主题类型）
- `source`：星球名 + 作者名（双层定位）

## 抓取流程

详见 [skill/SKILL.md 2.6 节](../skill/SKILL.md)：

1. URL 正则提取 `topic_id`（兼容电脑端 + 手机端链接）
2. `zsxq-cli topic +detail --topic-id <id>` 拿结构化 JSON
3. （可选）`get_topic_comments` 拿评论列表
4. Python 下载 `cdn.zsxq.com` 图片到 `media/` 子目录
5. 生成 .md + frontmatter

## 错误处理

| 错误码 | 含义 | 处理 |
|--------|------|------|
| 401 | token 过期 | `zsxq-cli auth login` 重新走 OAuth 设备码 |
| 403 | 当前账户不在目标星球 | 切换账户或加入星球 |
| 主题不存在 | 主题被星主删除 | 如实告知，不假装完成 |

---

> **核心优势**：直接走 `zsxq-cli` API 拿 JSON，比网页抓取稳定，且无登录态失效风险。