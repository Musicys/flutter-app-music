下面是完整的 Markdown 版接口文档，可直接保存为 `Meting-API.md` 使用。

---

# Meting API 接口文档

> 基于 Meting 的音乐元数据与资源获取接口，支持网易云音乐、QQ 音乐双数据源。

## 1. 基本信息

| 项目 | 说明 |
|---|---|
| 接口地址 | `https://api.qijieya.cn/meting/` |
| 请求方式 | `GET` |
| 参数形式 | Query String（URL 查询参数） |
| 编码 | UTF-8 |
| 鉴权 | 无需鉴权（公开接口） |
| 数据源 | `netease`（网易云音乐，默认）、`tencent`（QQ 音乐） |

**完整请求格式：**

```
GET https://api.qijieya.cn/meting/?server={server}&type={type}&id={id}&{其他可选参数}
```

---

## 2. 请求参数

### 2.1 公共参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|---|---|---|---|---|
| `server` | string | 否 | `netease` | 数据源。可选值：`netease`（网易云音乐）、`tencent`（QQ 音乐） |
| `type` | string | **是** | — | 返回数据类型，详见 §3 |
| `id` | string | **是** | — | 类型对应的 ID。`type=search` 时填**搜索关键词** |

### 2.2 条件参数

| 参数 | 类型 | 生效条件 | 必填 | 默认值 | 可选值 | 说明 |
|---|---|---|---|---|---|---|
| `page` | int | `type=search` | 否 | `1` | ≥1 | 搜索页码 |
| `limit` | int | `type=search` | 否 | `30` | ≥1 | 每页返回条数 |
| `search_type` | int | `type=search` | 否 | `1` | `1` | 平台搜索类型 |
| `br` | int | `type=url` | 否 | `320` | `2000` / `320` / `192` / `128` | 音质参数 |
| `cover` | int | `type=pic` | 否 | `300` | `300` / `500` | 封面分辨率 |
| `size` | int | `type=pic` | 否 | `300` | `300` / `500` | 旧版兼容参数，与 `cover` 等价 |

**音质对照表（`br`）：**

| 值 | 音质 |
|---|---|
| `2000` | FLAC 无损 |
| `320` | 320kbps（默认） |
| `192` | 192kbps |
| `128` | 128kbps |

---

## 3. type 取值说明

| type | 说明 | id 含义 | 主要返回内容 |
|---|---|---|---|
| `name` | 歌曲名 | 单曲 ID | 歌曲名称 |
| `artist` | 歌手 | 单曲 ID | 歌手信息 |
| `url` | 播放链接 | 单曲 ID | 音频直链 |
| `pic` | 封面图 | 单曲 ID / 封面 ID | 封面图片地址 |
| `lrc` | 歌词 | 单曲 ID | LRC 格式歌词文本 |
| `song` | 单曲详情 | 单曲 ID | 单曲完整信息 |
| `search` | 搜索 | **搜索关键词** | 匹配的歌曲列表 |
| `playlist` | 歌单 | 歌单 ID | 歌单信息及曲目列表 |

---

## 4. 请求示例

### 4.1 获取歌曲播放链接

```bash
curl "https://api.qijieya.cn/meting/?type=url&id=1969519579"
```

```javascript
// 浏览器 / Node.js
const res = await fetch('https://api.qijieya.cn/meting/?type=url&id=1969519579');
const data = await res.json();
console.log(data);
```

```python
# Python
import requests

resp = requests.get(
    "https://api.qijieya.cn/meting/",
    params={"type": "url", "id": "1969519579"}
)
print(resp.json())
```

**指定 QQ 音乐数据源：**

```bash
curl "https://api.qijieya.cn/meting/?server=tencent&type=url&id=1969519579"
```

### 4.2 获取 FLAC 无损音质

```bash
curl "https://api.qijieya.cn/meting/?type=url&id=416892104&br=2000"
```

```python
resp = requests.get(
    "https://api.qijieya.cn/meting/",
    params={"type": "url", "id": "416892104", "br": 2000}
)
```

> 说明：`br=2000` 为 FLAC 无损，非 VIP 用户或版权受限时可能返回失败或降级音质。

### 4.3 获取封面图

```bash
# 默认 300px
curl "https://api.qijieya.cn/meting/?type=pic&id=416892104"

# 指定 500px
curl "https://api.qijieya.cn/meting/?type=pic&id=416892104&cover=500"

# 旧版兼容参数
curl "https://api.qijieya.cn/meting/?type=pic&id=416892104&size=500"
```

