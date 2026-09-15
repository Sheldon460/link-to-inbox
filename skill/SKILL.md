---
name: link-to-inbox
description: "跨平台链接自动归档到 Obsidian 素材收件箱。输入一个链接（公众号/小红书/抖音/快手/B站/视频号/TikTok/YouTube/知识星球/X推特/通用网页），自动识别平台、抓取完整内容（标题+作者+正文+图片）。视频平台（抖音/小红书/快手/B站/视频号/TikTok/YouTube）优先 dousnap；知识星球走 zsxq-cli；公众号走本机直连（绕过微信验证墙）；X 推文走 Jina Reader（推荐） + chrome-direct + syndication API 三级兜底；其他通用网页走 Jina Reader 统一入口，按格式归档到 Obsidian 02.素材收件箱。支持飞书远程触发。"
description_zh: "链接自动归档到 Obsidian 素材收件箱（dousnap + zsxq-cli + chrome-direct + Jina Reader 四入口，公众号仍走本机）"
version: 1.9.0
allowed-tools: Read,Write,Bash,WebFetch,Skill,Glob
metadata:
  clawdbot:
    emoji: "📥"
    requires:
      bins:
        - curl
        - python3
        - markitdown
        - browser-act
        - yt-dlp
        - ffmpeg
        - whisper-cli
        - mpv
      env:
        - JINA_API_KEY  # 可选；不填时 Jina 路径走免费额度（限速），公众号/X/通用网页仍可走本机兜底
        - https_proxy   # 可选；中国大陆网络通常需要走代理才能访问 r.jina.ai
---

# link-to-inbox — 链接自动归档到 Obsidian 素材收件箱

## 触发方式

- 用户在任意对话中发一个链接，说"归档""抓取""存到收件箱"等
- 飞书发链接给 WorkBuddy 后，识别为归档请求

## 工作流总览

```
接收链接
  ↓
识别平台类型（URL domain 匹配）
  ↓
按平台分发抓取（**Mars 风格统一 fetchArticle 架构**）：
  ├─ 公众号 (mp.weixin.qq.com) → 本机直连（绕过微信验证墙，必须）/ Jina Reader（兜底，被验证墙挡时退化为空内容）
  ├─ 小红书 (xhslink/xiaohongshu) → dousnap（首选）/ browser-act chrome-direct（兜底）
  ├─ 抖音 (douyin) → dousnap（首选）/ convry + Python（兜底）
  ├─ 快手 (kuaishou) → dousnap（首选）
  ├─ 视频号 (channels.weixin.qq.com) → dousnap（首选，绕开 macOS 保存面板）/ convry（兜底）
  ├─ B站 (bilibili.com) → dousnap（首选，字幕更准）/ yt-dlp + whisper.cpp（兜底）
  ├─ TikTok / YouTube → dousnap（首选）
  ├─ 知识星球 (zsxq.com) → zsxq-cli topic +detail（直连 API）
  ├─ X 推特 (x.com / twitter.com) → Jina Reader（首选，mars 风格，需 JINA_API_KEY）/ chrome-direct + syndication API（兜底）
  └─ 通用网页 → Jina Reader 统一入口（mars 风格通用抓取；需 JINA_API_KEY 走 https://r.jina.ai/）
  ↓
Mars 风格 post-processing：tidy() 清洗 markdown（去掉 Image N 编号、链接包裹、孤 permalink、重复标题）
  ↓
生成 Obsidian .md（带标准 frontmatter）
  ↓
Mars 风格并发下载图片：max 60 张 / 12 MB / 3 并发（图片 URL 来自 markdown `![](...)` 解析）
  ↓
回复摘要（飞书 / 对话）
```

### Mars 风格 fetchArticle 设计要点（v1.9.0 借鉴自 Mars Editor reader.ts）

Mars Editor 的抓取哲学（来自其 `reader.ts` 源码注释）：

1. **抓取外包给第三方**（Mars 选 Jina.ai）——不内置 headless browser
2. **POST 而非 GET**：URL 放 body 避免 `#` fragment / 双重编码问题
3. **响应是 plain text 而非 JSON**：JSON 在长文里经常有未转义反斜杠（实测 v1.9.0 验证）—— Mars 默认请求 plain text，自行解析 `Title: ... / URL Source: ... / Published Time: ... / Markdown Content:` 头部
4. **失败可解释**：HTTP 401/402/429/451 各自给用户友好的中文解释
5. **图片本地化**：从 markdown `![](...)` 解析 URL，并发下载（限 60 张 / 12 MB）
6. **公众号特例**：Mars 不走第三方，本机直连（因为 Jina 拿不到微信文章）

link-to-inbox v1.9.0 完全沿用此设计：所有"通用抓取"（含 X 推文）走 Jina Reader，公众号保留本机直连。

## Vault 路径

```
/Users/sheldon/Library/Mobile Documents/iCloud~md~obsidian/Documents/02.素材收件箱
```

## 归档目录映射

| 平台 | 归档子目录 | 附件子目录 |
|------|-----------|-----------|
| 公众号 | 02.微信文章/ | 02.微信文章/images/YYYY-MM-DD-作者-标题/ |
| 小红书 | 03.小红书素材/ | 03.小红书素材/media/ |
| B站 | 13.B站/ | 13.B站/YYYY-MM-DD-作者-标题/ |
| 抖音 | 07.抖音视频/ | 07.抖音视频/YYYY-MM-DD-作者-标题/ |
| 视频号 | 11.视频号/ | 11.视频号/YYYY-MM-DD-作者-标题/ |
| 快手 | 12.快手/ | 12.快手/YYYY-MM-DD-作者-标题/ |
| TikTok/YouTube | 14.海外/ | 14.海外/YYYY-MM-DD-作者-标题/ |
| 知识星球 | 15.知识星球/ | 15.知识星球/YYYY-MM-DD-作者-标题/ |
| X 推特 | 16.X推文/ | 16.X推文/media/ |
| 通用网页 | 05.网页文字/ | — |

## 一、识别平台类型

根据 URL domain 判断：

| Domain 包含 | 平台 | content_type |
|-------------|------|-------------|
| mp.weixin.qq.com | 公众号文章 | wechat-article |
| xhslink.com / xiaohongshu.com | 小红书 | xhs-post |
| bilibili.com / b23.tv | B站 | bilibili-video |
| douyin.com / v.douyin.com | 抖音 | douyin-video |
| v.kuaishou.com / kuaishou.com | 快手 | kuaishou-video |
| channels.weixin.qq.com / finder.video.qq.com | 视频号 | sph-video |
| tiktok.com / youtube.com / youtu.be | TikTok/YouTube | overseas-video |
| zsxq.com / wx.zsxq.com / articles.zsxq.com | 知识星球 | zsxq-topic |
| x.com / twitter.com / t.co | X 推特 | x-post |
| 其他 | 通用网页 | webpage |

**判断逻辑**：
```python
url = "<用户输入的链接>"
if "mp.weixin.qq.com" in url:
    platform = "公众号"
    dest_dir = "02.微信文章"
elif any(x in url for x in ["xhslink.com", "xiaohongshu.com"]):
    platform = "小红书"
    dest_dir = "03.小红书素材"
elif any(x in url for x in ["douyin.com", "v.douyin.com"]):
    platform = "抖音"
    dest_dir = "07.抖音视频"
elif any(x in url for x in ["channels.weixin.qq.com", "finder.video.qq.com"]):
    platform = "视频号"
    dest_dir = "11.视频号"
elif any(x in url for x in ["zsxq.com", "wx.zsxq.com", "articles.zsxq.com"]):
    platform = "知识星球"
    dest_dir = "15.知识星球"
elif any(x in url for x in ["x.com", "twitter.com", "t.co"]):
    platform = "X (Twitter)"
    dest_dir = "16.X推文"
else:
    platform = "通用网页"
    dest_dir = "05.网页文字"
```

