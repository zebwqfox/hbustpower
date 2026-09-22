# 湖科电量 iOS 26（UIKit + Liquid Glass）

原生 UIKit 客户端，最低系统要求为 iOS 26。1.4.0 使用蓝色主题与原生 Liquid Glass，新增按钮按压回弹、可拖拽欢迎页贴纸、余额估算展开、用量卡片跳转，以及图表选日和读数联动。支持深色模式、动态字体和减弱动态效果。

设计说明见 [DESIGN.md](DESIGN.md)，模拟器预览见 `design-preview`。

## 运行

1. 使用 Xcode 26 或更高版本打开 `HBUSTPowerIOS.xcodeproj`。
2. 在 Signing & Capabilities 中选择自己的开发团队。
3. 选择 iPhone 模拟器或真机运行。

iOS 不允许普通 App 在后台长期定时轮询。应用会在启动、回到前台和用户手动刷新时查询数据。

## 远程推送

客户端已接入 APNs：授权后注册设备令牌、通过 HTTPS 向服务端登记、前台展示通知，并按 payload 的 `destination` 跳转到对应标签页。完整的 Apple 配置、登记接口和推送 payload 约定见 [APNS-SETUP.md](APNS-SETUP.md)。

未配置 `Info.plist` 的 `HBUSTPushRegistrationEndpoint` 时，App 只取得并安全保存 APNs 令牌，不会把令牌发送到任何第三方。APNs 私钥不得放入 App。Sideloadly 或其他第三方重签名可能移除推送权限，正式推送必须使用已开启 Push Notifications 的有效 provisioning profile。

## 学校统一身份认证（测试）

连接校园服务时优先显示“学校统一身份认证”，入口采用一卡通公开配置中的 `commonoauth2` 流程；认证完成后继续复用一卡通门户、电费 `appId=180` 授权和现有数据读取。学习通认证保留为备用方式。

学校当前将该入口重定向到 `http://sso.hbust.edu.cn:28000`。App 会在进入前明确提醒，只允许顶层页面在学校 SSO 与一卡通域名之间跳转，并且不读取、不注入、不保存学校密码。这个 HTTP 现状不适合作为正式生产登录链路；上线前应推动学校提供有效 HTTPS，或取得学校正式的 OAuth/CAS 客户端接入参数。无测试账号时只能验证到达登录页，完整登录及一卡通回跳必须由账号本人在真机完成。

实测当前账号登录后，学校 SSO 在回到一卡通前提示“服务大厅未授权(1)”。这表示学校 OAuth 客户端已识别账号，但服务大厅没有向该账号开放访问权限，不是 App 的密码或回调错误。App 会识别该提示并提供“改用学习通”；若要让统一认证真正替代学习通，需要学校 SSO 管理员为目标师生范围授权服务大厅，或为本 App 提供正式客户端及回调地址。

## 生成 Sideloadly IPA

在安装了 Xcode 26 的 Mac 上运行：

```sh
chmod +x build_sideloadly_ipa.sh
./build_sideloadly_ipa.sh
```

脚本会在 `dist/湖科电量-iOS26-Sideloadly.ipa` 生成未签名 IPA。将该 IPA 拖入 Sideloadly，由 Sideloadly 使用你的 Apple ID 重新签名并安装。

## 1.4.1 通知提醒

首次启动时先申请系统通知权限，再查询学校电量。拒绝也可正常使用；已经决定过的权限不会重复弹窗。

电量首次低于提醒值时发送一次，持续偏低的重复刷新不会反复发送；回升后再次变低重新提醒。权限拒绝或发送失败不再消耗提醒机会，在允许通知后的下次成功更新时可重新检查。修改阈值或切换宿舍按新条件判断。

测试方法与结果见 [NOTIFICATION-TESTS.md](NOTIFICATION-TESTS.md)。

## 1.4.2 启动与调试

修复已有登录状态时欢迎登录页短暂闪现：等待权限和恢复会话时显示独立连接状态，只有确认需要认证才显示登录入口；网络失败可直接重试，已有电量数据在刷新时保留。

在 **设置 → 调试与诊断** 中可以：

- 查看通知授权、横幅 / 声音 / 锁屏设置，以及测试通知数量。
- 申请通知权限或打开系统通知设置；发送即时、10 秒延迟及低电量样式测试通知。
- 清除测试通知，不影响实际低电量提醒的记录。
- 查看本机凭据是否存在、学校 Cookie 数量、刷新结果与耗时、数据时间与数量、提醒状态。
- 查看本次运行最近 60 条日志，并复制不包含账户、宿舍号、授权链接或 Cookie 内容的诊断报告。

