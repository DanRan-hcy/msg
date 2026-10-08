# 实时动态与通知设置修复设计

## 目标

修复取件信息已识别但灵动岛、锁屏不显示，以及设置页开关状态与实际行为不同步的问题，同时优化 Live Activity 的信息层级。

## 设计

- `PickupActivityManager` 统一负责根据待取数据创建、更新和结束 Live Activity，并返回可展示的失败状态；系统未允许实时动态时，设置页提供系统设置入口。
- 设置页的实时动态开关关闭时立即结束已有活动，打开时立即刷新；通知开关只有在系统通知授权成功后才保持开启，拒绝时回滚并提示。
- 快捷指令和手动添加都使用同一套保存后刷新流程，避免某个入口漏更新活动或通知。
- 灵动岛紧凑态仅展示图标和数量；展开态突出数量、最近驿站和验证码，其余折叠；锁屏按驿站分组展示，并减少重复地址。

## 验证

使用 `xcodebuild -project Pickup.xcodeproj -scheme Pickup -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` 检查主 App 与 Widget 的编译结果；不新增测试文件，不执行前端构建。