## 二、按平台抓取内容

### 2.0 统一入口：dousnap.com（首选）

> **覆盖平台**：抖音、小红书、快手、B站、视频号、TikTok、YouTube（公众号不在 dousnap 范围，仍走 2.1）
> **价值**：一次性拿到【标题+描述+【画面】【旁白】结构化文案+封面+视频下载链接】，无需 macOS 保存面板（视频号关键优化点）

**实测流程（已验证 2026-08-18）**：

```bash
# 1. 打开 dousnap
browser-act --session dousnap browser open <browser-id> "https://www.dousnap.com/" --headed

# 2. 等待加载
browser-act --session dousnap wait stable --timeout 15000

# 3. 一步式触发：填链接 + 强制点击"提取文案"按钮（React 站点）
#    用 setNativeValue 触发 React 的 input 同步，再 simulate 真实 click
#    返回 'submitted' 表示已触发；最多等 5 秒按钮可点
browser-act --session dousnap eval '(async()=>{const inp=document.querySelector("input[placeholder*=\"粘贴\"]");if(!inp)return"no input";const url="<链接>";const setter=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,"value").set;setter.call(inp,url);inp.dispatchEvent(new Event("input",{bubbles:true}));inp.dispatchEvent(new Event("change",{bubbles:true}));await new Promise(r=>setTimeout(r,1500));const btn=Array.from(document.querySelectorAll("button")).find(b=>b.textContent.trim().includes("提取文案")&&!b.disabled);if(!btn)return"no enabled btn";btn.click();btn.dispatchEvent(new MouseEvent("click",{bubbles:true,cancelable:true}));await new Promise(r=>setTimeout(r,500));return"submitted"})()'

# 4. 轮询等待"AI 正在提取视频文案"文本消失（i 是轮询次数，30 秒一次）
for i in 1 2 3 4 5 6; do
  sleep 30
  result=$(browser-act --session dousnap eval "(()=>{const body=document.body.innerText;return JSON.stringify({stillExtracting:body.includes('AI 正在提取视频文案'),hasTitle:body.includes('视频标题')})})()" 2>&1)
  echo "[$i] $result"
  if echo "$result" | grep -q '"stillExtracting":false'; then break; fi
done

# 5. 提取完整文本
browser-act --session dousnap eval "document.body.innerText" > /tmp/dousnap_result.txt

# 6. 提取视频/封面下载链接（用 JS eval 拿到 href，给 Python urllib 用）
browser-act --session dousnap eval "(()=>{const links=Array.from(document.querySelectorAll('a[href*=\".mp4\"],a[href*=\".webp\"],a[href*=\".jpg\"],a[href*=\".png\"],a[download]')).slice(0,5).map(a=>a.href);return JSON.stringify(links)})()" > /tmp/dousnap_links.json
```

**关键发现**：
- dousnap 自动识别平台（抖音/小红书/快手/B站/视频号/TikTok/YouTube）
- 输出格式自带【画面】【旁白】结构（脚本可直接复用）
- 视频文件、封面图都有"下载"按钮
- **无 macOS 保存面板问题**——视频号场景终于可远程无人值守
- **B站用官方字幕**而非 ASR，准确度比 Whisper 高

**为什么 v1.6.0 脚本会失败（v1.6.1 修复）**：
- dousnap 用 React 框架，`input.value=...` + `dispatchEvent('input')` 不会触发 React 同步
- 必须用 `Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(inp, url)` 触发原生 setter
- 然后要等 1.5 秒让 React 内部 state 更新（按钮 disabled→enabled）
- 最后按钮点击需要同时触发 button.click() 和 dispatchEvent mouse click 兼容 Vue/React 合成事件

**关键发现**：
- dousnap 自动识别平台（抖音/小红书/快手/B站/视频号/TikTok/YouTube）
- 输出格式自带【画面】【旁白】结构（脚本可直接复用）
- 视频文件、封面图都有"下载"按钮
- **无 macOS 保存面板问题**——视频号场景终于可远程无人值守
- **B站用官方字幕**而非 ASR，准确度比 Whisper 高

**提取结果的 DOM 结构**（用于解析字段）：
- 标题：`<element class="...title...">` 含"复制标题"
- 描述：`<element class="...desc...">` 含"复制描述"
- 文案：`<element class="...transcript...">` 含【画面】【旁白】段
- 视频下载：`<a href="..." download>` 或 `<button>下载视频</button>`
- 封面：`<img src="..." alt="...">` 含"下载封面图"

**网络稳定性**：实测单条抖音链接 30 秒内完成；B站单条 1-2 分钟（取决于视频时长）。如果 dousnap 慢或失败，按平台降级到 2.2/2.3/2.4/2.5 章节的兜底方案。

### 2.1 公众号文章 (mp.weixin.qq.com)

**抓取文字**：
```
WebFetch: url=<链接>, prompt="提取这篇微信公众号文章的完整内容：标题、作者/公众号名称、发布日期、正文全文（保留段落结构）、所有图片URL列表。尽量完整提取，不要省略。"
```

**下载图片**：
```bash
# 1. 用 curl + python3 提取所有 mmbiz.qpic.cn 图片 URL
curl -sL "<链接>" -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15" > /tmp/weixin_article.html

python3 -c "
import re
html = open('/tmp/weixin_article.html').read()
urls = set(re.findall(r'cdn_url:\s*[\x27\x22](https://mmbiz\.qpic\.cn/[^\x27\x22]+)', html))
data_urls = re.findall(r'data-src=\x22(https://mmbiz\.qpic\.cn/[^\x22]+)\x22', html)
all_urls = urls.union(data_urls)
for u in sorted(all_urls):
    if 'wx_fmt=' in u and 'mmbiz.qpic.cn' in u:
        print(u.strip())
"

# 2. 创建附件目录
VAULT="<vault_path>"
IMG_DIR="$VAULT/02.微信文章/images/<YYYY-MM-DD-作者-标题>"
mkdir -p "$IMG_DIR"

# 3. 下载图片
# 逐张 curl -sL -o "$IMG_DIR/img_XX.jpg" "<url>"
```

### 2.2 小红书 (xiaohongshu.com)

> **首选 dousnap（见 2.0）**；本节是 dousnap 不可用时的兜底

**首选方式：chrome-direct 直接操控本机 Chrome（复用已有登录态，无需扫码）**

```bash
# 1. 列出可用浏览器，确认 chrome-direct 的 browser-id
browser-act browser list
# 通常为 direct_local_<数字>（chrome-direct 模式）

# 2. 打开小红书链接（--headed 显示窗口便于观察）
browser-act --session xhs-archive browser open <browser-id> "<链接>" --headed

# 3. 等待页面加载稳定
browser-act --session xhs-archive wait stable --timeout 30000

# 4. 用 JS eval 精确提取笔记信息（不要用 get markdown，会混入页面框架和推荐帖）
#    4a. 标题 + 正文 + 标签 + 日期
browser-act --session xhs-archive eval "(()=>{const t=document.querySelector('#detail-title')?.textContent?.trim()||'';const d=document.querySelector('#detail-desc')?.textContent?.trim()||'';const tags=Array.from(document.querySelectorAll('.tag-item')).map(el=>el.textContent?.trim());const date=document.querySelector('.note-bottom-date')?.textContent?.trim()||'';return JSON.stringify({title:t,description:d,tags:tags,date:date},null,2)})()"

#    4b. 提取当前笔记的图片 URL（只取轮播图，避免混入推荐帖）
browser-act --session xhs-archive eval "(()=>{const imgs=Array.from(document.querySelectorAll('.note-slider-img img')).filter(i=>i.width>100).map(i=>i.src);return JSON.stringify([...new Set(imgs)])})()"

#    4c. 作者信息（如需要）
browser-act --session xhs-archive eval "(()=>{const author=document.querySelector('.username')?.textContent?.trim()||document.querySelector('.author-name')?.textContent?.trim()||'';return JSON.stringify({author:author})})()"

# 5. 关闭会话
browser-act session close xhs-archive
```

