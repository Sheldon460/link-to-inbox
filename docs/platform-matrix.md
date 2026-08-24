# 平台覆盖矩阵

> 本文档详细列出 link-to-inbox 支持的所有平台、识别规则、抓取能力、附件类型。

## 平台总览

| # | 平台 | Domain | 识别难度 | 抓取稳定性 | 视频下载 | 字幕转写 | 备注 |
|---|------|--------|---------|-----------|---------|---------|------|
| 1 | 公众号 | `mp.weixin.qq.com` | ⭐ | ⭐⭐⭐⭐⭐ | ❌ | ❌ | WebFetch + curl |
| 2 | 小红书 | `xhslink.com` / `xiaohongshu.com` | ⭐⭐⭐ | ⭐⭐⭐⭐ | ❌ | ❌ | chrome-direct 需登录 |
| 3 | 抖音 | `douyin.com` / `v.douyin.com` | ⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | ✅ | dousnap 结构化输出 |
| 4 | 快手 | `v.kuaishou.com` / `kuaishou.com` | ⭐⭐ | ⭐⭐⭐⭐ | ✅ | ✅ | dousnap 新增 |
| 5 | B站 | `bilibili.com` / `b23.tv` | ⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | ✅ | 官方字幕优于 ASR |
| 6 | 视频号 | `channels.weixin.qq.com` | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | ✅ | 绕开 macOS 保存面板 |
| 7 | TikTok | `tiktok.com` | ⭐⭐ | ⭐⭐⭐⭐ | ✅ | ✅ | dousnap 新增 |
| 8 | YouTube | `youtube.com` / `youtu.be` | ⭐ | ⭐⭐⭐⭐ | ✅ | ✅ | dousnap 新增 |
| 9 | 知识星球 | `zsxq.com` / `wx.zsxq.com` | ⭐ | ⭐⭐⭐⭐⭐ | ❌ | ❌ | zsxq-cli API 直连 |
| 10 | 通用网页 | 其他 | — | ⭐⭐⭐ | ❌ | ❌ | WebFetch 兜底 |

## 详细能力对照

### 公众号 (mp.weixin.qq.com)

- **入口**：WebFetch + curl
- **可抓取**：标题、作者、公众号名、发布日期、正文、所有 `mmbiz.qpic.cn` 图片
- **不可抓**：视频（公众号视频走 iframe 嵌入，无法直接下载）
- **目录**：`02.微信文章/images/YYYY-MM-DD-作者-标题/`
- **frontmatter 特有字段**：`images_path`

### 小红书 (xhslink.com / xiaohongshu.com)

- **入口**：dousnap（首选）/ chrome-direct（兜底）
- **可抓取**：标题、正文、话题标签、发布日期、作者、所有图片、点赞评论数
- **注意**：
  - 短链接 `xsec_token` 可能过期（错误 300031），用站内搜索方案
  - 图片 URL 有效期约 2 小时
- **目录**：`03.小红书素材/<分类>/YYYY-MM-DD-作者-标题/media/`

### 抖音 (douyin.com / v.douyin.com)

- **入口**：dousnap（首选）/ convry（兜底）
- **可抓取**：标题、描述、【画面】【旁白】结构化文案、封面、多分辨率视频、口播转写
- **视频来源**：下载到本地后用 ffmpeg 提取音频 → whisper.cpp 转写
- **目录**：`07.抖音视频/YYYY-MM-DD-作者-标题/`

### 快手 (v.kuaishou.com / kuaishou.com)

- **入口**：dousnap
- **可抓取**：标题、描述、文案、封面、视频
- **目录**：`12.快手/YYYY-MM-DD-作者-标题/`

### B站 (bilibili.com / b23.tv)

- **入口**：dousnap（首选，官方字幕更准）/ yt-dlp（兜底）
- **可抓取**：标题、UP主、字幕（官方）、视频（合并音视频）
- **注意**：非会员只能下载 480P；1080P 60帧需大会员
- **目录**：`13.B站/YYYY-MM-DD-作者-标题/`

### 视频号 (channels.weixin.qq.com)

- **入口**：dousnap（首选，绕开 macOS 保存面板）/ convry（兜底）
- **可抓取**：标题、描述、文案、封面、视频
- **关键优化**：dousnap 解决了视频号必须依赖 macOS 保存面板的痛点
- **目录**：`11.视频号/YYYY-MM-DD-作者-标题/`

### TikTok / YouTube (海外平台)

- **入口**：dousnap
- **可抓取**：标题、描述、文案、封面、视频
- **目录**：`14.海外/YYYY-MM-DD-作者-标题/`

### 知识星球 (zsxq.com / wx.zsxq.com)

- **入口**：`zsxq-cli topic +detail`（直连 API）
- **可抓取**：主题正文、发布者、点赞数、评论数、阅读数、标签、发布时间
- **不可抓**：评论列表（需另外调用 `get_topic_comments`）
- **关键优势**：JSON 结构化数据，无需网页抓取
- **目录**：`15.知识星球/YYYY-MM-DD-作者-标题/`
- **frontmatter 特有字段**：`topic_id`、`group_id`、`type`（talk/qa/task/solution）

### 通用网页 (fallback)

- **入口**：WebFetch
- **可抓取**：正文（依赖页面结构）
- **目录**：`05.网页文字/`

## 抓取稳定性策略

```
首选入口（dousnap / zsxq-cli API）
  ↓ 降级
平台专属工具（chrome-direct / yt-dlp / convry）
  ↓ 降级
通用 WebFetch
  ↓ 降级
告知用户手动操作
```

每层失败都有明确日志，便于排错。

---

## 扩展平台指南

如需新增平台支持，按以下流程：

1. 在 dousnap 检查是否已支持该平台
2. 检查平台是否有公开/半公开 API（如 zsxq-cli）
3. 编写 `### 2.X` 章节，遵循现有模板：
   - URL 格式识别
   - 抓取流程（带完整命令）
   - JSON 字段映射表
   - 附件下载脚本
   - frontmatter 适配
4. 更新本矩阵表 + README.md 平台覆盖表
5. 加示例到 `examples/`
6. 更新 `docs/changelog.md` 版本号