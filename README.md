# Pickup：本地取件码管家

Pickup 是一款运行在 iPhone 上的纯本地取件码管理 App。它通过快捷指令接收快递短信，在设备端识别驿站、地址、快递公司和取件码，并按驿站分组展示。

项目不上传短信内容，也不连接快递公司接口，适合只想快速找到取件码的日常场景。

## 功能

- **短信识别：** 从取件短信中识别取件码、驿站、地址和快递公司。
- **快捷指令接入：** 通过 App Intents 将短信内容传入 App，支持「用 Pickup 添加取件短信」快捷指令。
- **本地管理：** 支持手动添加、复制取件码、标记已取和删除记录。
- **分组查看：** 按驿站和地址归类待取包裹，并支持搜索。
- **通知提醒：** 新增取件码后可发送本地通知。
- **小组件：** 在主屏幕查看待取数量和常用取件码。
- **灵动岛与锁屏：** 通过 Live Activity 展示待取数量、驿站和取件码。
- **去重保护：** 使用本地指纹避免重复保存同一条短信。

## 环境要求

- macOS，已安装 Xcode 26 或更高版本
- iOS 27 或更高版本的 iPhone（项目当前使用 iOS 27 SDK）
- Swift 6
- 需要配置 Apple Developer Team，才能运行 App、Widget 和 Live Activity

## 快速开始

1. 克隆项目并打开 Xcode 工程：

   ```bash
   git clone git@github.com:DanRan-hcy/msg.git
   cd msg
   open Pickup.xcodeproj
   ```

2. 在 Xcode 中选择 `Pickup` 和 `PickupWidget` 两个 Target，分别设置自己的 **Signing & Capabilities** 和 **Team**。

3. 确认 App Group 与 Bundle Identifier 使用你自己的标识。项目默认值如下：

   - App Group：`group.com.xxx.Pickup`
   - App：`com.xxx.Pickup`
   - Widget：`com.xxx.Pickup.Widget`

4. 选择真机或模拟器运行 `Pickup` Scheme。

首次打开 App 后，可以选择加载示例数据，先体验分组、复制和「已取」流程。

## 接入快捷指令

项目提供 `AddPickupMessageIntent`，用于接收一段短信文本并自动保存识别结果。可以在「快捷指令」App 中创建自动化：

1. 创建「收到短信」或符合个人使用习惯的自动化。
2. 添加 Pickup 的「添加取件短信」动作。
3. 将短信正文作为「短信内容」传给该动作。
4. 根据需要关闭自动化运行前询问。

短信会在本机解析。无法确认是取件短信、包含敏感词或没有明确取件码的内容不会被保存。

## 项目结构

```text
Pickup/
├── PickupApp.swift                 # App 入口
├── PickupRootView.swift            # 首次使用、设置和主界面入口
├── PickupScreens.swift             # 待取、历史、详情和添加页面
├── PickupParser.swift              # 取件短信解析器
├── PickupItem.swift                # SwiftData 数据模型
├── PickupStore.swift               # 本地数据和通知管理
├── PickupActivityManager.swift     # Live Activity 生命周期管理
├── AddPickupMessageIntent.swift    # App Intents 与快捷指令
└── PickupWidgetSnapshotWriter.swift# 写入 Widget 共享快照
Shared/
└── PickupActivityAttributes.swift  # Live Activity 数据结构
PickupWidget/
└── PickupWidget.swift              # 小组件和灵动岛界面
```

数据层使用 SwiftData，App 与 Widget 通过 App Group 共享小组件快照。所有取件记录保存在设备本地，项目没有服务器、账号系统或云同步功能。

## 隐私说明

- 短信正文只在设备端处理。
- 项目不请求网络，不上传短信、取件码或地址。
- 取件码和地址会写入 App 的本地 SwiftData 数据库。
- 开启通知或 Live Activity 后，系统会按照 iOS 权限机制展示对应内容。

## 许可

当前仓库未附带单独的开源许可证文件。若要公开分发，请根据项目用途补充 `LICENSE`，并确认 Apple Developer、图标和第三方资源的使用许可。
