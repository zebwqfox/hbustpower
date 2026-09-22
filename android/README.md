# 湖科电量 Android 1.9.3

包名 `com.zebwqfox.hbustpower`。原生 Kotlin + Jetpack Compose，基于仓库内 iOS 客户端的功能开发。五个标签：电量、用量、充值记录、校园卡、设置；另有关于、更新日志、调试与诊断、记录详情、学习通登录和官方充值页。

## 构建

需要 Android SDK Platform 37、Build Tools 36+、JDK 17–26。项目自带 Gradle Wrapper。

```powershell
cd android
.\gradlew.bat testDebugUnitTest assembleDebug
```

- 调试 APK：`app/build/outputs/apk/debug/app-debug.apk`
- Release（R8 压缩，暂用 debug 签名，发布前换成正式 keystore）：`.\gradlew.bat assembleRelease`

Windows 注意：如果 Gradle 报 `Unable to establish loopback connection`，把 JDK 的临时目录指向一个短的纯英文路径：

```powershell
$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:\hbtmp -Djava.io.tmpdir=C:\hbtmp"
```

## 合规与备案

- 首次启动先显示《隐私政策》《用户服务协议》同意页，**未同意前不联网、不申请权限**；不同意直接退出。
- 两份文本由 `filing/` 下的 Markdown 经 `tools/sync-legal.py` 同步到 `assets/legal/`，应用内、网页版、备案材料始终一致。改动实质内容时把 `LegalDocuments.CONSENT_VERSION` 加 1，老用户会重新看到同意页。
- 关于页预留备案号展示位：备案通过后填 `res/values/strings.xml` 的 `icp_filing_number` 即显示。
- release 签名从 `keystore.properties` 读取（已 gitignore）；`tools/Get-FilingSignature.ps1` 可导出备案要填的应用公钥与签名 MD5/SHA-1/SHA-256。
- 备案材料与办理步骤见仓库根目录的 `filing/`。

## 学校数据

应用使用学校指定的学习通授权入口（`data/SchoolEndpoints.kt`），用户无需配置。

## 检查更新与公告

应用读取一个放在自有站点上的静态 JSON，用来提示新版本、显示公告、在学校页面改版时临时关掉某个入口。
**只读取、不上传**：普通 GET，不带 Cookie、参数或设备标识；发现新版本也只是弹提示，安装包由用户在浏览器里自行下载。
没有任何形式的代码热更新——下发内容只有版本号、文字和布尔开关。

```properties
# android/gradle.properties
cloudConfigUrl=https://hbustelec.imfurry.com/app/config.json
cloudDownloadHosts=cdn-imfurry.imfurry.com
```

`cloudConfigUrl` 留空时整个功能不编译进去：不发请求，设置里也不显示“检查更新”。
文件格式与托管说明见 `cloud/README.md`，示例见 `cloud/config.example.json`。
`cloudDownloadHosts` 之外的下载地址会被直接丢弃，即使 JSON 被篡改也没法把用户引到陌生页面。

代码在 `data/CloudConfig*.kt`：`CloudConfig` 只做解析与判断（纯 Kotlin，可单测），
`HttpCloudConfigFetcher` 负责一次带 ETag、限 64 KB 的请求，`CloudConfigRepository` 管缓存、每日一次的节流
和“跳过这个版本”“关掉这条公告”的记录。

## 匿名使用统计（默认开启，可在同意隐私政策前关掉）

`data/Telemetry.kt`。每天最多一次，上报应用版本、系统版本、机型、ABI、语言、渠道，和一个
App 自己 `UUID.randomUUID()` 出来的安装标识——不读 IMEI / OAID / Android ID，不含账号、宿舍号、电量。

默认是开的，但**开关就在隐私同意页上、「同意并继续」按钮的正上方**，用户在同意之前就能关掉；关掉的话
连安装标识都不会生成。此后在 设置 → 帮助改进 里也能随时关，关闭时本机标识一并删除。

这个「默认开启但摆在明面上」的形态是刻意的：悄悄默认开启在备案口径上站不住，
而藏在设置深处的开关拿不到有意义的样本。`PrivacyConsentScreen` 的那个开关不要挪走。

```properties
telemetryUrl=https://hbustelec.imfurry.com/api/v1/report
```

留空则整个功能不编译进去，设置里也不出现这一项。

隐私政策第六条逐条写了这些承诺，`app/src/test/.../TelemetryTest.kt` 逐条测了它们。**改这里之前先看那些测试。**
收数据的面板在另一个仓库（`hbustpower-admin`），不在这里。

## 实现要点