**下载图片**：用 Python（shell 数组下载大量 URL 容易因引号/语法报错失败，务必用 Python）：
```bash
python3 << 'PYEOF'
import urllib.request, os
VAULT = "<vault_path>"
dest = os.path.join(VAULT, "03.小红书素材", "<AI工具|AI教程>", "media", "<YYYY-MM-DD-作者-标题>")
os.makedirs(dest, exist_ok=True)
urls = [ "<图片URL1>", "<图片URL2>", ... ]  # 从 4b 结果粘贴
for i, url in enumerate(urls, 1):
    fpath = os.path.join(dest, f"img_{i}.webp")
    try:
        urllib.request.urlretrieve(url, fpath)
        print(f"OK  img_{i}.webp  ({os.path.getsize(fpath):,} bytes)")
    except Exception as e:
        print(f"FAIL  img_{i}.webp  ({e})")
print(f"\nDownloaded: {len(os.listdir(dest))} files")
PYEOF
```

**备选方式（当 chrome-direct 不可用时）**：
```bash
browser-act stealth-extract "<链接>" --content-type markdown
```

**注意**：
- chrome-direct 直接复用本机 Chrome 的小红书登录态，抓取前确保 Chrome 已登录小红书
- 小红书短链接 `xhslink.cn` 直接打开即可，chrome-direct 会自动跳转到真实笔记页
- 分享链接里的 `xsec_token` 有时会过期（错误 300031「笔记暂时无法浏览」），此时**改用站内搜索方案**（见下）
- 下载图片若部分失败（超时/网络），在 Markdown 中只引用已下载的图片，并在文末注明下载情况

**xsec_token 过期（300031）时的站内搜索方案**：

当直接打开笔记链接返回 300031 时，笔记在网页端被限制直接访问，但站内搜索仍可访问：

```bash
# 1. 用笔记标题关键词打开站内搜索页（笔记详情无法访问，但搜索结果卡片正常）
browser-act --session xhs-search browser open <browser-id> "https://www.xiaohongshu.com/search_result/?keyword=<URL编码的标题关键词>&source=web_search_result_notes" --headed
browser-act --session xhs-search wait stable --timeout 15000

# 2. 从搜索结果卡片中提取目标笔记（按标题匹配）和卡片链接里的新 xsec_token
browser-act --session xhs-search eval "(()=>{const card=Array.from(document.querySelectorAll('.note-item')).find(c=>c.querySelector('.title')?.textContent?.includes('<标题关键词>'));if(!card)return 'not found';const a=card.querySelector('a[href*=\"xsec_token\"]');return a?a.href:'no token link'})()"

# 3. 用搜索结果卡片返回的完整 URL（带新的 xsec_token）打开笔记详情
browser-act --session xhs-archive browser open <browser-id> "<上一步返回的完整URL>" --headed
browser-act --session xhs-archive wait stable --timeout 15000
# 之后用标准 JS eval 提取标题/正文/图片/作者
```

**注意**：搜索卡片里的笔记链接带的是新生成的 `xsec_token`，用它可以正常打开详情。图片链接有效期较短（约 2 小时），下载要趁早。

### 2.3 抖音 (douyin.com)

> **首选 dousnap（见 2.0）**；本节是 dousnap 不可用时的兜底

**使用 convry-video-downloader skill**：
```bash
# 调用 convry-video-downloader skill 下载视频
Skill("convry-video-downloader", args="<链接>")
```

**convry 抖音实际流程（已验证）**：
1. `browser-act --session douyin-archive browser open <browser-id> "https://www.convry.com/video/tiktok/one" --headed`
2. `state` 找 textarea（placeholder="输入分享链接或者网页链接。"）和"点击解析"按钮
3. `input <idx> "<链接>"` + `click <idx>` → 页面会自动跳转到 `sph.miuistore.com/sph/public/dy-d?url=...` 解析页
4. 解析页显示：视频ID、视频标题、视频描述、缩略图、多个分辨率下载地址（如 958x576 / 1798x1080 / 1198x720）
5. **用 JS eval 提取所有下载地址的真实 URL**（不要点击下载，会触发浏览器下载且难控制）：
```bash
browser-act --session douyin-archive eval "(()=>{const links=Array.from(document.querySelectorAll('a')).filter(a=>a.textContent.includes('下载地址')).map(a=>({text:a.textContent.trim(),href:a.href}));return JSON.stringify(links,null,2)})()"
```
6. **选最高清分辨率**（如 1798x1080），用 curl -sI 确认 Content-Length 得到文件大小
7. **下载时必须带 Referer: https://www.douyin.com/**（convry 页面的 miuistore referer 会 403），用 Python urllib：
```bash
python3 << 'PYEOF'
import urllib.request
url = "<下载地址URL>"
dest = "<目标路径>.mp4"
req = urllib.request.Request(url, headers={
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36",
    "Referer": "https://www.douyin.com/",
})
with urllib.request.urlopen(req, timeout=120) as r, open(dest, "wb") as f:
    while True:
        chunk = r.read(1024*1024)
        if not chunk: break
        f.write(chunk)
print("done")
PYEOF
```

**获取作者名**（convry 解析页不显示作者）：
- 用视频ID打开 `https://www.douyin.com/video/<视频ID>`，读 `meta[name="description"]`，格式如 "… - 作者名于<日期>发布在抖音，已经收获了XX万个喜欢…"
```bash
browser-act --session douyin-author browser open <browser-id> "https://www.douyin.com/video/<视频ID>" --headed
browser-act --session douyin-author eval "document.querySelector('meta[name=\"description\"]')?.content"
```

**转写音频（markitdown 无法转写视频，用 ffmpeg + whisper.cpp）**：
```bash
# 1. 提取音频（16kHz 单声道 wav）
ffmpeg -y -i <视频.mp4> -vn -ac 1 -ar 16000 /tmp/audio.wav

# 2. whisper.cpp 转写（M4 本地模型，10分钟视频约 90 秒完成）
whisper-cli -m /Users/sheldon/Models/whisper/ggml-large-v3-turbo.bin -f /tmp/audio.wav -l zh -otxt -of /tmp/whisper_out
# 转写结果在 /tmp/whisper_out.txt
```

**下载路径**：视频文件存入 `07.抖音视频/YYYY-MM-DD-作者-标题/` 目录

### 2.5 B站 (bilibili.com / b23.tv)

> **首选 dousnap（见 2.0）**；本节是 dousnap 不可用时的兜底

**使用 yt-dlp 工具（已通过 pip 全局安装）**：

```bash
# 1. 用 yt-dlp 复用 Chrome cookie 下载音视频合并的 mp4
#    B 站默认 format 100026 只有视频流（音视频分离），必须用 +ba 强制合并音轨
"/Users/sheldon/.workbuddy/binaries/python/envs/default/bin/python3" -m yt_dlp \
  --cookies-from-browser chrome \
  -o "/Users/sheldon/WorkBuddy/Claw/bili-tmp/<视频描述>.%(ext)s" \
  -f "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[ext=mp4]" \
  --no-playlist \
  "https://www.bilibili.com/video/BV1xxxxxxxxxx"
```

**关键参数**：
- `--cookies-from-browser chrome` — 复用本机 Chrome 登录态（B 站未登录只能 480P）
- `-f "bv*+ba"` — 视频流 + 音频流合并（默认只下视频，无音频）
- `/Users/sheldon/WorkBuddy/Claw/bili-tmp/` — 临时目录（**不要用 /tmp**，下次重启会被清空）

**注意**：1080P 60帧只有大会员才能下载，非会员会报
`Format(s) 1080P 60帧 are missing; you have to become a premium member`
普通 1080P 通常足够。