### 4.4 获取单曲详情

```bash
curl "https://api.qijieya.cn/meting/?type=song&id=591321"
```

```javascript
const res = await fetch('https://api.qijieya.cn/meting/?type=song&id=591321');
const song = await res.json();
// song.name / song.artist / song.pic / song.url / song.lrc
```

### 4.5 搜索歌曲

```bash
# 基础搜索
curl "https://api.qijieya.cn/meting/?type=search&id=周杰伦"
```json

[{"name":"\u5e03\u62c9\u683c\u5e7f\u573a","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=210049","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951172453712025","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=210049"},{"name":"\u60f3\u4f60\u5c31\u5199\u4fe1 (Live)","artist":"\u5468\u6770\u4f26\/\u674e\u7855\/\u5f20\u946b","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=509781655","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951163038292176","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=509781655"},{"name":"\u5c4b\u9876","artist":"\u5468\u6770\u4f26\/\u6e29\u5c9a\/\u5434\u5b97\u5baa","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=5257138","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165671182684","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=5257138"},{"name":"\u9ed8 (Live)","artist":"\u674e\u8363\u6d69\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=1888354230","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951166537300832","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=1888354230"},{"name":"\u56e0\u4e3a\u7231\u60c5 (Live)","artist":"\u5468\u6770\u4f26\/\u90a3\u82f1","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=490595315","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=18892908300315027","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=490595315"},{"name":"\u5200\u9a6c\u65e6","artist":"\u674e\u739f\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=255020","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165959446596","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=255020"},{"name":"\u9a91\u58eb\u7cbe\u795e","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=210062","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951172453712025","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=210062"},{"name":"\u5c4b\u9876 (Live)","artist":"\u5468\u6770\u4f26\/\u5bbf\u6db5\/\u5f20\u795e\u513f","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=1317494434","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951163604724077","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=1317494434"},{"name":"\u6d77\u76d7","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=209917","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951170708258712","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=209917"},{"name":"\u5c71\u6b4c\u597d\u6bd4\u6625\u6c5f\u6c34.\u591a\u8c22\u4e86(Live)","artist":"\u5b8b\u7956\u82f1\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=288750","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=871912720826764","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=288750"},{"name":"\u4e4c\u514b\u4e3d\u4e3d (Live)","artist":"\u5468\u6770\u4f26\/\u9648\u9896\u6069\/\u8096\u90a6\u59ae\/\u6731\u6587\u5a77","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=509781651","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951163038292176","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=509781651"},{"name":"Try (Kung Fu Panda 3 Official Theme Song)","artist":"\u6d3e\u4f1f\u4fca\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=400876427","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951166326634933","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=400876427"},{"name":"\u4e00\u7b11\u800c\u8fc7 + \u4f60\u7684\u80cc\u5305 (Live)","artist":"\u5468\u6770\u4f26\/\u5218\u6b22","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=490602323","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=18892908300315027","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=490602323"},{"name":"\u6ca7\u6d77\u4e00\u58f0\u7b11 (Live)","artist":"\u90a3\u82f1\/\u5468\u6770\u4f26\/\u5218\u6b22\/\u9648\u5955\u8fc5","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=490602328","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=18892908300315027","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=490602328"},{"name":"\u5200\u9a6c\u65e6","artist":"\u674e\u739f\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=254832","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951170501372101","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=254832"},{"name":"\u9a91\u58eb\u7cbe\u795e","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=209659","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165958730017","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=209659"},{"name":"\u53ea\u6709\u4e3a\u4f60 + \u5b89\u9759 + \u4e0d\u7ba1\u6709\u591a\u82e6 + \u6ee1 + \u6211\u8981\u590f\u5929 (Live)","artist":"\u90a3\u82f1\/\u6c6a\u5cf0\/\u5ebe\u6f84\u5e86\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=421160888","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=3394192410959263","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=421160888"},{"name":"\u5e03\u62c9\u683c\u5e7f\u573a","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=5234479","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=605830906916387","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=5234479"},{"name":"\u6d77\u76d7","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=400581225","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165958770652","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=400581225"},{"name":"\u5e03\u62c9\u683c\u5e7f\u573a","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=185790","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951171358446171","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=185790"},{"name":"\u9a91\u58eb\u7cbe\u795e","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=400161918","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165958812099","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=400161918"},{"name":"\u5200\u9a6c\u65e6","artist":"\u5468\u6770\u4f26\/\u674e\u739f","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=5257160","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165671182684","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=5257160"},{"name":"\u5200\u9a6c\u65e6","artist":"\u674e\u739f\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=1372847156","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165986697918","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=1372847156"},{"name":"\u7ed3\u5c3e\u66f2-\u53cb\u8c0a\u5730\u4e45\u5929\u957f(Live)","artist":"\u5b8b\u7956\u82f1\/\u90ce\u6717\/\u591a\u660e\u6208\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=288820","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=871912720826764","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=288820"},{"name":"\u5200\u9a6c\u65e6","artist":"\u674e\u739f\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=400161754","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165986730839","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=400161754"},{"name":"\u9ec4\u6d66\u6c5f\u6df1","artist":"\u5b8b\u7956\u82f1\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=518076026","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951163062543313","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=518076026"},{"name":"\u8ba9\u6211\u4e00\u6b21\u7231\u4e2a\u591f + \u56e0\u4e3a\u7231\u6240\u4ee5\u7231 + \u629a\u4ed9\u6e56 + \u7b49\u4f60\u4e0b\u8bfe + \u970d\u5143\u7532 + \u4e07\u91cc\u957f\u57ce\u6c38\u4e0d\u5012 (Live)","artist":"\u5ebe\u6f84\u5e86\/\u5468\u6770\u4f26\/\u8c22\u9706\u950b\/\u674e\u5065","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=866049359","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951163409765276","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=866049359"},{"name":"\u5e03\u62c9\u683c\u5e7f\u573a","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=209660","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165958730017","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=209660"},{"name":"\u5e03\u62c9\u683c\u5e7f\u573a","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=400162858","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951165958812099","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=400162858"},{"name":"\u5200\u9a6c\u65e6","artist":"\u5468\u6770\u4f26\/\u674e\u739f","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=5268828","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=75866302334161","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=5268828"}]
```
# 指定返回 5 条
curl "https://api.qijieya.cn/meting/?type=search&id=周杰伦&limit=1"
[{"name":"\u5e03\u62c9\u683c\u5e7f\u573a","artist":"\u8521\u4f9d\u6797\/\u5468\u6770\u4f26","url":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=url&id=210049","pic":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=pic&id=109951172453712025","lrc":"https:\/\/api.qijieya.cn\/meting\/?server=netease&type=lrc&id=210049"}]
# 翻页：第 2 页，每页 10 条
curl "https://api.qijieya.cn/meting/?type=search&id=周杰伦&page=2&limit=10"
```

