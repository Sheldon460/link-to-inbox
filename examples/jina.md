# link-to-inbox v1.9.0 — Jina Reader 通用抓取示例

> 自 v1.9.0 起，link-to-inbox 增加 §2.8「通用网页 / Jina Reader 统一入口」，借鉴 Mars Editor 的 `reader.ts` 设计。本文档是配置 + 使用示例。

## 什么是 Jina Reader？

[Jina Reader](https://jina.ai/reader/) 是一个把任意网页转成 Markdown 的云端服务：
- 远端 headless Chrome 渲染（含 JS）
- 智能 Readability 提取正文（去掉导航/侧栏/cookie banner/相关推荐/评论区）
- 返回 Markdown
- 免费额度：20 req/min/IP（匿名）
- **中国大陆网络通常需要代理**才能访问 `r.jina.ai`

## 一、注册 API key（推荐）

匿名请求会被 Jina 反爬系统标记为"低信誉网络"（如 AS30058 机房 IP），经常返回 401。

**注册步骤**（5 分钟）：

1. 打开 https://jina.ai/reader/ → 点 "Get API Key"
2. GitHub OAuth 登录（无需邮箱验证）
3. 复制免费 key（10M tokens 一次性）
4. 把 key 设到环境变量：

```bash
echo 'export JINA_API_KEY="jina_你的_key_粘贴到这里"' >> ~/.zshrc
echo 'export https_proxy="http://127.0.0.1:7897"' >> ~/.zshrc  # Clash Verge 端口
echo 'export http_proxy="http://127.0.0.1:7897"' >> ~/.zshrc
source ~/.zshrc
```

## 二、配置代理

中国大陆网络访问 `r.jina.ai` 的几种方式：

| 方案 | 配置 |
|------|------|
| **Clash Verge TUN/增强模式** | 默认透明代理，可不设 env |
| **HTTP 代理**（推荐） | `export https_proxy=http://127.0.0.1:7897`（端口看你的 Clash）|
| **SOCKS5 代理** | `export all_proxy=socks5://127.0.0.1:7891` |

**测试连通**：

```bash
curl -fsS --max-time 10 -I "https://r.jina.ai/" 2>&1 | head -3
```

应该返回 `HTTP/2 200`。

## 三、quickstart（任意 URL）

```bash
# 加载 §2.8 的 fetch_jina_article 函数（从 SKILL.md §2.8.2 复制函数体到 ~/.zshrc 或单独 shell 脚本）

URL="https://example.com/some-article"
RESULT=$(fetch_jina_article "$URL")
echo "$RESULT" | python3 -m json.tool
```

返回结构：
```json
{
  "title": "...",
  "url": "https://example.com/some-article",
  "byline": "...",
  "publishedTime": "...",
  "markdown": "...",
  "images": ["https://...", "..."]
}
```

## 四、X 推文抓取

X 推文是 JS-heavy 站点，syndication API 和 chrome-direct 各有缺陷。v1.9.0 改为 **Jina 首选**：

```bash
URL="https://x.com/<handle>/status/<tweet_id>"
RESULT=$(fetch_jina_article "$URL")
# 拿到完整 markdown（含 X 长文 article 正文、代码块、shell 命令等）
```

实测 X 长文（8568 字节，含完整 Ling-3.0-tiny 部署教程 + 6 张图）。

## 五、通用博客/技术文章

```bash
URL="https://blog.cloudflare.com/some-post"
RESULT=$(fetch_jina_article "$URL")
# 27,780+ 字符完整 markdown（含代码块、链接、图片）
```

## 六、错误排查

### 401 AuthenticationRequiredError

```json
{"code":401,"name":"AuthenticationRequiredError","message":"You have been blocked from performing anonymous queries due to bad network reputation (AS30058). Please authenticate."}
```

**原因**：Clash 出口 IP 在 AS30058（FDCservers）等低信誉网络段。**解决**：
1. 注册 API key（见步骤一）
2. 或换非 AS30058 的代理节点

### JSON 解析报 `Invalid \escape`

```python
json.decoder.JSONDecodeError: Invalid \escape
```

**原因**：Jina JSON 模式在 X 长文里把 shell 命令的 `\"` 没正确转义。**解决**：
- 用 **plain text 模式**（不带 `Accept: application/json`）—— §2.8 的 `fetch_jina_article` 已默认走 plain text

### 请求超时 60 秒

```bash
curl: (28) Operation timed out after 60006 milliseconds
```

**原因**：X 等 JS-heavy 站点第一次访问要跑完整 headless Chrome。**解决**：
- 等（一两分钟后重试）
- 提高 `JINA_TIMEOUT` 环境变量

### DNS 污染（解析到 157.240.1.33）

```
nslookup r.jina.ai → 157.240.1.33  ← Facebook IP，污染！
```

**解决**：走代理（见步骤二）。

## 七、为什么用 Mars Editor 的设计？

Mars Editor (https://github.com/whyubel1eve/Mars-Editor-APP) 是 macOS / Windows / Linux 桌面 markdown 编辑器，**抓取部分完全外包给 Jina.ai**，不内置 headless browser。

**借鉴的设计要点**（来自 Mars `reader.ts` 源码）：

1. **POST 而非 GET**（URL 放 body）
2. **plain text 响应**（不用 JSON，避免转义问题）
3. **统一解释 HTTP 错误码**（401/402/429/451 给用户友好中文）
4. **图片本地化并发下载**（限 60 张 / 12 MB / 3 并发）
5. **tidy() 清洗 markdown**（去 Image N 编号 / 链接包裹 / 孤 permalink / 重复空行）
6. **公众号本机直连**（绕过微信验证墙，第三方拿不到）

v1.9.0 完全沿用此设计，与 Mars Editor 行为一致。

## 八、token 消耗

| 内容 | token 数 |
|------|---------|
| 短博客文章（1-2 千字） | 约 1-2K tokens |
| 长文 / 技术文章（5K+字） | 约 5-10K tokens |
| X 推文（短）| 约 200-500 tokens |
| X 长文（含代码块）| 约 5-8K tokens |

10M tokens 一次性 key 大约够抓 **1000-5000 篇中等文章**，日常使用绰绰有余。

## 九、隐私说明

Jina Reader 看到的内容：
- ✅ **目标 URL**（这是抓取的入口，必然看到）
- ✅ **目标页面内容**（这是要返回的 markdown）
- ❌ **不会看到**：你的 JINA_API_KEY、你的 vault 内容、你的其他文件

link-to-inbox 不会把任何数据写回 Jina；Jina 只起到「远端渲染 + 转 Markdown」的作用。