**2. 提取音频转写**：
```bash
ffmpeg -y -i /Users/sheldon/WorkBuddy/Claw/bili-tmp/<视频>.mp4 \
  -vn -ac 1 -ar 16000 /Users/sheldon/WorkBuddy/Claw/bili-tmp/<视频>.wav
whisper-cli -m /Users/sheldon/Models/whisper/ggml-large-v3-turbo.bin \
  -f /Users/sheldon/WorkBuddy/Claw/bili-tmp/<视频>.wav -l zh -otxt \
  -of /Users/sheldon/WorkBuddy/Claw/bili-tmp/<视频>
```

**3. 获取作者/标题（可选）**：
- 直接看 yt-dlp 返回的标题；作者名通常在文件名 or 视频页 hero info
- 也可用 `browser-act` 打开视频页 → `document.querySelector('.up-name').textContent` 拿作者

**4. 归档**：视频和 .md 都移动到 `13.B站/YYYY-MM-DD-作者-标题/`

**下载路径**：视频文件存入 `13.B站/YYYY-MM-DD-作者-标题/` 目录

### 2.6 知识星球 (zsxq.com / wx.zsxq.com / articles.zsxq.com)

> **不走 dousnap**，知识星球是登录态封闭生态，直接调用 `zsxq-cli` 拿结构化 JSON，比网页抓取更可靠。

**URL 格式识别**：

```
电脑端：https://wx.zsxq.com/group/{group_id}/topic/{topic_id}
手机端：https://wx.zsxq.com/mweb/views/topicdetail/topicdetail.html?topic_id={topic_id}&group_id={group_id}
公开笔记：https://articles.zsxq.com/html/{note_id}/{slug}.html
```

**抓取流程**：

```bash
# 1. 从 URL 提取 topic_id（用正则，兼容电脑端 + 手机端）
topic_id=$(echo "<链接>" | grep -oE 'topic[_-]?id=[0-9]+|/topic/[0-9]+' | grep -oE '[0-9]+' | head -1)
# 若 topic_id 抽取失败，用浏览器打开链接，从 URL 重定向里复制

# 2. 调用 zsxq-cli 拿主题详情（JSON 输出）
zsxq-cli topic +detail --topic-id "$topic_id"

# 3. （可选）拿评论列表
zsxq-cli api call get_topic_comments --params "{\"topic_id\":\"$topic_id\",\"limit\":50,\"index\":0}"
```

**解析 JSON 关键字段**（写入 frontmatter）：

| 字段 | 来源 | 示例 |
|------|------|------|
| `title` | `topic.title` | "示例主题标题" |
| `topic_id` | `topic.topic_id` | "111222333444" |
| `group_id` | `topic.group.group_id` | "123456789" |
| `group_name` | `topic.group.name` | "示例星球" |
| `author` | `topic.owner.name` | "示例用户" |
| `create_time` | `topic.create_time` | "2025-12-31T09:19:28.239+0800" |
| `type` | `topic.type` | talk / q&a / task / solution |
| `content` | `topic.content` | 正文（HTML 片段或纯文本） |
| `counts` | `topic.counts` | comments/likes/readers |

**下载附件（如有）**：知识星球正文里的图片链接通常是 `cdn.zsxq.com` 域名的临时 URL，用 Python 抓取：

```bash
python3 << 'PYEOF'
import urllib.request, os, re
VAULT = "<vault_path>"
dest = os.path.join(VAULT, "15.知识星球", "<YYYY-MM-DD-作者-标题>", "media")
os.makedirs(dest, exist_ok=True)
content = """<topic.content 原文，含 <img src='https://cdn.zsxq.com/...'>"""
urls = re.findall(r'https?://cdn\.zsxq\.com/[^\s\'"<>]+', content)
for i, url in enumerate(urls, 1):
    try:
        req = urllib.request.Request(url, headers={"Referer": "https://wx.zsxq.com/"})
        with urllib.request.urlopen(req, timeout=30) as r, open(os.path.join(dest, f"img_{i}.jpg"), "wb") as f:
            f.write(r.read())
        print(f"OK img_{i}.jpg")
    except Exception as e:
        print(f"FAIL img_{i}: {e}")
PYEOF
```

**归档**：写入 `15.知识星球/YYYY-MM-DD-作者-标题.md`，文件名用主题创建日期（不是抓取日期），标题清理特殊字符后截取 30 字。

**frontmatter 适配**（知识星球特有字段）：

```yaml
---
title: "<主题标题>"
created: <归档日期 YYYY-MM-DD>
source: "知识星球 - <星球名> · <作者>"
source_url: "<原始链接>"
date: <主题 create_time 转为 YYYY-MM-DD>
imported_at: <抓取日期时间>
tags:
  - 素材收件箱
  - 知识星球
  - <星球名>
  - <type: talk / qa / task / solution>
type: inbox-raw
extraction_status: "zsxq-cli topic +detail; <comments>/<likes> 评论/点赞"
author: <owner.name>
topic_id: <topic_id>
group_id: <group_id>
images_path: "[[media/]]"  # 仅在有图片附件时填写
---
```

**注意**：
- zsxq-cli 需先登录（`zsxq-cli auth login`），token 存系统 Keychain
- 遇到 401 走 `zsxq-cli auth login` 重新走 OAuth 设备码
- 403 通常是当前账户不在目标星球内，无法抓取私有主题
- 主题可能被星主删除，抓取失败时如实报告，不假装完成

### 2.4 视频号 (channels.weixin.qq.com)

**使用 convry-video-downloader skill**：
```bash
# 调用 convry-video-downloader skill 下载视频
Skill("convry-video-downloader", args="<链接>")
```

**前置配置（已知不可靠，2026-08-12 实测发现）**：

> **⚠️ 已撤回的方案**：曾尝试通过修改 Chrome Preferences 和 macOS defaults 关闭下载弹窗，实测发现：
> - 写入 `savefile.default_directory` 和 `profile.default_download_directory` 到 Preferences 会被 Chrome 重启时保留，但**仍然触发 macOS 保存面板**
> - 写入 macOS `defaults write com.google.Chrome PromptForDownload -bool false` 会导致 Chrome 启动后立即崩溃（SIGTRAP/EXC_BREAKPOINT，崩溃报告 `Google Chrome-2026-08-12-155345.ips`）
> - 因此**当前流程仍然依赖 macOS 保存面板弹窗**——远程操作需要用户在弹窗手动点"保存"
>
> 已于 2026-08-12 16:50 回退所有改动（删除 Preferences 字段 + defaults delete PromptForDownload）。

**当前可用的远程方案**：
- **飞书消息提示用户**：用户在弹窗出现后手动点保存到 Obsidian 目录
- **CDP `Page.setDownloadBehavior`**（待验证）：通过 Chrome DevTools Protocol 设置下载行为，理论上可绕过弹窗

**convry 视频号实际流程（已验证 2026-08-12）**：
1. `browser-act --session sph-archive browser open <browser-id> "https://www.convry.com/video/sph/home" --headed`
2. `state` 找输入框（placeholder="达人名称或视频号分享链接"）
3. **用 JS eval 触发提交**（直接点 [47] 按钮可能不触发）：
```bash
browser-act --session sph-archive eval "(()=>{const inp=document.querySelector('input[placeholder=\"达人名称或视频号分享链接\"]');inp.value='<链接>';inp.dispatchEvent(new Event('input',{bubbles:true}));const btn=Array.from(document.querySelectorAll('button')).find(b=>b.classList.contains('sph-search'));if(btn){btn.click();return 'clicked'}}return 'no btn'})()"
```
4. 等 8 秒，表格列出匹配的视频项（含标题、缩略图、大小）
5. 点击表格项的"下载视频"按钮（用 JS eval：`Array.from(document.querySelectorAll('.el-table__row button')).find(b=>b.textContent.trim()==='下载视频').click()`）→ 跳转 `sph.miuistore.com/?sph_url=<视频ID>&...`
6. miuistore 解析页输入框已自动填好视频 ID，**首次点"下载"按钮触发解析**（进度 0.01% → ~90%）
7. **解析完成后**按钮恢复为"下载"，**第二次点才触发浏览器真实下载**
   - 用 JS eval 找隐藏按钮并点击：`document.querySelector('.btn.btn-success.w-100:not(.btn-go)')?.click()`
   - 触发后 Chrome 按 `PromptForDownload=false` + `savefile.default_directory` 配置直接保存，无保存面板弹窗
