# 实时动态与设置开关修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 Live Activity、锁屏、通知和设置开关的状态与实际行为保持一致，并优化灵动岛和锁屏布局。

**架构：** 由 `PickupActivityManager` 统一维护活动生命周期和错误状态；设置页通过状态刷新和系统设置链接反馈权限。新增数据入口都先保存，再刷新活动与通知，展示层只负责按状态渲染。

**技术栈：** Swift 6、SwiftUI、ActivityKit、WidgetKit、UserNotifications、SwiftData。

---

### 任务 1：统一 Live Activity 生命周期与错误反馈

**文件：**
- 修改：`Pickup/PickupActivityManager.swift`
- 修改：`Pickup/PickupScreens.swift`

- [x] **步骤 1：** 为管理器增加可观察的刷新结果类型，区分无待取、开关关闭、系统未允许、请求失败和成功状态；创建活动时保留 `Activity.request` 错误文本供设置页展示。
- [x] **步骤 2：** 将设置页的实时动态状态绑定到刷新结果；开关关闭时结束现有活动，开关打开且系统允许时立即重建活动。
- [x] **步骤 3：** 添加打开 `UIApplication.openSettingsURLString` 的入口，并在系统状态变化后重新读取 `ActivityAuthorizationInfo`。

### 任务 2：统一保存后的活动与通知刷新

**文件：**
- 修改：`Pickup/PickupStore.swift`
- 修改：`Pickup/PickupRootView.swift`
- 修改：`Pickup/AddPickupMessageIntent.swift`

- [ ] **步骤 1：** 增加保存后统一刷新入口，保证快捷指令和手动添加都使用相同的 Activity 刷新逻辑。
- [x] **步骤 2：** 通知仅在设置开关开启且系统授权成功时发送；关闭时取消待发送通知。
- [ ] **步骤 3：** 在保存、完成、删除和清理示例后调用统一刷新，保持活动和小组件快照一致。

### 任务 3：优化 Live Activity 视觉层级

**文件：**
- 修改：`PickupWidget/PickupWidget.swift`

- [x] **步骤 1：** 紧凑态保留图标和数量，统一颜色与可访问性文案。
- [x] **步骤 2：** 展开态以数量和最近驿站为主，限制验证码行数并将超出内容归并为剩余件数。
- [x] **步骤 3：** 锁屏态按驿站分组，减少重复地址，增加更新时间和空状态保护，确保窄屏不截断关键信息。

### 任务 4：编译验证

**文件：** 无新增测试文件。

- [x] **步骤 1：** 执行 `xcodebuild -project Pickup.xcodeproj -scheme Pickup -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO`。
- [x] **步骤 2：** 检查 `git diff`，确认只包含本需求相关修改，并按仓库要求保持中文注释。
