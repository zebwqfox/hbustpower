# 湖科电量 APNs 接入

App 已完成客户端 APNs 注册、设备令牌登记、前台展示和通知点击跳转。要实际发送远程推送，还需要一个由学校或运营方控制的 HTTPS 服务端。

## Apple 侧配置

1. 使用付费 Apple Developer Program 中的正式 App ID；不要继续使用 `com.local.hbustpower.ios` 作为生产 Bundle ID。
2. 在 Certificates, Identifiers & Profiles 中为该 App ID 开启 Push Notifications。
3. 在 Xcode 的 Signing & Capabilities 中选择对应团队，确认 `Push Notifications` 存在。
4. 服务端创建 APNs Auth Key（`.p8`），记录 Key ID、Team ID 和生产 Bundle ID。`.p8` 只能放在服务端密钥管理系统，不能加入项目或 IPA。

通过免费个人签名、第三方重签名或被移除 `aps-environment` 权限的 IPA，无法保证取得有效 APNs 设备令牌。开发签名连接 Sandbox；分发签名连接 Production，服务端必须按登记请求中的 `push_environment` 区分。

## 设备登记接口

把 `Info.plist` 中的 `HBUSTPushRegistrationEndpoint` 配成正式 HTTPS 地址，例如：

```xml
<key>HBUSTPushRegistrationEndpoint</key>
<string>https://push.example.edu.cn/v1/devices/register</string>
```

App 会以 `POST application/json` 发送：

```json
{
  "installation_id": "本次安装的随机 UUID",
  "device_token": "APNs token（十六进制）",
  "platform": "ios",
  "bundle_id": "正式 Bundle ID",
  "app_version": "1.9.0",
  "build_number": "26",
  "push_environment": "development 或 production",
  "locale": "zh_CN",
  "time_zone": "Asia/Shanghai"
}
```

服务端返回任意 `2xx` 即登记成功。服务端必须按 `installation_id` 更新令牌而不是重复插入，并在 APNs 返回令牌失效时删除记录。接口上线前应增加应用级鉴权、限流和防重放；不要把固定 API Secret 内置在 App 中。

## 推送 Payload

客户端识别以下 `destination`：

- `overview`：电量首页
- `usage`：用量
- `records`：充值记录
- `campus_card`：校园卡
- `settings`：设置

示例：

```json
{
  "aps": {
    "alert": {
      "title": "宿舍电量偏低",
      "body": "电量已经低于你设置的提醒值。"
    },
    "sound": "default",
    "category": "POWER_ALERT"
  },
  "destination": "overview",
  "event_id": "evt_01J..."
}
```

推送正文不要包含学号、房间号、完整余额或登录信息；打开 App 后再鉴权读取详情。类别还支持 `CAMPUS_NOTICE` 和 `APP_UPDATE`。

## 验证

1. 必须使用真机；iOS 模拟器不用于验证真实 APNs 设备令牌链路。
2. 首次启动允许通知，进入“设置 → 调试与诊断 → 远程推送”。
3. 确认显示“已取得 APNs 设备令牌”和“设备令牌已登记”。
4. 从服务端向该令牌发送 Sandbox 或 Production 推送，核对前台横幅、后台通知和点击跳转。
5. 卸载重装、恢复备份或系统改变令牌后，确认服务端记录被更新。