8. **必须依赖浏览器完成下载**，不能用 Python 接管（miuistore 解析结果是加密的 `_data` 字段，无明文 URL）

**验证下载**：视频文件应出现在用户配置的 Chrome 下载目录（本次是 Obsidian `02.素材收件箱/`，由 skill 移动到 `11.视频号/`）：
```bash
ls -lt "$VAULT" | head -10
```

**转写音频**：同抖音，用 ffmpeg + whisper.cpp（markitdown 不支持视频转写，见 2.3）。

**下载路径**：视频文件由 Chrome 保存到 `02.素材收件箱/` 根目录，skill 后续按归档命名规则移动到 `11.视频号/YYYY-MM-DD-作者-标题/` 子目录。

### 2.7 X 推特 (x.com / twitter.com / t.co)

> **不走 dousnap**（dousnap 仅支持抖音/小红书/快手/B站/视频号/TikTok/YouTube），X 推文 **v1.9.0 改为三入口推荐顺序**：
>
> 1. **首选**：Jina Reader 通用入口（mars 风格，需 `JINA_API_KEY` 环境变量；无需 Chrome 登录态、无需 Chrome 远程调试、无 cookie，r.jina.ai 远端 headless Chrome 渲染后返回 markdown）
> 2. **兜底 1**：chrome-direct 复用本机 Chrome 登录态（已登录能看到私密推文、长文 article 完整版）
> 3. **兜底 2**：syndication API 公开（`cdn.syndication.twimg.com`，无需登录，但只能拿公开推文，X 长文只给短链不给正文）

**URL 格式识别**：

```
标准推文：https://x.com/<handle>/status/<tweet_id>
带查询参数：https://x.com/<handle>/status/<tweet_id>?s=20&t=...
短链：https://t.co/<slug>  →  需先解析为标准推文 URL
```

**首选方式：Jina Reader（v1.9.0 新增，mars 风格推荐）**

设置 `JINA_API_KEY` 环境变量后，调用 §2.8 通用 Jina Reader 入口会自动处理 X 推文（含 X 长文）。X 推文是 JS-heavy 站点，syndication API 和 chrome-direct 各有缺陷（前者不返回长文正文，后者依赖登录态），Jina 远端 headless Chrome 能拿到最完整的 markdown。实测 X 长文（《Ling-3.0-tiny 部署教程》8568 字节完整 markdown）：

```bash
curl -sS -X POST "https://r.jina.ai/" \
  -H "Authorization: Bearer $JINA_API_KEY" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Retain-Images: all" \
  -H "X-Base: final" \
  -H "X-Timeout: 45" \
  -d "url=https://x.com/Re7_AI/status/2091717668869128410"
```

返回 plain text（**注意：用 plain text 模式不要 `Accept: application/json`——v1.9.0 实测发现 Jina JSON 模式在 X 长文里有未转义反斜杠导致 `Invalid \escape` 解析失败**），格式：

```
Title: 睿奇Re7 (@Re7_AI) on X
URL Source: https://x.com/Re7_AI/status/2091717668869128410
Published Time: 2026-08-24T02:42:09.000Z
Markdown Content:
<完整 markdown 正文>
```

走通用 §2.8 `fetchJinaArticle(url)` 函数即可，返回 `{title, url, byline, publishedTime, markdown, images}`。后续图片下载、归档走标准流程。

**兜底方式 1：chrome-direct 复用本机 Chrome 登录态**（保留 v1.8.0 流程）

```bash
# 1. 列出可用浏览器，确认 chrome-direct 的 browser-id（一般为 direct_local_<数字>）
browser-act browser list

# 2. ⚠️ 关键坑：session 名要唯一，避免复用已开标签页导致 url ≠ 预期
#    同时建议去掉 ?s=20 这种查询参数，避免 Chrome 误以为是别的页面
CLEAN_URL=$(echo "<链接>" | sed -E 's/\?.*$//')
browser-act --session x-post-archive-$RANDOM browser open <browser-id> "$CLEAN_URL" --headed

# 3. ⚠️ 不要等 wait stable——x.com 后台 SSE 持续活动，稳定检测永不通过
#    直接评估 article 是否就绪即可
browser-act --session x-post-archive-* eval "(()=>{const a=document.querySelector('article[data-testid=\"tweet\"]');if(!a)return JSON.stringify({ready:false,url:location.href,title:document.title});return JSON.stringify({ready:true,url:location.href,title:document.title,articleLen:a.innerText.length})})()"

# 4. 一次性提取所有元数据 + 正文 + 图片 URL（避免反复 eval）
#    ⚠️ 关键：[data-testid="tweetText"] 长度=0 是 Twitter 懒加载设计，
#    必须用 article.innerText 兜底才能拿到完整正文
browser-act --session x-post-archive-* eval "(()=>{const articles=document.querySelectorAll('article[data-testid=\"tweet\"]');const a=articles[0];if(!a)return JSON.stringify({error:'no tweet'});const handleLink=Array.from(a.querySelectorAll('a[role=\"link\"]')).map(l=>l.getAttribute('href')).find(h=>h&&h.startsWith('/')&&!h.includes('/status/')&&h.split('/').filter(Boolean).length===1)||'';const userNameText=a.querySelector('[data-testid=\"User-Name\"]')?.textContent?.trim()||'';const userName=userNameText.replace(/^@/,'').replace(handleLink.replace('/',''),'').trim()||userNameText;const timeUtc=a.querySelector('time')?.getAttribute('datetime')||'';const text=a.innerText;const images=Array.from(a.querySelectorAll('img[src*=\"pbs.twimg.com/media\"]')).map(i=>i.src).filter((v,i,arr)=>arr.indexOf(v)===i);const metrics=Array.from(a.querySelectorAll('[data-testid=\"app-text-transition-container\"]')).map(e=>e.textContent?.trim()).filter(Boolean);const replyCount=metrics[0]||'';const retweetCount=metrics[1]||'';const likeCount=metrics[2]||'';const viewCount=text.match(/([\d,]+)\s*查看/)?.[1]||'';return JSON.stringify({userName,handle:handleLink,timeUtc,text,images,replyCount,retweetCount,likeCount,viewCount,articleLen:text.length},null,2)})()"
```

**下载原图**（⚠️ 推文图片默认给的是 medium，改 name=large 才能拿原图）：

```bash
# 1. 创建附件目录
VAULT="/Users/sheldon/Library/Mobile Documents/iCloud~md~obsidian/Documents"
DEST="$VAULT/02.素材收件箱/16.X推文/<YYYY-MM-DD>-@<handle>-<标题>/media"
mkdir -p "$DEST"

# 2. 用 Python 批量下载（替换 name=medium 为 name=large）
/Users/sheldon/.workbuddy/binaries/python/envs/default/bin/python3 << PYEOF
import urllib.request, os, re
VAULT = "/Users/sheldon/Library/Mobile Documents/iCloud~md~obsidian/Documents"
dest = os.path.join(VAULT, "02.素材收件箱/16.X推文", "<YYYY-MM-DD>-@<handle>-<标题>", "media")
os.makedirs(dest, exist_ok=True)
raw_urls = """<从第 4 步 eval 返回的 images 数组粘贴>"""
urls = re.findall(r'https?://[^\s\",]+', raw_urls)
urls = [u.replace('name=medium','name=large') for u in urls]
for i, url in enumerate(urls, 1):
    fpath = os.path.join(dest, f"img_{i}.jpg")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r, open(fpath, "wb") as f:
            f.write(r.read())
        print(f"OK  img_{i}.jpg  ({os.path.getsize(fpath):,} bytes)")
    except Exception as e:
        print(f"FAIL  img_{i}.jpg  ({e})")
print(f"\nFiles: {os.listdir(dest)}")
PYEOF
```

