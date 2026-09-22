<div align="center">

# 湖科电量

湖北科技学院宿舍电量查询的 iOS 与 Android 客户端。

简体中文 · [English](README.md)

[![Platforms](https://img.shields.io/badge/platforms-iOS%2026%2B%20%7C%20Android%206%2B-2563EB)](#环境要求)
[![Languages](https://img.shields.io/badge/Swift%20%7C%20Kotlin-native-F05138)](#环境要求)
[![Tests](https://img.shields.io/badge/tests-71-2EA043)](#测试)

<img src="docs/screenshots/home-light.png" width="250" alt="首页" />
<img src="docs/screenshots/home-dark.png" width="250" alt="深色模式" />
<img src="docs/screenshots/usage-light.png" width="250" alt="用量图表" />

</div>

## 为什么做这个

在智慧湖科里看一眼宿舍还剩多少电，要点好几层。这个应用把最常看的两个数字放在第一屏：还剩多少度，大概还能用几天。

数据直接来自学校自己的网页服务，中间没有我的服务器，密码也不会被保存。

## 功能

| | |
|---|---|
| 电量 | 剩余度数、预计可用天数、补助和电价 |
| 用量 | 近 7 天照明与空调分开的柱状图，可以点或拖动查看某一天 |
| 充值记录 | 带汇总卡的历史记录，单条可以看完整字段 |
| 校园卡 | 通过官方一卡通门户读取余额，多张卡显示合计 |
| 低电量提醒 | 电量首次低于设定值时发一条本地通知 |
| 调试与诊断 | 通知和会话状态、刷新耗时，以及可复制的脱敏报告 |

除了这些基础功能，还有几个小东西：

- **电量水位**。余额卡像个水箱，剩得越多水位越高。倾斜手机液面会跟着晃，横向拨动水会跟着手指走。
- **下拉充电**。下拉到位松手，圆环开始旋转并冒火花；成功变绿打勾，失败变橙摇头。
- **用电小发现**。可以左右滑的小卡片：这周比上周省了 12%、连续 3 天低于平均、空调占了 81%、剩余电量约值 ¥57、上次充值是 12 天前。
- **充值计算器**。选金额看能用到哪天，或者选日期看至少要充多少钱；按宿舍人数分摊，复制一句话直接发群里。
- 手绘下划线、有点歪的贴纸、关于页上贴着胶带的便签，还有一个彩蛋。

### 主题

**设置 → 外观** 里有三套配色，其中两套以朋友命名。

| 主题 | 配色 | 额外的小东西 |
|---|---|---|
| 湖科蓝 | 云白配清蓝 | 应用原本的样子 |
| 紫鸟紫 | 夜色紫配琥珀橙 | 每次打开显示一句《飞鸟集》 |
| 枫烻黄 | 暖黄配项圈红 | 点一下会摇的铃铛 |

切换主题后整个界面一起变：卡片、图表、水位、火花，还有小组件。

<div align="center">
<img src="docs/screenshots/theme-picker.png" width="240" alt="主题" />
<img src="docs/screenshots/about.png" width="240" alt="关于页" />
<img src="docs/screenshots/changelog.png" width="240" alt="更新日志" />
</div>

### 小组件

桌面的小号和中号，加上锁屏的三种样式。颜色跟随当前主题，电量偏低时变成提醒色。

<div align="center">
<img src="docs/screenshots/widgets.png" width="300" alt="小组件预览" />
</div>

> 小组件通过 App Group（`group.com.local.hbustpower`）读取应用的数据，而 App Group 需要付费开发者账号。用免费 Apple ID 侧载时扩展能装上，但拿不到共享存储，小组件会一直显示“打开一次湖科电量”。**设置 → 调试与诊断 → 小组件** 里能看到共享存储到底有没有生效。

### 折叠屏与大屏

布局按尺寸类判断，不看屏幕宽高，也不看横竖屏。

- 展开的内屏和 iPad 上是左右等宽两栏，外屏和普通手机上是单栏。
- 半折叠时，两栏之间的间隙会对准 `reservedRegions(kind: .division)`（iOS 27.1+）返回的折痕位置，交互控件不会压在折痕上。
- 内容避开左右不对称的安全区，外屏右侧的竖向工具栏不会挡住东西。
- 在 iPhone Duo 模拟器上测过四种形态：外屏、内屏横向、内屏竖向、半折叠。

<div align="center">
<img src="docs/screenshots/duo-inner.png" width="370" alt="展开的内屏" />
<img src="docs/screenshots/duo-half-folded.png" width="370" alt="半折叠" />
</div>

<details>
<summary>更多界面</summary>

<div align="center">
<img src="docs/screenshots/records-light.png" width="230" alt="充值记录" />
<img src="docs/screenshots/campus-card-1.6.0.png" width="230" alt="校园卡" />
<img src="docs/screenshots/settings-light.png" width="230" alt="设置" />
<img src="docs/screenshots/xuexitong-glass-1.4.5.png" width="230" alt="登录" />
</div>

</details>

## 隐私

- 登录在学校自己的学习通页面完成，应用只是把你输入的内容填进官方表单，不保存密码。
- 只保存授权链接；iOS 使用钥匙串，Android 使用 Android Keystore 加密。
- 没有后端，所有请求直接发给学校。
- 诊断信息不含账号、宿舍号、授权链接和 Cookie 内容。
- 授权跳转链接严格校验：主机和路径完全匹配，`appId=180` 和 token 各出现一次且 token 非空。

## 开始使用

### iOS 环境要求

- Xcode 26 或更高（iPhone Duo 模拟器需要 27.1+）
- iOS 26 或更高
- 想让小组件显示真实数据，需要付费开发者账号

### iOS 编译运行

```sh
git clone https://github.com/zebwqfox/hbustpower.git
cd hbustpower/ios
open HBUSTPowerIOS.xcodeproj
```

在 Signing & Capabilities 里选自己的 Team，选好设备运行即可。

### Android 编译运行

需要 Android SDK Platform 37、Build Tools 36+ 与 JDK 17–26，最低支持 Android 6。

```powershell
cd android
.\gradlew.bat testDebugUnitTest assembleDebug lintDebug
```

调试安装包生成在 `android/app/build/outputs/apk/debug/app-debug.apk`，更多说明见 [Android 开发文档](android/README.md)。

### 配置学校入口

`ios/HBUSTPowerIOS/Services/ElectricityService.swift` 里是一卡通服务的 OAuth 入口地址，其中 `appKey` 在本仓库已脱敏：

```
appKey%3DREPLACE_WITH_YOUR_SCHOOL_APP_KEY
```

编译前需要从学校官方入口取得当前值。其余参数（`fidEnc`、`mappId`、`wfwEnc`）是本校的配置，换学校不通用。

### 打未签名 IPA

```sh
cd ios
./build_sideloadly_ipa.sh        # 生成 dist/湖科电量-iOS26-Sideloadly.ipa
```

把 IPA 拖进 [Sideloadly](https://sideloadly.io)，用自己的 Apple ID 重新签名安装。**不要勾选 Use automatic bundle ID**：它会改写应用的包标识符，而小组件的标识符必须以应用的为前缀，否则 iOS 会忽略这个扩展。

### 调试启动参数

调试版支持这些参数，方便离线看界面。

| 参数 | 作用 |
|---|---|
| `--ui-preview` | 使用离线演示数据，不联网 |
| `--preview-tab=1…4` | 直接打开用量 / 充值记录 / 校园卡 / 设置 |
| `--preview-about`、`--preview-changelog`、`--preview-widgets` | 直接打开对应页面 |
| `--slow-refresh-preview` | 演示刷新延迟 3 秒，方便看充电动画 |
| `--liquid-gravity-x=-0.5` | 模拟重力，检查水位倾斜方向 |
| `--simulate-vertical-bar` | 模拟不对称安全区，类似 Duo 外屏 |

## 工程结构

```
ios/
├─ HBUSTPowerIOS/
│  ├─ Models/           应用状态、数据模型、小发现、充值计算、更新日志
│  ├─ Services/         网络、HTML 解析、钥匙串、通知、诊断
│  ├─ ViewControllers/  电量、用量、记录、校园卡、设置、关于、计算器
│  └─ Views/            主题、动效、图表、水位、贴纸、下拉充电
├─ HBUSTPowerWidgets/   小组件扩展
├─ Shared/              应用与小组件共用的代码
├─ HBUSTPowerIOSTests/  单元测试
└─ WidgetSupport/       小组件的 Info.plist 与权限文件
android/                 Kotlin + Jetpack Compose 安卓客户端
fixtures/                两个平台共用的脱敏 HTML 测试样本
filing/                  隐私政策、用户协议与备案材料
```

数据流向：WebView 完成官方登录，应用捕获电费授权跳转，把学校的 Cookie 同步到 HTTP 会话，然后请求三个页面并解析。解析逻辑放在 `ElectricityHTMLParser`，不含网络代码，可以直接用样本测试。

## 测试

```sh
cd ios
xcodebuild test -project HBUSTPowerIOS.xcodeproj -scheme '湖科电量' \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

iOS 有 27 个 XCTest 测试方法；Android 有 44 项 JVM 单元测试，并通过 Android Lint。两端都覆盖 HTML 解析、授权跳转校验、用量估算、充值计算与更新日志等容易出问题的部分。

## 计划

- [x] iOS 应用
- [x] 主题、小组件、充值计算器
- [x] iPhone Duo 适配
- [x] 安卓客户端（Kotlin + Jetpack Compose），位于 `android/`
- [ ] 用付费账号签名后在真机上验证小组件

## 致谢

- [@zebwqfox](https://github.com/zebwqfox) —— 作者、维护者
- 登录走学习通和学校的官方服务；学习通 Logo 只用于标识登录方式。
- 紫鸟紫、枫烻黄两套配色以两位朋友命名。
- 《飞鸟集》诗句取自泰戈尔 1916 年原作与郑振铎 1922 年译本，均已过版权保护期。
