# 1.4.3 验证记录

日期：2026-09-07。环境：Xcode 27，iOS 26.5；iPhone 17 Pro 与 iPad Pro 11-inch (M5) 模拟器。

## 滚动标题

四个主页面均通过真实 UINavigationController / UIScrollView 状态检查。iPhone 和 iPad 上，导航栏高度均从 106 pt 收起为 54 pt。测试同时检查系统观察的滚动视图与内容层级，使用临时额外滚动范围，并在完成后恢复。

修复依据：[Apple setContentScrollView(_:for:) 文档](https://developer.apple.com/documentation/uikit/uiviewcontroller/setcontentscrollview(_:for:))。UIKit 对复杂视图层级的自动选择可能不正确；现在显式关联滚动视图，装饰背景不再排在其前面。

参数：`--ui-preview --verify-layout`。
标记：`LAYOUT_CHECK COMPLETE: 4 scrolling titles collapse`。

## 原生登录与自动进入电费

通过 WKWebView 的本地 HTML 测试页验证，测试不向学校提交账号密码：

- 只允许 HTTPS 的 passport2.chaoxing.com/mlogin 使用原生账号密码提交；相似域名和二次验证路径不匹配。
- 未同意协议不提交；明确同意后调用一次官方表单按钮。
- 密码包含引号、反斜杠和类似 HTML 的字符时，通过 callAsyncJavaScript 参数原样传递，未拼接到代码中。
- 一卡通卡片延迟渲染、使用 div/span 和父级点击事件时，能自动进入“宿舍电费充值”，且只触发一次，不点击“卡片充值”。
- 不在相似但非学校的域名执行入口自动点击。
- 重复 appId 参数的授权链接会被拒绝，不触发 Dictionary 重复键崩溃。

参数：`--ui-preview --verify-authentication`。
标记：`AUTH_CHECK COMPLETE`。

另外以匿名方式加载了真实超星授权链，WKWebView 最终识别到可用的官方移动表单，输出 `AUTH_LIVE_FORM ready=true`。此检查未输入账号或密码；它确认表单接入可用，不代表真实学校账户认证、二次验证或一卡通完整业务已端到端通过。

官方表单与脚本核对来源：

- [超星官方移动登录页](https://passport2.chaoxing.com/mlogin)
- [超星官方移动登录脚本](https://passport2-static.chaoxing.com/js/fanya/mobile/login.js?v=20260610)
- [学校一卡通门户](http://ecard.hbust.edu.cn/plat?name=loginTransit&source=h5)

## 回归与交付范围

10 项启动状态检查及 27 项低电量 / 权限检查再次通过。
参数：`--ui-preview --verify-startup --verify-alerts`。

Debug 模拟器和 Release arm64 构建成功，无 Swift 编译警告。模拟器运行时出现系统 AuthKit / 键盘框架重复类提示，未阻止测试完成。

本次未直接测试“为 iPad 设计”的 Mac 运行环境，也未使用真实学校账号登录。原生表单保留官方验证入口，用户可在安装后用自己的账号验证完整流程。

原生页面预览：`--welcome-preview --native-login-preview`。
匿名官方表单检查：`--welcome-preview --live-login-check`。
所有自动验证和预览参数仅存在于 Debug 构建；Release 保留实际原生登录、官方验证备用入口和设置内调试页。