**兜底方式 1：syndication API（无需登录，公开）**

> 适用于 chrome-direct 登录态过期 / 反爬触发 / 想批量抓公开推文。
>
> ⚠️ **必须带 `lang=en&token=x` 参数**，否则返回 `{}` 空 JSON（2026-08-30 实测发现）

```bash
# 1. 从 URL 提取 tweet_id
TWEET_ID=$(echo "<链接>" | grep -oE 'status/[0-9]+' | grep -oE '[0-9]+')

# 2. curl 抓 syndication API（必须带 lang+token，否则返回 {}）
curl -sL "https://cdn.syndication.twimg.com/tweet-result?id=$TWEET_ID&lang=en&token=x" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/150.0.0.0 Safari/537.36" \
  > /tmp/x_syndication_$TWEET_ID.json

# 3. 关键字段（实测 2026-08-30 / 2026-08-31）
# 顶层:
# - id_str                推文 ID（字符串）
# - created_at            UTC ISO 时间
# - text                  推文正文（X 长文只有短链，主文短）
# - lang                  zh / en / zxx（zxx = 无文字/纯链接/纯媒体）
# - favorite_count        点赞数
# - conversation_count    回复数（注意：不是 reply_count）
# - possibly_sensitive    敏感标记
# - isEdited / isStaleEdit
# - entities.urls[]       推文里的链接（含 display_url / expanded_url）
# - article.cover_media   X 长文封面图（含 original_img_url）
#
# user.* (嵌套):
# - user.id_str           用户 ID
# - user.name             显示名（如 "云析"）
# - user.screen_name      handle（不带 @，如 "yunxi0623"）
# - user.profile_image_url_https
# - user.is_blue_verified
#
# ⚠️ syndication API 不返回的字段（必须靠 chrome-direct 拿）:
# - retweet_count         转推数
# - quote_count           引用数
# - view_count            浏览量
# - mediaDetails          普通推文的内嵌图片/视频列表（X 长文无此字段，正文图在 article.cover_media）
```

**X 长文特殊处理**：

如果 syndication 返回的 `text` 是短链（如 `https://t.co/xxx`），且 `entities.urls[].expanded_url` 是 `https://x.com/i/article/<id>` 形式，说明这条推文是 **X 长文（Article）**，主文在 article 页里。需要：
1. 解析出 `article_id`（从 `expanded_url`）
2. chrome-direct 打开 `https://x.com/i/article/<article_id>` 拿正文
3. 或者直接靠 chrome-direct `article.innerText` 兜底拿全文（已在 v1.8.0 流程里默认做）

**兜底方式 2：stealth-extract（无需登录，markdown 输出）**

```bash
# 适合 chrome-direct / syndication 都失败时的兜底
browser-act stealth-extract "<链接>" --content-type markdown
```

**frontmatter 适配（X 推文特有字段）**：

```yaml
---
title: "<推文首行或话题>"
created: <归档日期 YYYY-MM-DD>
source: "X (Twitter) - <作者显示名> @<handle>"
source_url: "<原始链接>"
date: <推文发布日 YYYY-MM-DD>
imported_at: <抓取日期时间>
tags:
  - 素材收件箱
  - X-Twitter
  - <内容相关tags>
type: inbox-raw
extraction_status: "chrome-direct 已登录态抓取；<N>张原图；<回复> 回复 / <转推> 转推 / <点赞> 点赞 / <引用> 引用 / <浏览> 浏览"
author: <作者显示名> (@<handle>)
tweet_id: <数字 ID>
author_handle: "@<handle>"
author_name: "<作者显示名>"
lang: <zh / en / ...>
published_at_utc: <ISO UTC>
published_at_local: "<YYYY-MM-DD HH:MM +08:00>"
metrics:
  replies: <int>
  retweets: <int>
  likes: <int>
  quotes: <int>
  views: <int>
media_count: <int>
has_quoted_tweet: <bool>
images_path: "[[media/]]"  # 仅在有图片附件时填写
---
```

**文件名规范**：

```
<YYYY-MM-DD>-@<handle>-<标题截取30字以内>.md
```

例如：`2026-08-30-@yunxi0623-OpenAI已经用上WebMCP.md`

**注意**：

- **会话复用坑**：chrome-direct session 名必须唯一 + 去掉 URL 查询参数，否则会路由到已存在的标签页
- **wait stable 不可用**：x.com 后台 SSE / analytics 持续有网络活动，稳定检测永不通过，直接评估 article 就绪即可
- **tweetText selector 失效**：Twitter 在 article 内不渲染文本节点，必须用 `article.innerText` 兜底
- **图片必须改 name=large**：默认 medium 尺寸，原图需要手动替换 query 参数
- **时间换算**：`time[datetime]` 是 UTC ISO，需 `+8h` 换算为北京时间
- **作者信息**：不要从 `[data-testid="User-Name"]` textContent 拆分（会得到 `"云析@yunxi0623"` 合并文本），从 `a[role="link"]` 的 href 单独拿 handle 更可靠

**抓取边界（不能做）**：

- ❌ 批量爬用户主页时间线（违反 X ToS，会触发账号风险）
- ❌ 高频单用户抓取（>10 条/分钟会被封 IP / session）
- ❌ 抓私密账号 / 私密推文（必须用户已登录且账号公开）
- ❌ 把抓取的推文二次公开发布（原始版权仍归作者）

只允许：单条公开推文抓取 + 用户私有知识库归档。

### 2.8 通用网页 / Jina Reader 统一入口（v1.9.0 新增，mars 风格）

> **借鉴自 Mars Editor 的 `reader.ts` fetchArticle 实现**。本入口是 X 推特、其他通用博客、文档站点、技术文章等"没有专门处理逻辑"的统一抓取入口。视频平台（抖音/小红书/快手/B站/视频号/TikTok/YouTube）仍走 dousnap，公众号仍走本机直连（见 §2.1），知识星球仍走 zsxq-cli（见 §2.6）。

#### 2.8.1 配置（v1.9.1：使用 init.sh 模板）

> **v1.9.1 修复**：v1.9.0 测试发现 `JINA_API_KEY` env var 在某些情况下会被 shell 损坏（看起来是 `jina_xxx` 但 Jina 返回 401 Invalid）。**v1.9.1 改用 `init.sh.example` 模板 + `source ./init.sh` 加载**，并在脚本里直接验证 key 可用性。

**一次性设置**：

```bash
# 1. 克隆（如果还没）
git clone --depth 1 https://github.com/Sheldon460/link-to-inbox.git ~/Downloads/link-to-inbox
cd ~/Downloads/link-to-inbox

# 2. 复制 init 模板（init.sh 已在 .gitignore，不会被 commit）
cp init.sh.example init.sh

# 3. 编辑 init.sh，填入你自己的 JINA_API_KEY
$EDITOR init.sh
#    - 注册：https://jina.ai/reader/ → Get API Key（GitHub OAuth，免费 10M tokens）
#    - 替换：export JINA_API_KEY="jina_在这里粘贴你的key"
#    - 检查代理端口（默认 7897 是 Clash Verge）

# 4. 在每个 shell 里加载：
source ./init.sh
#    ✅ Jina API key 验证通过
#    ✅ 代理已设
```

**关键约束**：

