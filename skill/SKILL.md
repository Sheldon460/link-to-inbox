---
name: link-to-inbox
description: "跨平台链接自动归档到 Obsidian 素材收件箱。输入一个链接（公众号/小红书/抖音/快手/B站/视频号/TikTok/YouTube/知识星球），自动识别平台、优先通过 dousnap 抓取完整内容（标题+描述+口播文案+封面+视频），知识星球走 zsxq-cli topic +detail，按格式归档到 Obsidian 02.素材收件箱。支持飞书远程触发。"
description_zh: "链接自动归档到 Obsidian 素材收件箱（dousnap + zsxq-cli 双入口）"
version: 1.7.0
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
按平台分发抓取（**优先 dousnap 入口**，convry/whisper 降级为兜底）：
  ├─ 公众号 (mp.weixin.qq.com) → WebFetch + curl 下载图片
  ├─ 小红书 (xhslink/xiaohongshu) → dousnap（首选）/ browser-act chrome-direct（兜底）
  ├─ 抖音 (douyin) → dousnap（首选）/ convry + Python（兜底）
  ├─ 快手 (kuaishou) → dousnap（新增）
  ├─ 视频号 (channels.weixin.qq.com) → dousnap（首选，绕开 macOS 保存面板）/ convry（兜底）
  ├─ B站 (bilibili.com) → dousnap（首选，字幕更准）/ yt-dlp + whisper.cpp（兜底）
  ├─ TikTok / YouTube → dousnap（新增）
  └─ 知识星球 (zsxq.com) → zsxq-cli topic +detail（直连 API）
  ↓
生成 Obsidian .md（带标准 frontmatter）
  ↓
下载附件到对应 media 目录
  ↓
回复摘要（飞书 / 对话）
```

### 优先 dousnap 的理由

[dousnap.com](https://www.dousnap.com/)（抖虫 DouChong）是一个统一的视频文案提取站点：
- ✅ 支持 7 个平台：抖音/小红书/快手/B站/视频号/TikTok/YouTube
- ✅ 一次拿到：标题 + 描述 + 口播文案（带【画面】【旁白】结构）+ 封面图 + 视频下载
- ✅ 完全免费、无需登录、无需人机验证
- ✅ 视频号场景不再依赖 macOS 保存面板（远程无人值守）
- ✅ B 站用官方字幕提取，比 whisper ASR 更准

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
| vault 目录不存在 | 自动创建 |

## 六、飞书远程触发说明

飞书双向通信配通后，用户在飞书发送链接给 WorkBuddy 机器人，WorkBuddy 收到消息后：
1. 解析消息文本，提取 URL
2. 调用本 skill 的抓取+归档流程
3. 完成后通过飞书回复摘要

---

_本 skill 覆盖公众号（强支持）、小红书（chrome-direct 复用 Chrome 登录态）、抖音/视频号/B站/快手/TikTok/YouTube（dousnap + 平台兜底）、知识星球（zsxq-cli 直连 API）共 9 个平台。通用网页走 05.网页文字 目录。_