```python
resp = requests.get(
    "https://api.qijieya.cn/meting/",
    params={
        "type": "search",
        "id": "周杰伦",      # 关键词直接作为 id 传入
        "limit": 5,
        "page": 1
    }
)
results = resp.json()
for item in results:
    print(item.get("name"), item.get("artist"), item.get("id"))
```

> ⚠️ 中文关键词需 URL 编码。使用 `requests` / `fetch` 的 params 传参时会自动编码；手动拼接 URL 时请自行 `encodeURIComponent("周杰伦")`。

### 4.6 获取歌单

```bash
curl "https://api.qijieya.cn/meting/?type=playlist&id=2619366284"
```[
[
  {
    "name": "溟淬",
    "artist": "慕客",
    "url": "https://api.qijieya.cn/meting/?server=netease&type=url&id=3354563193",
    "pic": "https://api.qijieya.cn/meting/?server=netease&type=pic&id=109951173089824277",
    "lrc": "https://api.qijieya.cn/meting/?server=netease&type=lrc&id=3354563193"
  },
  {
    "name": "Revival",
    "artist": "TQ☆",
    "url": "https://api.qijieya.cn/meting/?server=netease&type=url&id=401722088",
    "pic": "https://api.qijieya.cn/meting/?server=netease&type=pic&id=6046214441318535",
    "lrc": "https://api.qijieya.cn/meting/?server=netease&type=lrc&id=401722088"
  },]

```javascript
const res = await fetch('https://api.qijieya.cn/meting/?type=playlist&id=2619366284');
const playlist = await res.json();
console.log(playlist.name, playlist.tracks?.length);
```

### 4.7 获取歌词

```bash
curl "https://api.qijieya.cn/meting/?type=lrc&id=1969519579"
```

返回为 LRC 纯文本，形如：

```
[00:00.00] 歌曲名 - 歌手
[00:05.12] 第一句歌词
[00:09.88] 第二句歌词
```

### 4.8 获取歌曲名 / 歌手

```bash
curl "https://api.qijieya.cn/meting/?type=name&id=1969519579"
curl "https://api.qijieya.cn/meting/?type=artist&id=1969519579"
```

---

## 5. 返回数据说明

> 以下为各 type 的**典型返回结构**，实际字段以接口真实响应为准，建议先用 `type=song` 拉取一次确认字段名。

### 5.1 type=song / name / artist

```json
{
  "id": "1969519579",
  "name": "歌曲名称",
  "artist": "歌手名称",
  "album": "专辑名称",
  "pic": "https://p1.music.126.net/xxx.jpg",
  "url": "https://m701.music.126.net/xxx.mp3",
  "lrc": "[00:00.00]...",
  "br": 320
}
```

`type=name` 仅返回歌曲名，`type=artist` 仅返回歌手，可能为纯字符串或精简对象。

### 5.2 type=url

返回音频直链，可能为纯字符串或包含地址的对象：

```json
{
  "url": "https://m701.music.126.net/xxxx.mp3",
  "br": 320
}
```

> 直链通常**有时效性**（数分钟至数小时），不要长期缓存，播放前应实时获取。

### 5.3 type=pic

```json
{
  "pic": "https://p1.music.126.net/xxx.jpg",
  "size": 500
}
```

### 5.4 type=lrc

返回 LRC 格式纯文本（`Content-Type: text/plain`），非 JSON。

### 5.5 type=search

```json
[
  {
    "id": "1969519579",
    "name": "歌曲名称",
    "artist": "歌手名称",
    "album": "专辑名称",
    "pic": "https://p1.music.126.net/xxx.jpg"
  }
]
```

### 5.6 type=playlist

```json
{
  "id": "2619366284",
  "name": "歌单名称",
  "cover": "https://p1.music.126.net/xxx.jpg",
  "tracks": [
    { "id": "1969519579", "name": "歌曲名称", "artist": "歌手名称" }
  ]
}
```

---

## 6. 错误与异常

| 情况 | 表现 | 处理建议 |
|---|---|---|
| 缺少必填参数 | 返回错误信息或空结果 | 检查 `type`、`id` 是否传入 |
| ID 不存在 | 返回空对象 / 错误提示 | 校验 ID 与 `server` 是否匹配（网易 ID 不能用于 tencent） |
| VIP / 版权受限 | `url` 为空或返回失败 | 换用其他 `br`，或改用另一数据源 |
| 直链过期 | 播放 403 / 无响应 | 重新请求获取新链接，勿缓存 |
| 频率限制 | 返回 429 或空 | 增加请求间隔，避免高频轮询 |

**通用错误判断建议：**

```javascript
const res = await fetch(url);
if (!res.ok) throw new Error(`HTTP ${res.status}`);
const data = await res.json();
if (!data || (typeof data === 'object' && !Object.keys(data).length)) {
  throw new Error('接口返回为空，可能是 ID 无效或版权受限');
}
```

---

## 7. 注意事项

1. **ID 与数据源必须对应**：网易云的歌单/单曲 ID 不能用于 `server=tencent`，反之亦然。
2. **中文参数需编码**：`type=search` 传关键词时务必做 URL 编码。
3. **播放链接有时效**：不要持久化存储 `url`，应在播放时实时获取。
4. **FLAC 不保证可用**：`br=2000` 依赖账号权限与版权，失败时建议回退到 `320`。
5. **`cover` 与 `size` 二选一**：`size` 为旧版兼容参数，新接入建议使用 `cover`。
6. **遵守平台条款**：本接口用于个人学习与开发测试，请勿用于商业分发或大规模爬取，注意尊重音乐版权。
7. **接口稳定性**：第三方代理接口可能随时变更或失效，生产环境建议做好降级与容错。

---

## 8. 快速参考（全部示例一览）

| 场景 | 请求 URL |
|---|---|
| 播放链接 | `?type=url&id=1969519579` |
| FLAC 音质 | `?type=url&id=416892104&br=2000` |
| 封面 500px | `?type=pic&id=416892104&cover=500` |
| 单曲详情 | `?type=song&id=591321` |
| 搜索（5 条） | `?type=search&id=周杰伦&limit=5` |
| 歌单 | `?type=playlist&id=2619366284` |
| 歌词 | `?type=lrc&id=1969519579` |
| QQ 音乐源 | `?server=tencent&type=url&id=xxxx` |

---

需要我再补一份 **Postman Collection（JSON）** 或 **TypeScript 类型定义 + 封装好的调用类**吗？另外，由于返回字段我是按 Meting 通用结构推断的，建议你实际跑一次 `type=song` 和 `type=search`，把真实响应发我，我可以把 §5 的示例校准成准确字段。