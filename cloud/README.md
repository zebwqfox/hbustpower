# 版本与公告文件

应用会读取这一个静态 JSON，用来提示新版本、显示公告、在学校页面改版时临时关掉某个入口。
**它只被读取，不接收任何业务数据**；请求不带 Cookie、不带设备标识，只附带一个用于绕过 CDN 旧缓存的 `cacheBust` 当前时间戳参数。

## 放在哪

| 文件 | 位置 | 为什么 |
|---|---|---|
| `config.json` | `https://hbustelec.imfurry.com/app/config.json` | 几 KB，改起来快，和隐私政策网页同一个站点 |
| `HBUSTPower-Android-x.y.z-release.apk` | `https://cdn-imfurry.imfurry.com/update-release/` | 安装包大，走 CDN 便宜、带宽稳 |

两处都必须是 **HTTPS**。应用只接受 `cloudDownloadHosts` 里列出的域名作为下载地址，
其他地址会被直接丢掉——这样即使 `config.json` 被改动，也没法把用户引到陌生页面。

## 怎么配到构建里

`android/gradle.properties`：

```properties
cloudConfigUrl=https://hbustelec.imfurry.com/app/config.json
cloudDownloadHosts=cdn-imfurry.imfurry.com
```

`cloudConfigUrl` 留空时整个功能不编译进去：不发请求，设置里也不显示"检查更新"。
也可以临时覆盖：`./gradlew assembleRelease -PcloudConfigUrl=https://...`

## 字段

顶层每个字段都可以省略；省略即"这次没有这项内容"。旧版本读到新字段会忽略，不会崩。

| 字段 | 说明 |
|---|---|
| `update.versionCode` | 必填，整数。大于用户当前的 `versionCode` 才会提示 |
| `update.versionName` | 必填，显示给用户看的版本号，例如 `1.9.3` |
| `update.notes` | 字符串数组，每条一行，写清楚改了什么 |
| `update.downloadUrl` | HTTPS，且域名在 `cloudDownloadHosts` 里，否则被丢弃 |
| `update.sha256` | 可选，64 位小写十六进制，方便用户自己校验 |
| `update.sizeBytes` | 可选，显示成 `9.0 MB` |
| `notice.id` | 必填。用户关掉的是这个 id；改了文字想重新弹，就换一个 id |
| `notice.title` / `notice.body` | `body` 必填，纯文字，不支持 HTML |
| `notice.level` | `info`（默认）或 `warning`，后者用警示色 |
| `notice.expiresAt` | Unix 秒。到点自动消失，**建议每条公告都写**，忘了撤也不会一直挂着 |
| `notice.dismissible` | 默认 `true`。设 `false` 则不给关闭按钮，慎用 |
| `flags` | 布尔开关。缺省视为 `true`：读不到文件时所有功能照常 |
| `minSupportedVersionCode` | 低于它的版本会看到"请更新"，但仍然可以继续用 |

可用的开关：`campusCard`、`recharge`、`updateCheck`。其中 `updateCheck=false` 会隐藏版本提示和
手动检查入口，但不会停止读取这个配置文件，否则它无法再被远程开启，公告和其他开关也无法恢复。

## 用起来

- **每次启动都查一次**；回到前台也查，但最多每 30 分钟一次；用户手动点「检查更新」则每次都查。
  功能开关是拿来救急的——学校页面改版了要立刻关掉某个入口，等一天就没意义了。
- 带 `ETag` 请求，没改动时源站返回 304，只有几百字节。客户端同时附带 `cacheBust` 时间戳，
  避免共享缓存继续返回发布前的旧配置。
- 响应超过 64 KB 会被拒绝。
- 拉取失败时应用一切照常，静默失败；只有手动检查才会提示错误。

## 不要往里加的东西

- 接口地址、脚本、任何要执行的内容。下发可执行内容属于热更新，备案口径完全不同，
  见 `filing/07-域名与服务器说明.md`。
- 任何用户数据相关的字段。这个文件是单向的，服务端不知道谁读了它。