| 环境变量 | 必填？ | 说明 |
|----------|--------|------|
| `JINA_API_KEY` | **必填**（v1.9.1 起）| 不填时 init.sh 会拒绝运行；v1.9.0 允许空 key 但 401 风险大 |
| `https_proxy` / `http_proxy` | 可选 | 中国大陆网络通常需要；TUN/增强模式 Clash 已自动透明代理可不填 |

**安全规则**：

- ✅ `init.sh` 在 `.gitignore` 里，**绝不会被 commit**
- ✅ 用户自己填 key（不被写进 SKILL.md / scripts / commit history）
- ❌ **绝不**把 API key 硬编码进 SKILL.md、脚本、commit message、PR 描述
- ❌ **绝不**把 `init.sh` 上传网盘 / 邮件 / 截图
- ❌ **绝不**在公共频道（Discord / Slack）粘贴 key
- ⚠️  key 一旦泄露，立即去 https://jina.ai/api-dashboard 撤销 + 申请新的

#### 2.8.2 核心 fetch 函数（mars 风格）

```bash
fetch_jina_article() {
  local url="$1"
  local key="${JINA_API_KEY:-}"
  local timeout="${JINA_TIMEOUT:-45}"

  # mars 风格：POST 而非 GET，URL 放 body 避免 # fragment 截断 / 双重编码
  local headers=(
    -H "Content-Type: application/x-www-form-urlencoded"
    -H "X-Retain-Images: all"        # 保留 markdown 图片 URL
    -H "X-Base: final"                # 相对 URL 解析基于最终跳转后的 URL
    -H "X-Timeout: ${timeout}"
  )
  if [[ -n "$key" ]]; then
    headers+=(-H "Authorization: Bearer $key")
  fi

  # ⚠️ 不要加 -H "Accept: application/json"：v1.9.0 实测发现 Jina JSON 模式在 X 长文里有未转义反斜杠
  # （如 shell 命令里的 \" 转义），解析会失败。plain text 模式完美工作。
  local resp
  resp=$(curl -sS --max-time $((timeout + 15)) -X POST "https://r.jina.ai/" \
    "${headers[@]}" \
    -d "url=${url}" 2>&1)

  # mars 风格：从 plain text 解析 Title / URL Source / Published Time / Markdown Content 头部
  python3 << PYEOF
import re, sys, json
text = """${resp//\"/\\\"}"""
# mars 风格：提取头部元数据，剩余作为正文
fields = {}
lines = text.split('\n')
start = 0
for i, line in enumerate(lines):
    if re.match(r'^Markdown Content:\s*$', line):
        start = i + 1
        break
    m = re.match(r'^([A-Z][A-Za-z ]+):\s*(.*)$', line)
    if m: fields[m.group(1).strip()] = m.group(2).strip()
    elif line.strip(): break
content = '\n'.join(lines[start:])

# mars 风格 tidy()：清洗 markdown 残留物
def tidy(md):
    return (md
        .replace('![Image', '![')                                          # 去掉 Image N 编号
        .replace('[![' + '!['*0, '[![')                                   # noop（避免连续替换）
        # 实际上图包裹清理：
    )

# 简化版 tidy（按 Mars Editor 思路，但避免上面字符串拼接问题）
def tidy2(md):
    md = re.sub(r'!\[Image \d+(?::\s*)?', '![', md)        # Image 12: alt → ![alt
    md = re.sub(r'\[(!\[[^\]]*\]\([^)]*\))\]\([^)]*\)', r'\1', md)  # 链接包裹图
    md = re.sub(r'^[ \t]*\[[#¶§]?\]\([^)]*\)[ \t]*$', '', md, flags=re.MULTILINE)  # 孤 permalink
    md = re.sub(r'^[ \t]*[=]{3,}[ \t]*$', '', md, flags=re.MULTILINE)  # setext 下划线
    md = re.sub(r'[ \t]+$', '', md, flags=re.MULTILINE)
    md = re.sub(r'\n{3,}', '\n\n', md)
    return md.strip()

# 提取图片 URL
images = re.findall(r'!\[([^\]]*)\]\((https?://[^)]+)\)', content)

result = {
    'title': fields.get('Title', ''),
    'url': fields.get('URL Source') or '${url}',
    'byline': fields.get('Author', ''),
    'publishedTime': fields.get('Published Time', ''),
    'markdown': tidy2(content),
    'images': [u for _, u in images],
}
print(json.dumps(result, ensure_ascii=False))
PYEOF
}
```

调用方式：

```bash
result=$(fetch_jina_article "https://example.com/article")
title=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
markdown=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['markdown'])")
images=$(echo "$result" | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)['images']))")
```

#### 2.8.3 错误处理（按 Mars Editor `explainStatus` 思路）

| HTTP | 含义 | 用户友好的提示 |
|------|------|---------------|
| 200 | OK | — |
| 400 / 422 | 抓取失败 | "这个地址抓不出正文 —— 多半是登录墙、付费墙，或者压根不是文章页" |
| 401 | key 不对或 AS30058 等低信誉网络 | "Jina 的 key 不对，去设置里改一下，或者干脆清空 —— 不填 key 也能用（限速 20 req/min）" |
| 402 | 额度用完 | "Jina 这个 key 的额度用完了。清空 key 就回到免费额度，或者去 jina.ai 充值" |
| 429 | 限流 | "请求太频繁了，等一会儿再试"（有 key）/ "请求太频繁了（不填 key 是每分钟 20 次）" |
| 451 | 法律拒绝 | "这个页面拒绝被抓取" |
| 5xx | Jina 服务端问题 | "Jina 那边出错了（HTTP {code}），稍后再试" |

**目标站点错误**（data.httpStatus >= 400）：

| HTTP | 含义 | 用户友好的提示 |
|------|------|---------------|
| 404 / 410 | 链接打不开 | "这个链接打不开了（对方返回 404）" |
| 401 / 403 | 站点要登录 | "这个页面要登录才看得到正文" |
| 429 | 站点限流 | "对方站点觉得访问太频繁" |
| 5xx | 站点出问题 | "对方站点这会儿有问题" |

#### 2.8.4 图片下载（mars 风格并发）

```bash
download_jina_images() {
  local dest_dir="$1"   # 目标目录（不含文件名）
  local images_json="$2" # JSON 数组字符串，例如 '["https://...","https://..."]'
  local max_images="${MAX_IMAGES:-60}"
  local max_bytes_per_img="$((12 * 1024 * 1024))"
  local concurrency="${CONCURRENCY:-3}"

  python3 << PYEOF
import urllib.request, os, json, re
dest = "${dest_dir}"
images = json.loads('''${images_json//\"/\\\"}''')[:${max_images}]
os.makedirs(dest, exist_ok=True)
ok = fail = 0
for i, url in enumerate(images, 1):
    fpath = os.path.join(dest, f"img_{i}.jpg")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
        if len(data) > ${max_bytes_per_img}:
            print(f"SKIP img_{i} too big ({len(data):,} bytes)"); fail += 1; continue
        with open(fpath, 'wb') as f:
            f.write(data)
        print(f"OK img_{i}.jpg ({len(data):,} bytes)"); ok += 1
    except Exception as e:
        print(f"FAIL img_{i}: {e}"); fail += 1
print(f"\nDone: {ok} ok, {fail} fail, total {len(os.listdir(dest))} files in {dest}")
PYEOF
}
```

#### 2.8.5 完整流程示例（通用博客文章）

