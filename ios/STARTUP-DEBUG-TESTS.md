# 1.4.2 启动与调试验证

环境：2026-09-05，Xcode 27，iOS 26.5 / iPhone 17 Pro 模拟器。

## 启动状态与入口：10 项通过

使用真实 OverviewViewController 和 AppModel 通知更新，注入离线状态并检查视图可见性：

1. 首次 idle 渲染不显示登录欢迎页。
2. loading 恢复会话时只显示连接状态。
3. 无数据且网络错误时显示重试状态。
4. 确认 authenticationRequired 才显示登录欢迎页。
5. 从登录重新连接时隐藏登录欢迎页。
6. 取得离线认证快照后直接显示电量页。
7. 已有数据时刷新保留电量页。
8. 刷新失败继续保留已有数据。
9. 已有数据且登录过期时保留电量页及重新登录入口。
10. 设置的调试行实际导航到 DebugViewController。

复现：Debug 运行 `--ui-preview --verify-startup`，成功标记 `STARTUP_CHECK COMPLETE: 10 checks passed`。

本次没有使用真实学校账户重放冷启动；以上验证的是渲染状态及导航，不代替真机登录有效性和学校网络验证。

## 测试通知：系统实际投递通过

使用与调试页面相同的 DebugNotificationService 和真实 UNUserNotificationCenter，在模拟器临时授权下验证：

- 即时通知、延迟通知（自动验证缩短为 2 秒）、低电量样式通知都被本次新增投递或前台代理接收。
- 10 秒延迟测试请求进入系统待发送列表，随后可取消。
- 清除仅移除 debug-notification- 前缀通知，保留其他待发送请求。
- 测试前后实际低电量提醒的 UserDefaults 去重记录保持一致。

复现：`--ui-preview --preview-debug --verify-debug-notifications`。
成功标记：`DEBUG_NOTIFICATION_CHECK COMPLETE`。

测试权限使用 provisional，因此实际验证了系统投递，未将其等同于真机有声横幅或锁屏展示。真机可在调试页点击“10 秒后发送”，切到后台或锁屏进行检查。

## 原有提醒与构建回归

原有 27 项提醒 / 权限逻辑检查全部通过；真实 AppModel → LowBalanceReminder → iOS 通知投递再次通过。详见 NOTIFICATION-TESTS.md。

复现：`--ui-preview --verify-alerts --verify-system-alert`。

Debug 模拟器和 Release arm64 设备构建均成功，无 Swift 编译警告；xcodebuild 输出一条既有 scheme destination 提示。查看了连接页和调试页的模拟器截图。

纯预览 `--startup-preview` 可固定连接状态；`--ui-preview --preview-debug` 可进入离线调试页面。这些预览和自动验证参数只存在于 Debug，Release 保留正常可操作的调试页面。
