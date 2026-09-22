# 校园卡余额 1.6.0

2026-09-08，根据当前学校公开门户脚本检查：

- http://ecard.hbust.edu.cn/plat/js/app.a72d0ecb.js
- http://ecard.hbust.edu.cn/plat/js/chunk-47e902a2.4020ee03.js

官方组件通过 `$api.get('/berserker-app/ykt/tsm/getCampusCards')` 读取 `data.card`。配置type不为1时累加db_balance+unsettle_amount，不为2时累加elec_accamt，金额从分转换为元。当前实现沿用这一口径；没有抓取或导出用户token。相较历史DISCOVERY的独立模块方案，本版直接使用门户已提供的校园卡只读能力。

## 检查

- `node Tests/campus-card.test.js`：12项离线脚本契约检查，包括来源/会话、钱包配置、金额单位、零/负值、多卡和缺失值。
- `--ui-preview --verify-authentication`：原生WKWebView异步JS返回金额验证，以及原有登录域名、协议、特殊字符和电费卡片自动进入检查。
- `--ui-preview --verify-layout`：五个页面的原生滚动标题。
- 原有10项启动、27项通知和首次引导检查通过。
- Debug/Release编译；校园卡及无渐变原生登录页面模拟器截图检查。

## 边界

未使用真实学校账户验证余额，也未进行充值。模拟余额不代表当前账户余额。门户接口或配置变化可能导致“暂时无法读取”；请通过“连接校园卡”完成官方验证后实测。按钮打开官方网页而非已验证的智慧湖科App深链；用户自己在官网充值。校园卡余额不触发宿舍低电量提醒。

## 1.6.1 会话衔接修复

校园卡门户的 Vue store 从当前窗口的 sessionStorage.access_token 初始化。WKWebsiteDataStore 相同只保证相关持久网站数据共享，不会让两个独立 WebView 共享 sessionStorage。1.6.0 在认证完成后销毁登录窗口并用新窗口打开 /plat，可能丢失这部分授权。

本版将原登录 WebView 交给校园卡页，保留其浏览上下文；接管时不重新导航。首次没有校园卡浏览上下文时通过官方 SSO 入口恢复，而不是直接打开裸 /plat。已授权窗口中的刷新继续复用同一 WebView。增加25秒总超时，覆盖卡在JS接口Promise的情况；注销、离开和新请求使旧响应失效。调试日志记录恢复授权、接管页面、读取完成及失败阶段，不包含会话凭据。

回归用例：两个相同 data store 的原生WebView访问同源页面，确认新窗口无法读到前一窗口sessionStorage；调用生产adoptPortal路径后确认原窗口身份和sessionStorage保留。真实用户账户余额仍需设备复测。
