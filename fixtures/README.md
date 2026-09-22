# 1.7.1 最新交接增量（优先于下文所有历史说明，包括 1.6.0 增量）

2026-09-17：iOS 已从 1.6.0 升到 **1.7.1**，`sources/HBUSTPower-iOS` 已同步（仅 appKey 脱敏）。Android 以 1.7.1 为对齐目标，逐条清单见 **docs/IOS-1.7.1-ALIGNMENT.md**，要点如下：

- 1.6.1：校园卡授权后沿用原 WebView 读取余额，25 秒总超时。
- 1.6.2：解析修复（记录字段不串行、固定北京时间、页脚“统一身份认证”不再误判登录失效），授权入口去掉 uid；新样本和由 iOS 真实代码生成的 `fixtures/expected-1.7.1.json`。
- 1.7.0：余额卡电量水位（重力 + 手指，**注意 Android 重力传感器符号与 iOS 相反**）、状态贴纸、手绘下划线、下拉“充电”、用电小发现、长按菜单与分享卡片、关于页（作者“中二”，头像 `assets/developer-avatar.png`，头像彩蛋）、完整更新日志页（文案复用 `Models/Changelog.swift`）。
- 1.7.1：按窗口尺寸类布局；宽屏/展开折叠屏首页等宽两栏，适配不对称安全区，不锁方向；Android 可用 FoldingFeature 对齐折痕。

新截图为 `visuals/*-1.7.1.png`，说明见 visuals/README.md。与 1.6.0 增量冲突时以本增量为准；“电量、用量、充值记录、设置四个页面”等旧描述已过时，当前为电量、用量、充值记录、校园卡、设置五个标签，另有关于、更新日志和调试页。

---

# 合成测试数据

1.7.1 新增：`home-footer-auth.html`（页脚含“统一身份认证”但不是登录页）、`usage-missing-fields.html` / `records-missing-fields.html`（字段缺失不能串到下一条）、`login-form.html` / `login-script-rendered.html`（登录页判断）、`insights-cases.json`（用电小发现输入）。预期结果统一见 `expected-1.7.1.json`，由 iOS 真实代码生成（`tools/ios-parser-harness`）；其中 `legacy` 部分与原 `expected.json` 一致。

home/usage/records为人工构造的最小HTML，不是学校完整页面。七天每天照明2度、空调8度，共享余额60度，预期6天；expected.json为测试断言。请增加缺失、编码、错误页和复杂DOM测试，不要仅靠这个简单样本证明全站兼容。

旧Windows parseForTest仅暴露部分字段，JS校验不覆盖补助和表具；expected.json保留补助预期供Android完整解析测试。