调试入口保留在 Release 安装包中；低电量样式测试使用虚构数据，不修改真实电量。验证范围与复现参数见 [STARTUP-DEBUG-TESTS.md](STARTUP-DEBUG-TESTS.md)。

## 1.4.3 滚动标题与原生登录

- 四个主页面明确绑定系统观察的滚动视图，移除干扰识别的独立背景层。大标题随滚动收起，导航栏正常切换背景，适用于 iPhone 与 iPad 布局。
- 登录改为 UIKit 原生账号 / 密码输入框、协议勾选、状态和重试。原生提交仅对 HTTPS 的超星移动登录表单开放；通过参数传递填写官方表单，由超星现有脚本执行认证。应用不保存密码。
- 验证码、其他登录方式、密码找回及二次验证仍通过官方移动页面完成；原生输入界面没有重写学校认证协议。
- 一卡通门户使用受域名和路径限制的 MutationObserver 与有限时长轮询，等待异步渲染的“宿舍电费充值”卡片后仅点击一次。支持卡片容器上的事件及新窗口链接。
- 捕获电费授权后同步学校会话 Cookie，再交给现有电量数据流程；等待过久时可打开校园卡页面继续操作。

验证结果、范围和复现参数见 [AUTH-LAYOUT-TESTS.md](AUTH-LAYOUT-TESTS.md)。

## 1.4.4 学习通登录样式

原生登录表单改为接近学习通官方页面的白色背景、细边框圆角输入框、蓝紫渐变登录按钮和轻量文字链接。加入官方学习通 Logo，并保留深色模式、动态字体、原生账号密码输入及现有认证流程。