| 模块 | 位置 |
|---|---|
| HTML 解析（1.6.2 规则，逐项对照 `fixtures/expected-1.7.1.json`） | `data/ElectricityHtmlParser.kt` |
| 数据请求：先 home，再并行 use/pay record；401/403/登录页判为失效；UTF-8→GB18030 | `data/ElectricityService.kt` |
| Cookie：WebView `CookieManager` 作为唯一 Cookie 库，原生请求手动跟随重定向并写回，避免两套存储不同步 | `data/SessionHttpClient.kt` |
| 授权链接保存：Android Keystore AES-GCM 加密；禁止备份 | `data/Storage.kt` |
| 登录：学习通原生表单（JSON 编码参数注入官方 HTTPS 表单）；验证码等切到官方页面；门户自动进入宿舍电费；精确校验 redirect | `ui/screens/LoginScreen.kt`、`assets/scripts/*.js`（iOS 脚本原文） |
| 校园卡：授权后沿用同一个 WebView（保留 sessionStorage），25 秒总超时 | `ui/CampusCardController.kt` |
| 低电量提醒：严格小于阈值、系统接受后才记录、回升重置、换房/换阈值重新判断、串行化 | `notification/LowBalanceReminder.kt` |
| 首次引导 | `model/FirstRunFlow.kt` |
| 电量水位（重力符号已按 Android 反转）、手绘下划线、贴纸、下拉“充电” | `ui/components/` |
| 用电小发现、分享卡片（Canvas 绘制 900×600，不截屏） | `model/UsageInsights.kt`、`ui/screens/ShareCard.kt` |
| 宽屏两栏（宽度 ≥600dp）、FoldingFeature 折痕避让、不对称安全区 | `ui/PowerLayout.kt`、`ui/screens/OverviewScreen.kt` |
| 下拉“充电”四态：就绪（琥珀 + 火花 + 触觉）、充电中（旋转 + 光晕 + 文案轮换）、成功（绿色对勾 + 水位晃动）、失败（橙色摇头） | `ui/components/ChargeRefresh.kt` |
| 充值计算器（按金额 / 按日期 / 室友分摊）与充值记录汇总卡 | `model/RechargePlanner.kt`、`ui/screens/RechargePlannerSheet.kt` |
| 三套主题（湖科蓝 / 紫鸟紫 / 枫烻黄）与《飞鸟集》卡片 | `model/PowerThemeStyle.kt`、`ui/screens/ThemePickerScreen.kt` |

所有新动效在“移除动画”（动画时长缩放为 0）时保持静止。

## 测试

79 项 JVM 单元测试：解析器与 iOS 生成的预期结果、redirect 校验、服务层失效判断、学校地址规则、估算与小发现、低电量去重、首次引导状态机、更新日志（最新版本号 = versionName、从新到旧、分组非空）、头像彩蛋、水位倾斜方向、下拉充电文案、图表刻度与三段用量切换、贴纸阈值、手绘线确定性、下拉充电各阶段文案与圆环、充值计算器（与 iOS 单测逐例对照）、充值汇总跳过缺失字段、主题唯一性与持久化、《飞鸟集》循环、云端配置解析（畸形输入不抛异常、未知字段忽略、下载地址域名校验、公告过期与关闭、开关缺省为开）与仓储（每日节流、ETag 往返、失败不覆盖已有缓存、跳过版本、强制升级）、匿名统计（默认开启、关闭后彻底停发且不生成标识、关闭即删除标识、每日节流、字段白名单）。

## 已在模拟器（Android 16，1080×2400）验证

- 界面：首次引导、欢迎页、学习通登录、演示首页（水位/贴纸/手绘线/小发现）、用量图表选日、充值记录、校园卡、设置、关于页与第 7 次点击彩蛋、更新日志。
- 交互：下拉“充电”（圆环旋转、闪电正立、刷新按钮禁用）、余额卡长按菜单、分享电量卡片（Canvas 绘制的图片，不是截屏）、充值记录长按预览与菜单。
- 通知：申请权限、即时测试通知、10 秒延迟通知（后台送达）、低电量提醒真实去重链路——首次提醒 → 重复检查不再提醒 → 模拟回升后重新提醒（调试页的“模拟低电量检查”仅 Debug 构建可见，不改变已显示的电量）。
- 适配：深色模式、大字体（fontScale 1.8，卡片自动改为纵向排列）、关闭动画（动画时长缩放为 0）、横屏（紧凑图表 + 侧边导航栏）、2560×1600 宽屏两栏。

验证过程中修复的问题：未配置授权时系统返回键直接退出应用；深色模式部分文字为黑色；内容滚动到状态栏下方；横屏（短窗口）图表过高；侧边导航栏 5 个标签在横屏放不下；延迟测试通知在后台被系统推迟而不送达。

## 仍需真机 / 真实账号验证

- 真实学习通登录、门户自动进入电费、去掉 uid 后的不同账号
- 校园卡真实余额读取；官方充值页与支付 App 跳转
- WebView 在 Android 9+ 上对学校 http 域名的明文访问（`network_security_config.xml` 只放行两个学校域名）
- 真机厂商的通知与后台限制（模拟器上即时/延迟/低电量提醒均已送达）
- 手机左右倾斜时水位方向、折叠屏半折叠时的折痕避让、TalkBack 朗读
- 检查更新与匿名统计的真实链路：本机没有 Android SDK，`data/CloudConfig*.kt`、`data/Telemetry.kt` 及相关界面改动**尚未编译验证**，需在 Windows 上先跑 `.\gradlew.bat testDebugUnitTest assembleDebug`

## 与早期 Android 版本的差异

- 底部导航改用 Material 3 标准导航栏（宽屏为侧边导航栏），遵循 1.7.1 交接要求“不要自绘底栏”。原 Liquid Glass 底栏代码（`ui/components/LiquidBottom*.kt` 等）保留在工程中但未使用。
- 不再注册常驻前台服务和开机自启：iOS 没有全天后台轮询，交接要求不以常驻服务绕过用户选择。`background/` 下旧代码未在清单中声明，可按需删除。