```bash
# 1. 抓取
url="https://example.com/some-article"
result=$(fetch_jina_article "$url")
title=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
markdown=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['markdown'])")
images=$(echo "$result" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['images']))")

# 2. 创建附件目录
VAULT="/Users/sheldon/Library/Mobile Documents/iCloud~md~obsidian/Documents"
DEST="$VAULT/02.素材收件箱/05.网页文字/$(date +%Y-%m-%d)-${title:0:30}"
mkdir -p "$DEST"

# 3. 下载图片
download_jina_images "$DEST" "$images"

# 4. 写 markdown（带 frontmatter）
cat > "$DEST/$(date +%Y-%m-%d)-${title:0:30}.md" << MDEOF
---
title: "$title"
created: $(date +%Y-%m-%d)
source: "通用网页 - $(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')"
source_url: "$url"
date: $(date +%Y-%m-%d)
imported_at: $(date "+%Y-%m-%d %H:%M:%S %Z")
tags:
  - 素材收件箱
  - 通用网页
type: inbox-raw
extraction_status: "Jina Reader; $(echo "$images" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))") 张图片"
---

$markdown
MDEOF

echo "✅ 已归档到 $DEST"
```

## 三、归档格式

### 标准 Frontmatter

```yaml
---
title: "<文章标题>"
created: <归档日期 YYYY-MM-DD>
source: "<平台> - <作者/账号名>"
source_url: "<原始链接>"
date: <原文发布日期 YYYY-MM-DD>
imported_at: <抓取日期时间>
tags:
  - 素材收件箱
  - <平台tag>
  - <内容相关tags，从文章提取>
type: inbox-raw
extraction_status: <抓取内容摘要>
author: <作者名>
images_path: "[[media/<子目录>/]]"  # 公众号文章
---
```

### 文件名规范

```
<YYYY-MM-DD>-<作者/来源>-<标题截取30字以内>.md
```

- 日期：原文发布日期，取不到用抓取日期
- 标题：清理特殊字符（/ \ : * ? " < > |），截取 30 字内
- 作者：公众号名/小红书用户名/抖音创作者名

### 归档示例

**公众号文章**：
```
02.微信文章/2026-08-02-松鼠AIGC-WorkBuddy-Pinterest社媒作图Skill.md
02.微信文章/images/2026-08-02-WorkBuddy-Pinterest/img_01.jpeg
02.微信文章/images/2026-08-02-WorkBuddy-Pinterest/img_02.jpeg
...
```

**小红书帖子**：
```
03.小红书素材/AI工具/2026-08-11-某博主-某AI工具推荐.md
```

**抖音视频**：
```
07.抖音视频/2026-08-11-某账号-某视频标题/
  ├── 视频文件.mp4
  └── 转录文本.md
```

**视频号**：
```
11.视频号/2026-08-11-某账号-某视频标题/
  ├── 视频文件.mp4
  └── 转录文本.md
```

**X 推特**：
```
16.X推文/2026-08-30-@yunxi0623-OpenAI已经用上WebMCP/
  ├── 2026-08-30-@yunxi0623-OpenAI已经用上WebMCP.md
  └── media/
      ├── img_1.jpg
      └── img_2.jpg
```

## 四、回复摘要格式

### 4.1 对话内回复

归档完成后，直接回复 Markdown 摘要：

```
✅ 已归档到 Obsidian 素材收件箱

| 项目 | 详情 |
|------|------|
| 来源 | <平台> - <作者> |
| 标题 | <标题> |
| 归档位置 | 02.素材收件箱/<子目录>/<文件名>.md |
| 附件 | <N>张图片 / <1>个视频 |

📝 内容摘要：<100字左右的核心内容概括>
```

### 4.2 飞书回复（如果是从飞书触发的）

```bash
lark-cli im +messages-send \
  --receive-id-type chat_id \
  --receive-id "<原消息的chat_id>" \
  --as bot --markdown \
  -m "✅ 已归档到 Obsidian 素材收件箱

**来源**：<平台> · <作者>
**标题**：<标题>
**归档位置**：02.素材收件箱/<子目录>/<文件名>.md
**附件**：<N>张图片 / 视频已保存

**内容摘要**：<100字核心概括>"
```

注意：发送飞书消息前，需先从原消息中提取 `chat_id`。如果是用户身份发来的消息（`--as user` 发送），用 `--as bot` 回复时需要 bot 已在 chat 中。

## 五、错误处理

| 场景 | 处理方式 |
|------|----------|
| 链接无法访问 / 403 | 告知用户链接可能需要登录或已失效 |
| 小红书 300031（token 过期） | 用站内搜索 + 搜索卡片新 token 方案（见 2.2），不要直接放弃 |
| 公众号文章无图片 | 正常归档文字，images_path 留空 |
| 小红书未登录 | 提示用户先在本机 Chrome 登录小红书（chrome-direct 复用其登录态） |
| 抖音/视频号解析失败 | 如实报告，提供 convry 页面 URL 让用户手动操作 |
| 视频下载失败 | 只归档文字信息，标记 extraction_status 为"部分完成" |
| 知识星球 401 | 运行 `zsxq-cli auth login` 重新走 OAuth 设备码 |
| 知识星球 403 | 当前账户不在目标星球内，无法抓取私有主题，如实告知 |
| 知识星球主题被星主删除 | 抓取失败，如实报告，不假装完成 |
| X 推文 url ≠ 预期（eval 返回 xierdun.vip 等） | chrome-direct session 复用旧标签页 → `session close` + 新 name + 去掉 URL 查询参数重开 |
| X 推文 wait stable 永远 timeout | x.com 后台 SSE 持续活动，**跳过 wait stable**，直接评估 article 是否就绪 |
| X 推文 `[data-testid="tweetText"]` 长度=0 | Twitter 懒加载文本节点 → 用 `article.innerText` 兜底拿正文 |
| X 推文图片只有 medium 尺寸 | 默认 `?format=jpg&name=medium`，手动改 `name=large` 拿原图 |
| X 推文反爬 403 / Cloudflare challenge | chrome-direct 登录态失效 → 兜底 syndication API（无需登录）；都不行再 stealth-extract |
| X 推文私密账号 / 未登录看不到 | 提示用户在 Chrome 登录 X，syndication API 也只能拿公开推文 |
| **Jina Reader 401 (AuthenticationRequiredError)** | "blocked due to bad network reputation (AS30058)"：Clash 出口节点在低信誉网络段。**换非 AS30058 节点** 或注册免费 Jina API key（10M tokens 一次性）|
| Jina Reader 401 普通（key 错） | 核对 `JINA_API_KEY` 是否设置正确 |
| Jina Reader 402 | key 额度用完，去 jina.ai 充值 |
| Jina Reader 429 | 限速，等 1 分钟；有 key 也撞限流的话换 key |
| Jina Reader 451 | 目标站点法律拒绝被抓取（如 NYT），无法绕过 |
| Jina Reader 返回空 content | 大概率登录墙，尝试 chrome-direct 或人工抓 |
| Jina JSON 解析报 `Invalid \escape` | X 长文里的 shell 命令 `\"` 转义问题。**改用 plain text 模式**（不带 `Accept: application/json`），§2.8 的 fetch_jina_article 已默认走 plain text |
| Jina 请求超时（60 秒） | JS-heavy 站点（X、Twitter），等；或拆开 URL 重试 |
| r.jina.ai DNS 污染（解析到 157.240.1.33） | 设置 `https_proxy`/`http_proxy` 走 Clash 7897 端口 |
| vault 目录不存在 | 自动创建 |

## 六、飞书远程触发说明

飞书双向通信配通后，用户在飞书发送链接给 WorkBuddy 机器人，WorkBuddy 收到消息后：
1. 解析消息文本，提取 URL
2. 调用本 skill 的抓取+归档流程
3. 完成后通过飞书回复摘要

---

_本 skill 覆盖公众号（强支持）、小红书（chrome-direct 复用 Chrome 登录态）、抖音/视频号/B站/快手/TikTok/YouTube（dousnap + 平台兜底）、知识星球（zsxq-cli 直连 API）、X 推特（Jina Reader 首选 + chrome-direct + syndication API 三入口）、通用网页（Jina Reader 统一入口）共 10 个平台。通用网页走 05.网页文字 目录。_
