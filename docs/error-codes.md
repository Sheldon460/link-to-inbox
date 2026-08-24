# 错误码处理表

> 本文档覆盖 link-to-inbox 抓取过程中可能遇到的所有错误及对应处理方式。

## 通用错误（跨平台）

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| 链接无法访问 / 403 | 链接已失效、需要登录 | 告知用户手动操作 |
| 网络超时 | 临时网络问题 | 重试一次，仍失败则告知用户 |
| vault 目录不存在 | iCloud 未同步或本地路径错 | 自动 `mkdir -p`；iCloud 需先在 Obsidian 打开过 |
| dousnap 慢 / 超时 | dousnap 服务器压力大 | 自动降级到平台兜底方案 |

---

## 公众号 (mp.weixin.qq.com)

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| WebFetch 失败 | 反爬限制 | 标记 `extraction_status: "部分完成"` |
| 图片 URL 403 | mmbiz 防盗链 | curl + 真实 Referer 重试 |
| 无图片 | 纯文字文章 | 正常归档，images_path 留空 |
| 视频内容 | iframe 嵌入 | 抓取正文 + 标记"含视频内容"，提供原链接 |

---

## 小红书 (xiaohongshu.com)

| 错误码 | 原因 | 处理方式 |
|--------|------|---------|
| 300031 | `xsec_token` 过期，分享链接被限制 | **用站内搜索方案**（见下），不要直接放弃 |
| 笔记不存在 | 已被删除 | 告知用户，无法抓取 |
| 未登录 | 本机 Chrome 未登录小红书 | 提示用户先在本机 Chrome 登录 |
| 图片 URL 失效（2 小时后）| 临时 URL 过期 | 重新抓取一次 |

### xsec_token 过期处理（站内搜索方案）

```bash
# 1. 用笔记标题关键词打开站内搜索页
browser-act --session xhs-search browser open <browser-id> \
  "https://www.xiaohongshu.com/search_result/?keyword=<URL编码的标题关键词>&source=web_search_result_notes"

# 2. 从搜索结果卡片中提取目标笔记和新的 xsec_token
# 3. 用新 URL 打开笔记详情（带新 token）
```

---

## 抖音 (douyin.com)

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| dousnap 失败 | 服务端异常 | 降级到 convry 解析 |
| convry 解析失败 | 视频被删 / 限流 | 告知用户提供手动操作链接 |
| 视频下载 403 | 缺 Referer | 加 `Referer: https://www.douyin.com/` 头重试 |
| 音频提取失败 | ffmpeg 未安装或版本过旧 | 提示 `brew install ffmpeg` |
| Whisper 失败 | 模型路径错或音频损坏 | 检查 `~/Models/whisper/ggml-large-v3-turbo.bin` |

---

## B站 (bilibili.com)

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| 1080P 60帧 missing | 非大会员 | 降级到 1080P 普通或 720P |
| 视频下载无音轨 | 默认 format 只下视频流 | 用 `-f "bv*+ba"` 强制合并 |
| 未登录 480P 限制 | 本机 Chrome 未登录 B站 | 提示用户登录或接受 480P |

---

## 视频号 (channels.weixin.qq.com)

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| macOS 保存面板弹窗 | 默认下载行为 | **已通过 dousnap 绕过**；convry 兜底仍可能弹出 |
| convry 解析失败 | 视频已删或限流 | 告知用户手动操作 |
| 视频号 404 | 链接已失效 | 告知用户 |

---

## TikTok / YouTube

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| 地区限制 | YouTube 区域封锁 | 标记为"地区限制"，告知用户 |
| 视频被删 | 内容下架 | 告知用户 |
| 年龄限制 | 未登录或未验证年龄 | 提示用户登录验证 |

---

## 知识星球 (zsxq.com)

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| 401 | token 过期 | `zsxq-cli auth login` 重新走 OAuth 设备码 |
| 403 | 当前账户不在目标星球 | 切换账户或加入对应星球 |
| 404 | topic_id 不存在或主题被删除 | 重新核对 ID，告知用户 |
| `--topic-id is required` | 参数缺失 | 从 URL 重新提取 |
| API 调用超时 | 网络问题 | 重试一次 |

---

## 飞书远程触发特有错误

| 错误 | 原因 | 处理方式 |
|------|------|---------|
| chat_id 提取失败 | 消息来源不是飞书 | 用默认 chat_id 或提示用户手动提供 |
| 飞书发送失败 | bot 不在群聊中 | 提示用户把 bot 加入群聊或用 `--as user` |
| 附件过大 | 视频文件 > 100MB | 飞书有限制，仅回复文本摘要，文件本地保存 |

---

## 调试技巧

### 1. 手动复现

```bash
# 把 URL 粘到对话里，AI 会自动抓取
# 失败时查看对话中的错误日志

# 或手动跑命令调试
dousnap "<URL>"  # 通过 browser-act 操作
```

### 2. 查看 vault 目录状态

```bash
ls -lt "$VAULT" | head -20
```

### 3. 检查 zsxq-cli 状态

```bash
zsxq-cli auth status
zsxq-cli doctor
```

### 4. 验证 dousnap 可用性

```bash
browser-act --session dousnap browser open <browser-id> "https://www.dousnap.com/" --headed
```

---

## 反馈与改进

发现新的错误模式或解决方案，欢迎提 PR 更新本文档。