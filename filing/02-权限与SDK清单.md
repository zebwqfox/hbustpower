# 权限与第三方 SDK 清单

备案与应用商店上架都会要求这两张表，内容必须与安装包实际情况一致。以下信息取自 `android/app/src/main/AndroidManifest.xml` 与 `android/app/build.gradle.kts`，版本 1.9.0。

## 一、应用申请的权限

| 权限 | 类型 | 使用场景 | 调用时机 | 拒绝后的影响 |
|---|---|---|---|---|
| `android.permission.INTERNET` | 普通权限，安装时授予 | 访问学校电费系统与一卡通门户，读取电量、用量、充值记录、校园卡余额 | 用户同意隐私政策并登录后 | 无法查询真实数据，可使用离线演示 |
| `android.permission.POST_NOTIFICATIONS` | 运行时权限（Android 13+） | 剩余电量低于用户设定值时，在本机发出一次提醒 | 首次引导页由用户主动点击"开启通知"时弹窗申请 | 不再收到低电量提醒，其余功能不受影响 |
| `com.zebwqfox.hbustpower.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | 自定义签名级权限 | **由 AndroidX 组件自动生成**，用于限制应用内部动态广播只能被本应用接收，不涉及用户信息 | 系统内部 | 不适用 |

> 在 `adb shell dumpsys package` 或商店的权限扫描结果中会看到上面第三条，它不是开发者主动申请的用户权限，属于 AndroidX Core 的安全加固机制，保护级别为 signature。

**未申请的敏感权限**：位置、相机、麦克风、通讯录、短信、电话、日历、存储/相册、蓝牙、后台定位、开机自启、读取已安装应用列表、悬浮窗、无障碍服务。

**其他说明**

- 不读取 IMEI、MEID、OAID、Android ID、MAC 等设备标识。
- 不使用剪贴板读取；复制功能只写入剪贴板且由用户主动触发。
- 无常驻前台服务、无开机自启、无后台定时轮询；只在启动、回到前台或用户手动刷新时请求数据。
- 应用已设置 `allowBackup="false"`，本机数据不参与云备份。

## 二、第三方 SDK 目录

| SDK 名称 | 提供方 | 版本 | 用途 | 收集的个人信息 | 官网 / 隐私政策 |
|---|---|---|---|---|---|
| AndroidX Core / Activity / Lifecycle | Google | 1.19.0 / 1.13.0 / 2.10.0 | 基础组件、生命周期 | 无 | https://developer.android.com/jetpack |
| Jetpack Compose（UI / Foundation / Animation / Material3） | Google | 1.12.0 / 1.4.0 | 界面框架 | 无 | 同上 |
| Material Icons Extended | Google | 1.7.8 | 图标资源 | 无 | 同上 |
| AndroidX Window | Google | 1.5.0 | 折叠屏与窗口尺寸适配 | 无 | 同上 |
| Kotlin 标准库与协程 | JetBrains | 随 Kotlin 2.4.10 | 语言运行时 | 无 | https://kotlinlang.org |
| jsoup | jsoup 开源项目 | 1.21.2 | 解析学校网页 HTML（本地解析，不联网） | 无 | https://jsoup.org |
| desugar_jdk_libs | Google | 2.1.5 | 旧系统上的日期时间 API 兼容 | 无 | https://developer.android.com/studio/write/java8-support |
| Backdrop / Shapes | Kyant0（开源） | 2.0.1 / 1.2.1 | 界面材质绘制组件，**当前版本已打包但未启用** | 无 | https://github.com/Kyant0 |

> 以上组件均为本地运行的界面/工具库，不含统计、广告、推送、支付、社交登录类 SDK，不产生自有网络请求。

## 三、应用访问的网络地址

| 域名 | 归属 | 用途 | 协议 |
|---|---|---|---|
| `auth.chaoxing.com` | 超星（学校指定身份验证服务） | OAuth 授权入口 | HTTPS |
| `passport2.chaoxing.com` | 超星 | 官方登录页面，账号密码在此提交 | HTTPS |
| `ecard.hbust.edu.cn` | 湖北科技学院 | 一卡通门户、电费授权跳转、校园卡余额 | HTTP（学校现状） |
| `xianankd.hbust.edu.cn` | 湖北科技学院（电费服务商） | 宿舍电量、用量、充值记录 | HTTP（学校现状） |
| `homewh.chaoxing.com` | 超星 | 登录页展示的《隐私政策》《用户协议》链接 | HTTPS |

明文 HTTP 仅针对上述两个学校业务域名放行（`res/xml/network_security_config.xml`），其余域名一律要求 HTTPS；登录表单本身始终在 HTTPS 页面完成。

## 四、个人信息收集清单（对照《App 收集使用个人信息自评估指南》）

| 个人信息类型 | 是否收集 | 说明 |
|---|---|---|
| 身份信息（姓名、身份证、学号） | 否 | 应用不读取、不保存 |
| 账号密码 | 否（不保存） | 仅填入超星官方页面提交，内存中使用后即清除 |
| 位置信息 | 否 | 未申请权限 |
| 设备标识、设备信息 | 否 | 仅在调试页展示系统版本与机型，不上传 |
| 通讯录、短信、通话记录 | 否 | 未申请权限 |
| 图片、音视频、文件 | 否 | 分享电量卡片时在应用私有缓存生成图片，由用户主动分享 |
| 应用列表 | 否 | 未读取 |
| 交易与消费信息 | 否 | 充值记录只读展示，不参与支付 |
| 生物特征、健康、行踪轨迹等敏感信息 | 否 | 不涉及 |

## 五、与学校系统的关系声明

本应用为个人开发的第三方工具，与湖北科技学院、超星学习通无隶属或合作关系；应用内使用学习通标识仅用于标明登录服务来源。数据来源于学校官方系统，用户使用自己的账号登录并读取本人已绑定宿舍的数据。