Logo 来源：[超星官方应用页面](https://apps.chaoxing.com/t)，[原始素材](https://p.ananas.chaoxing.com/star3/144_144/55cdad9fe4b0529fd53fc5b1.png?rh=512&rw=512)。2026-09-07 获取，原样保存在 XuexitongLogo.imageset，仅用于标识学习通登录服务。

## 1.4.5 原生玻璃登录

按反馈恢复登录页的 Liquid Glass：账号和密码使用可交互的 UIGlassEffect 共享卡片，登录按钮使用系统 glass / prominentGlass 配置，其他登录方式使用系统玻璃按钮。保留学习通 Logo，用浅蓝与淡紫背景衬出材质，取消网页式描边输入框和自绘渐变按钮。原有 PowerActionButton 按压回弹与减少动态效果支持继续保留。

Debug 与 Release 构建通过；已检查模拟器原生页面截图。此次仅调整登录页呈现，认证仍由超星官方流程处理。

## 1.5.0 简洁首页与首次引导

首页突出剩余电量和预计时长，移除用量卡片与常驻设备列表。详细用量仍在“用量”，设备信息移至“设置 → 关于 → 电表信息”。用量区改为开放排版，减少图标和说明文案；正常刷新只通过原生控件状态表达，旧数据、失败和低电量仍保留必要提示。

首次启动先进入通知权限引导，再进入简短使用说明。授权、拒绝、暂不开启、重试、返回和从系统设置恢复均有独立处理，完成后持久化，不在后续启动重复展示。暂不开启时不会在首次低电量读取后再次弹出权限框；仍可在调试页主动申请。

后续界面约束见 [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md)。

## 1.5.1 恢复上一版界面

用户更喜欢 1.4.5 的丰富层次，本版恢复其首页、用量、记录、设置和玻璃登录界面，以及余额展开、用量跳转等交互；保留 1.5.0 首次权限引导、跳过授权保护和启动衔接。Android 移植以此组合为基准，1.5.0 极简首页不再作为视觉目标。

## 1.6.0 校园卡余额

新增“校园卡”页面，通过官方一卡通门户登录态和门户自身只读接口读取余额，不复用电费 appId=180 的定向授权。按学校卡配置处理钱包金额（分转元），多卡显示合计；缺失数据不会按零元显示，失败时保留上次余额并提示未更新。充值按钮在外部打开智慧湖科官方认证/一卡通网页，由用户选择卡片充值并完成操作；未使用未经验证的智慧湖科 App URL Scheme。

登录页去掉蓝紫渐变，保留原生玻璃输入框和按钮，加入三步图标流程及用户确认的登录说明，移除“不保存密码”展示文案（仍不保存密码）。

测试与验证边界见 CAMPUS-CARD-TESTS.md。Debug `--ui-preview --preview-tab=3` 显示校园卡演示余额；设置页现在是 index=4。

## 1.6.1 校园卡加载修复

修复校园卡授权后切换WebView丢失sessionStorage的问题，保留原授权页面继续读取。首次进入通过官方入口恢复会话，补充总超时与脱敏诊断，避免长时间转圈。

## 单元测试

学校页面解析集中在 `ElectricityHTMLParser`，测试位于 `HBUSTPowerIOSTests`。在 Xcode 中按 ⌘U，或运行：

```sh
xcodebuild test -project HBUSTPowerIOS.xcodeproj -scheme '湖科电量' -destination 'platform=iOS Simulator,name=iPhone 17'
```

修复内容：记录字段缺失时不再串用下一条记录；日期固定按公历和北京时间解析；页面正文或页脚出现“统一身份认证”不再误判为登录失效；数据请求 User-Agent 与登录 WebView 保持一致。当前测试样本为按页面结构手写，拿到真实页面后建议替换为脱敏副本。

## 1.6.2 更稳的数据读取

修复记录字段缺失时串用下一条、日期受设备历法和时区影响、页脚“统一身份认证”误判登录失效。授权链接去掉固定的学习通 `uid`，登录身份仅由 WebView 中实际登录的账号决定（需真机用不同账号确认）。学校页面解析独立为 `ElectricityHTMLParser` 并加入单元测试。

## 1.7.0 交互与手作感

- 余额卡加入电量水位 `EnergyLiquidView`：水位按预计天数（30 天为满）变化，竖屏手机布局下随重力倾斜，横向拨动或轻点产生波纹。
- 状态贴纸、手绘下划线、便签卡片等手作细节集中在 `Views/PlayfulViews.swift`。
- 下拉刷新改为 `ChargeRefreshControl`：拉满有触觉反馈，刷新时闪电脉动。
- 首页新增“用电小发现”（`Models/UsageInsights.swift`，有单元测试）。
- 长按余额卡、用量卡、充值记录弹出菜单，可复制、分享电量卡片图片或预览详情。
- 设置 → 关于：开发者的话（内容在 `DeveloperProfile`，可自行改写；填 `feedbackURL` 后显示反馈按钮）、最近更新和头像彩蛋（连点 7 次）。
- 设置 → 更新日志：全部版本说明，数据在 `Models/Changelog.swift`。发布新版本时须在最前面加一条，单元测试会检查最新条目与 `MARKETING_VERSION` 一致。
- 所有新增动效在“减弱动态效果”下保持静止。

## 1.7.1 适配 iPhone Duo

按苹果 iPhone Duo 开发者文档与 Tech Talks 的要求调整：

- 按尺寸类布局（`PowerLayout`），不按屏幕尺寸或界面方向判断。水平 regular（展开的内屏、iPad）时首页左右等宽两栏，折痕落在两栏间隙；compact（外屏、普通 iPhone）保持单栏，层级和功能一致。
- 滚动页面内容居中和宽度改为相对 `view.safeAreaLayoutGuide`，避开外屏右侧竖向工具栏造成的不对称安全区；表格启用 `cellLayoutMarginsFollowReadableWidth`。
- 刷新按钮改为带标题和图标的标准 `UIBarButtonItem`，不再使用 `customView`，便于系统移入竖向工具栏。
- 图表 `contentMode = .redraw`，折叠、展开后重新绘制。水位的重力倾斜仅在 compact 宽 + regular 高时启用。

验证：iPhone 17（单栏）、iPad mini（regular 宽度两栏）截图；Debug 参数 `--simulate-vertical-bar` 在右侧加入 76 pt 不对称安全区模拟外屏竖向工具栏。iPhone Duo 模拟器需要 Xcode 27.1 与 iOS 27.1 运行时，本机为 Xcode 27.0，尚未在 Duo 模拟器及折叠姿态（半折叠、帐篷）下实测。其他 Debug 参数：`--preview-about`、`--preview-changelog`。

## 1.7.2 下拉充电重做

下拉刷新 `ChargeRefreshControl` 改为“拉到位 + 松手”才刷新：拉过 96pt 进入就绪（触觉、琥珀色、火花、“松手，开始充电”），松手才调用 `onRefresh`；未就绪松手或就绪后退回再松手都会取消，并收起 UIKit 自己中途触发的刷新。系统 UIRefreshControl 只用于摆放和保持指示器（兼容大标题）。充电中圆弧旋转、闪电脉动、光晕呼吸、持续火花、文案轮换，至少 0.8 秒；完成变绿对勾 + 火花 + 成功触觉，首页水位同时晃动；失败变橙摇头。页面在刷新结束时调用 `finish(success:)`。

Debug 参数 `--ui-preview --slow-refresh-preview` 让预览刷新延迟 3 秒，便于查看动画。`--liquid-gravity-x=-0.5`（向左）或 `0.5`（向右）模拟重力，用于在模拟器中检查水位倾斜方向。

## 1.8.0 充值计算器

- `Models/RechargePlanner.swift`：按金额算可用天数和日期；按目标日期算至少充值金额（当天只计剩余时间，金额向上取整到元）；室友分摊向上取整到分。电价或两类日均缺失时不计算。`RechargeSummary` 汇总充值记录，缺失字段不按 0 计。均有单元测试。
- `RechargePlannerViewController`：首页“算一算”或余额卡长按菜单打开，半屏/全屏面板；宿舍人数保存在本机。
- 充值记录顶部汇总卡；外屏竖向工具栏存在时，小发现横向卡片裁剪在安全区内。
- iPhone Duo：Xcode 27.1 测试版 + iOS 27.1 模拟器运行时，外屏实测通过；展开/合上需在 Device Hub 里切换。

## 1.8.1 避开折痕

iOS 27.1 起用 `UIView.reservedRegions(kind: .division)` 读取折痕。半折叠时（区域 active 且为竖向），首页左栏宽度设为折痕左边缘、两栏间距设为折痕宽度，间隙正好覆盖折痕；展平、单栏或 iOS 26 时保持等宽两栏。实测：内屏横向 951×669pt，折痕 x=455.5–495.5；修复前间隙在 417.7–449.7，右栏约 46pt 压在折痕上。四种形态（外屏、内屏横/竖、半折叠）均在 Duo 模拟器截图检查。

## 1.8.2 登录更稳

- 真实账号在 Duo 模拟器上实测：去掉 `uid` 后学习通授权 → 一卡通 → 宿舍电费授权全部成功。
- 问题：模拟器版以不签名方式编译时没有钥匙串权限，保存授权报 -34018，原逻辑把它当成登录失败，随后刷新因无保存授权退回欢迎页。现在钥匙串失败只记诊断，照常读取。模拟器编译请用 `CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES`（本地签名会内嵌 application-identifier），真机经 Sideloadly 重签名后本就有权限。
- 真实页面的宿舍标题带第一块电表类型（如“东10-625照明”），解析时去掉末尾“照明/空调”。
- 调试版会在控制台输出登录导航（只含域名、路径和参数名，不含参数值）和诊断事件，便于排查。

## 1.9.0 主题

`Views/PowerThemeStyle.swift` 定义三套配色（湖科蓝、紫鸟紫、枫烻黄），每套含背景、卡片、主色、余额卡底色、次要色和火花色的浅色/深色取值，以及专属符号、问候语和充电文案。`PowerThemeStore` 保存选择并广播变更；`PowerTheme` 的颜色改为读取当前主题。已绘制的颜色无法就地更新，因此 `SceneDelegate` 收到变更后用淡入淡出重建根界面，并保留当前标签页。

- 入口：设置 → 外观 → 主题（`ThemePickerViewController`）。选中项再点一次播放专属动效。
- 紫鸟紫：首页底部 `StrayBirdsCardView` 每次启动随机显示一句《飞鸟集》（`Models/StrayBirds.swift`，泰戈尔原作与郑振铎译本均已过版权保护期），注明出处，轻点换句、长按复制。
- 余额卡贴纸轻点会在状态行显示主题问候语。
- 测试：`HBUSTPowerIOSTests/PowerThemeTests.swift` 校验主题唯一性、浅色与深色下主色互不相同、选择持久化与通知、诗句列表与循环。

## 1.10.0 桌面小组件

新增 `HBUSTPowerWidgets` 小组件扩展（配置在 `WidgetSupport/`）。`Shared/` 同时属于应用与扩展，含 `PowerThemeStyle`、`PowerWidgetSnapshot`（App Group 读写）和 `WidgetViews`（SwiftUI 视图）。

- 应用每次成功读取电量后写入共享存储并刷新时间线；清除登录时清空。
- 支持 systemSmall、systemMedium、accessoryCircular / Rectangular / Inline，配色取当前主题。
- App Group `group.com.local.hbustpower`。免费 Apple ID 侧载通常签不上，届时小组件只显示占位提示；设置 → 调试与诊断 → 小组件 可查看是否可用。
- Debug 参数 `--ui-preview --preview-widgets` 打开内置小组件预览（按真实尺寸渲染三套主题）。
- 测试：`WidgetSnapshotTests` 覆盖进度条取值、缺失数据与编解码。

### 小组件侧载注意

Sideloadly 安装时不要勾选 **Use automatic bundle ID**：它会改写主应用的包标识符，而扩展标识符必须是主应用加后缀，不匹配时 iOS 会静默忽略扩展（应用照常可用，但小组件不出现）。“Dropping 0 of 1 plug-ins” 表示扩展已保留。诊断页的“共享存储”改用 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` 判断，`UserDefaults(suiteName:)` 在没有权限时也可能返回对象，不可靠；并新增“小组件扩展”一行显示 PlugIns 内容。
