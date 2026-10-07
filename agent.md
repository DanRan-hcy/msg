# 本地取件码管家 iOS 27 V1

## 产品、UI、技术架构与 Vibe Coding 开发规格

---

# 1. 项目定位

开发一个运行在 iOS 27 上的纯本地取件码管理 App。

核心目标：

> **把短信里的快递取件信息，通过快捷指令自动交给 App，由 App 在本地识别“驿站 + 取件码”，并按照驿站分组展示，同时通过 Live Activity 展示在灵动岛和锁屏。**

产品不负责：

* 查询快递物流
* 查询快递单号
* 调用快递公司 API
* 登录淘宝/京东/菜鸟
* 云同步
* AI 识别
* 用户账号
* 广告
* 服务器数据

第一版只解决一个问题：

> **“我手机里有很多取件短信，我不想翻短信找验证码。”**

---

# 2. 核心产品体验

用户第一次安装 App：

```text
安装 App
   ↓
打开 App
   ↓
开启/配置快捷指令
   ↓
快捷指令自动获取短信内容
   ↓
将短信文本传给 App
```

以后：

```text
收到快递短信
      ↓
快捷指令
      ↓
传给 App
      ↓
本地解析
      ↓
识别：
    驿站
    取件码
    地址
    快递公司
      ↓
保存到本地
      ↓
按驿站分组
      ↓
更新 Live Activity
      ↓
灵动岛 / 锁屏显示
```

用户去取件：

```text
打开 App
   ↓
找到驿站
   ↓
看到取件码
   ↓
复制
   ↓
取件
   ↓
点击“已取”
   ↓
从待取列表移除
   ↓
Live Activity 更新
```

---

# 3. 产品原则

## 3.1 第一原则：本地

App 默认完全离线。

禁止：

* 网络请求
* HTTP
* HTTPS
* 第三方 SDK
* Analytics
* Crash SDK
* 云数据库
* 云同步
* AI API

第一版甚至不需要：

```text
NSAppTransportSecurity
```

也不主动声明网络权限。

所有数据：

```text
短信文本
解析结果
取件码
驿站
历史记录
```

全部保存在本机。

---

# 4. 技术栈

使用：

```text
Swift
SwiftUI
SwiftData
App Intents
ActivityKit
WidgetKit
UserNotifications
Swift Regex
```

推荐最低部署版本：

```text
iOS 27.0
```

开发工具：

```text
Xcode
Swift 6+
```

UI：

```text
SwiftUI
```

数据库：

```text
SwiftData
```

快捷指令：

```text
App Intents
```

灵动岛 / 锁屏：

```text
ActivityKit
WidgetKit
Live Activities
```

Apple 官方目前的 Live Activities 架构就是 ActivityKit + WidgetKit + SwiftUI，并支持 Dynamic Island、Lock Screen 等系统位置。

---

# 5. App 名称

暂定：

## 取件

英文内部项目名：

```text
Pickup
```

Bundle ID：

```text
com.xxx.Pickup
```

如果正式开发时发现名称不可用，再修改。

---

# 6. UI 风格

## 核心关键词

```text
iOS 27
Liquid Glass
高级
极简
轻盈
通透
年轻
原生
克制
```

不要做：

```text
❌ 安卓风
❌ 传统后台风
❌ 大面积渐变
❌ 大量彩色卡片
❌ 玻璃拟物过度
❌ 毛玻璃堆叠
❌ 网红 App 风
❌ 复杂插画
❌ 过多图标
```

整体感觉应该接近：

> Apple 原生系统 App + Liquid Glass + 极简效率工具。

Liquid Glass 只作为视觉材质，不要把所有元素都做成透明玻璃。

---

# 7. UI 总体设计

采用：

```text
背景
↓
系统背景材质
↓
内容层
↓
少量 Liquid Glass 卡片
```

而不是：

```text
玻璃卡片
玻璃卡片
玻璃卡片
玻璃按钮
玻璃按钮
```

玻璃应该是“点缀”，不是整个界面。

---

# 8. 首页

首页是整个 App 最重要的页面。

页面标题：

```text
取件
```

顶部显示：

```text
待取 3 件
```

下面按驿站分组。

---

## 8.1 首页结构

```text
┌─────────────────────────────┐
│                             │
│  取件                 ⋯     │
│                             │
│  3 个包裹待取                │
│                             │
│ ┌─────────────────────────┐ │
│ │ 🏪 菜鸟驿站              │ │
│ │                         │ │
│ │  2 个包裹                │ │
│ │                         │ │
│ │  6-5218      [复制]      │ │
│ │  382917      [复制]      │ │
│ │                         │ │
│ │  XX路菜鸟驿站             │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ ▣ 丰巢                   │ │
│ │                         │ │
│ │  1 个包裹                │ │
│ │                         │ │
│ │  3829        [复制]      │ │
│ │                         │ │
│ │  XX小区3号柜             │ │
│ └─────────────────────────┘ │
│                             │
│                             │
│       首页    历史    设置   │
└─────────────────────────────┘
```

---

# 9. 驿站分组逻辑

这是产品最核心的数据展示方式。

不能：

```text
包裹 1
包裹 2
包裹 3
包裹 4
```

而应该：

```text
菜鸟驿站
 ├── 6-5218
 └── 382917

丰巢
 └── 3829

妈妈驿站
 └── A1298
```

也就是说：

> **Station 是第一层分组。**

---

# 10. 驿站卡片

每个驿站对应一个 Group Card。

例如：

```text
┌──────────────────────────────┐
│  🏪  菜鸟驿站                │
│      2 个包裹                 │
│                              │
│  6-5218                  ⧉   │
│                              │
│  382917                  ⧉   │
│                              │
│  XX路菜鸟驿站                 │
└──────────────────────────────┘
```

要求：

* 卡片圆角
* 使用系统材质
* 轻微透明
* 轻微背景模糊
* 不要明显阴影
* 不要粗边框
* 内容间距充足
* 验证码数字明显
* 复制按钮低调

验证码是视觉重点。

---

# 11. 验证码展示

验证码应该使用：

```text
.monospaced()
```

例如：

```text
6-5218
```

而不是：

```text
6-5218
```

普通字体。

推荐：

```text
font(.system(size: 24, weight: .semibold, design: .rounded))
```

或者：

```text
.monospacedDigit()
```

让验证码一眼可读。

---

# 12. 点击验证码

点击验证码：

```text
复制到剪贴板
```

然后出现非常轻的反馈：

```text
已复制
```

不要弹 UIAlert。

推荐：

```text
短暂 Toast / Inline Feedback
```

例如：

```text
✓ 已复制
```

0.8~1.2 秒自动消失。

---

# 13. 单个包裹操作

每个 PickupItem 可以：

```text
复制
已取
删除
```

但是首页不要同时显示三个按钮。

默认只显示：

```text
复制
```

长按或者详情页显示：

```text
标记已取
删除
```

避免首页过于拥挤。

---

# 14. 点击驿站卡片

点击：

```text
菜鸟驿站
```

进入：

```text
驿站详情
```

页面：

```text
菜鸟驿站

XX路菜鸟驿站

2 个包裹

┌──────────────────────┐
│ 6-5218               │
│                      │
│ [复制验证码]          │
│                      │
│ 收到：今天 14:32      │
└──────────────────────┘

┌──────────────────────┐
│ 382917               │
│                      │
│ [复制验证码]          │
│                      │
│ 收到：今天 12:18      │
└──────────────────────┘
```

底部：

```text
全部标记为已取
```

---

# 15. 底部 Tab

第一版使用 3 个 Tab：

```text
取件
历史
设置
```

不要做 5 个以上。

---

# 16. 历史页面

历史页面：

```text
历史

今天

菜鸟驿站
6-5218
已取 · 14:42

丰巢
3829
已取 · 13:21


昨天

妈妈驿站
A1298
已取 · 昨天 19:32
```

历史数据不需要 Live Activity。

历史页面主要用于：

> “我昨天那个包裹取件码是多少？”

---

# 17. 设置页面

第一版设置只需要：

```text
快捷指令

Live Activity

通知

解析规则

数据管理
```

其中：

```text
快捷指令
```

显示：

```text
快捷指令未配置
```

或者：

```text
快捷指令已配置
```

---

# 18. 快捷指令设计

这是 V1 的核心入口。

App 必须暴露 App Intent。

推荐设计：

```text
AddPickupFromTextIntent
```

输入：

```text
messageText: String
```

快捷指令调用：

```text
取件 → 添加取件信息
```

传入短信全文。

例如：

```text
【菜鸟驿站】
您的包裹已到达XX路菜鸟驿站，
请凭取件码 6-5218 取件。
```

App Intent：

```text
收到字符串
    ↓
解析
    ↓
保存
    ↓
更新 Live Activity
    ↓
返回成功
```

---

# 19. App Intent 要求

Intent：

```text
AddPickupFromTextIntent
```

职责：

```text
接收短信文本
```

不要在 Intent 里面堆所有业务逻辑。

Intent 只负责：

```text
输入
↓
调用 PickupParser
↓
调用 PickupRepository
↓
调用 LiveActivityManager
↓
返回结果
```

架构必须保持干净。

---

# 20. 推荐代码架构

```text
Pickup/
│
├── App/
│   ├── PickupApp.swift
│   └── AppEnvironment.swift
│
├── Models/
│   ├── PickupItem.swift
│   ├── PickupStation.swift
│   └── PickupStatus.swift
│
├── Parser/
│   ├── PickupParser.swift
│   ├── PickupParseResult.swift
│   ├── RegexRules.swift
│   ├── StationDetector.swift
│   └── CodeDetector.swift
│
├── Repository/
│   └── PickupRepository.swift
│
├── Intents/
│   ├── AddPickupFromTextIntent.swift
│   ├── MarkPickupCompleteIntent.swift
│   └── CopyPickupCodeIntent.swift
│
├── LiveActivity/
│   ├── PickupActivityAttributes.swift
│   ├── PickupActivityManager.swift
│   └── PickupLiveActivityView.swift
│
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── StationCard.swift
│   │   └── PickupCodeRow.swift
│   │
│   ├── History/
│   │   └── HistoryView.swift
│   │
│   ├── Station/
│   │   └── StationDetailView.swift
│   │
│   └── Settings/
│       └── SettingsView.swift
│
├── Components/
│   ├── GlassCard.swift
│   ├── CopyButton.swift
│   ├── EmptyState.swift
│   └── ToastView.swift
│
└── Shared/
    ├── ClipboardManager.swift
    ├── DateFormatter.swift
    └── AppConstants.swift
```

---

# 21. 数据模型

## PickupItem

字段：

```text
id: UUID

code: String

stationName: String?

stationAddress: String?

companyName: String?

rawMessage: String

status: PickupStatus

createdAt: Date

pickedAt: Date?

source: String

confidence: Double
```

Status：

```text
waiting
completed
deleted
```

---

# 22. 为什么要保存 rawMessage

必须保存短信原文。

例如：

```text
rawMessage
```

原因：

以后解析规则升级，可以重新解析历史数据。

例如第一版：

```text
菜鸟驿站
6-5218
```

第二版：

```text
菜鸟驿站
6-5218
XX路菜鸟驿站
```

就可以重新处理。

---

# 23. Station 模型

不要简单把驿站名称当成字符串。

可以设计逻辑上的 Station：

```text
stationKey
stationName
address
company
```

例如：

```text
stationKey:
cn.cainiao.xxroad

stationName:
菜鸟驿站

address:
XX路菜鸟驿站
```

但是第一版可以不单独建立 SwiftData Station 表。

可以根据：

```text
stationName + stationAddress
```

动态分组。

---

# 24. 分组规则

优先：

```text
stationName
+
stationAddress
```

如果相同：

```text
归为同一组
```

例如：

```text
菜鸟驿站
XX路菜鸟驿站
```

全部归：

```text
菜鸟驿站 / XX路菜鸟驿站
```

---

# 25. 快递短信解析

不要使用 AI。

不要调用 NLP 模型。

使用：

```text
关键词
+
正则表达式
+
模板规则
+
上下文评分
```

---

# 26. 解析流程

```text
短信文本
 ↓
Normalize
 ↓
去除多余空格
 ↓
关键词扫描
 ↓
识别快递/驿站
 ↓
识别取件码
 ↓
识别地址
 ↓
评分
 ↓
生成 ParseResult
```

---

# 27. 文本标准化

例如：

```text
取件码：6 - 5218
```

标准化成：

```text
取件码: 6-5218
```

处理：

* 全角标点
* 连续空格
* 换行
* 全角数字
* 中文冒号
* 中文括号

---

# 28. 取件码关键词

第一版支持：

```text
取件码
取货码
提货码
提取码
自提码
取件密码
取件凭证
取货凭证
验证码
柜门密码
开箱码
开柜码
```

注意：

> “验证码”不能直接认为一定是取件码。

必须结合快递上下文。

---

# 29. 快递上下文关键词

```text
包裹
快递
快件
驿站
取件
取货
自提
丰巢
菜鸟驿站
妈妈驿站
兔喜
中通
圆通
申通
韵达
极兔
顺丰
京东
邮政
```

---

# 30. 取件码正则

第一版不要只有一个正则。

设计多个候选规则。

例如：

```regex
(?:取件码|取货码|提货码|自提码|取件凭证)[：:\s]*([A-Za-z0-9-]{4,12})
```

数字型：

```regex
(?<!\d)\d{4,8}(?!\d)
```

带连接符：

```regex
(?<!\d)\d{1,4}[- ]\d{2,6}(?!\d)
```

字母数字：

```regex
(?<![A-Za-z0-9])[A-Za-z0-9]{4,10}(?![A-Za-z0-9])
```

但是：

> **候选结果不能直接使用，必须经过上下文评分。**

---

# 31. 取件码评分机制

例如：

```text
“取件码：6-5218”
```

评分：

```text
出现“取件码”       +50
距离关键词 < 10字符  +30
长度合理             +10
数字/字母混合合理     +5
```

普通短信里的：

```text
订单号 202610071234
```

应该降低评分。

例如：

```text
订单号
手机号
身份证
金额
日期
时间
```

这些上下文附近的数字：

```text
-50
```

---

# 32. 驿站识别

优先级：

### 1. 明确名称

例如：

```text
菜鸟驿站
丰巢
妈妈驿站
兔喜生活
```

直接识别。

### 2. 短信发送方

如果快捷指令可以提供 sender，则优先使用。

### 3. 文本上下文

例如：

```text
您的包裹已到达：
XX路菜鸟驿站
```

提取：

```text
XX路菜鸟驿站
```

### 4. 无法识别

显示：

```text
其他驿站
```

不要猜。

---

# 33. 地址识别

第一版地址识别不需要复杂 NLP。

使用关键词：

```text
地址
位置
地点
取件地址
存放于
位于
```

然后提取附近文本。

例如：

```text
地址：XX市XX区XX路123号
```

提取：

```text
XX市XX区XX路123号
```

如果没有地址：

```text
不显示地址
```

不要生成假的地址。

---

# 34. 解析结果

最终：

```swift
struct PickupParseResult {
    let code: String
    let stationName: String?
    let stationAddress: String?
    let companyName: String?
    let confidence: Double
    let rawMessage: String
}
```

如果：

```text
confidence < 0.6
```

不要自动创建。

如果：

```text
0.6...0.8
```

可以创建，但标记：

```text
needsReview = true
```

如果：

```text
> 0.8
```

直接创建。

---

# 35. 去重

同一条短信可能通过快捷指令重复传入。

必须去重。

生成：

```text
hash(rawMessage + code + station)
```

保存：

```text
sourceHash
```

如果已经存在：

```text
不重复创建
```

---

# 36. 多个验证码

一条短信可能有：

```text
取件码：
A1234
B5678
```

或者：

```text
验证码 1234、5678
```

解析器支持：

```text
[String]
```

而不是：

```text
String
```

但每一个验证码必须绑定同一个 Station。

例如：

```text
菜鸟驿站
 ├── A1234
 └── B5678
```

---

# 37. 一个驿站多个包裹

这是重点。

例如：

```text
菜鸟驿站

6-5218
382917
A1298
```

UI：

```text
菜鸟驿站
3 个包裹

6-5218    ⧉
382917    ⧉
A1298     ⧉
```

不要拆成三个完全独立的大卡片。

---

# 38. Live Activity 设计

使用：

```text
ActivityKit
WidgetKit
SwiftUI
```

Apple 官方要求 Live Activity 为不同展示形态设计布局，包括：

```text
Compact
Minimal
Expanded
Lock Screen
```

因此必须分别设计，而不是只做一个 SwiftUI View。

---

# 39. Live Activity 核心原则

不要：

```text
一个包裹 = 一个 Live Activity
```

而是：

```text
所有待取包裹
        ↓
一个 Pickup Live Activity
```

例如：

```text
还有 3 个包裹
```

---

# 40. 灵动岛 Compact

极简。

左侧：

```text
📦
```

右侧：

```text
3件
```

视觉：

```text
     ┌───────────────┐
     │ 📦       3件  │
     └───────────────┘
```

不要在 Compact 中显示验证码。

因为空间太小。

---

# 41. 灵动岛 Expanded

展开后：

```text
┌─────────────────────────────┐
│                             │
│ 📦 待取 3 件                 │
│                             │
│ 菜鸟驿站                     │
│ 6-5218    382917            │
│                             │
│ 丰巢                         │
│ 3829                         │
│                             │
│                  查看全部 → │
└─────────────────────────────┘
```

重点：

```text
驿站
验证码
数量
```

不要显示大量短信原文。

---

# 42. 灵动岛 Minimal

只显示：

```text
📦
```

或者：

```text
3
```

保持极简。

---

# 43. 锁屏 Live Activity

锁屏空间比灵动岛大。

设计：

```text
┌──────────────────────────────┐
│                              │
│  📦 待取 3 件                 │
│                              │
│  菜鸟驿站                     │
│  6-5218     382917           │
│                              │
│  丰巢                         │
│  3829                        │
│                              │
│  打开取件                     │
└──────────────────────────────┘
```

如果超过展示容量：

```text
还有 5 件
```

只显示前 2 个驿站。

点击进入 App。

---

# 44. Live Activity 更新

当新增：

```text
新增一个验证码
```

更新：

```text
waitingCount
stations
codes
```

当用户：

```text
标记已取
```

重新计算。

如果：

```text
waitingCount == 0
```

结束 Live Activity。

---

# 45. Live Activity 生命周期

```text
0 个待取
 ↓
不显示

收到第一个包裹
 ↓
启动

新增包裹
 ↓
update

取走一个
 ↓
update

全部取走
 ↓
end
```

---

# 46. Live Activity 不需要服务器

因为第一版没有远程推送。

直接：

```text
App Intent
 ↓
本地数据库
 ↓
ActivityKit update
```

即可。

ActivityKit 的本地 `update` 机制可以用于不依赖服务器推送的 Live Activity；App Intent 也可以让系统在不打开 App 前台的情况下执行相关逻辑。

---

# 47. Live Activity 与 App Intent

核心 Intent：

```text
AddPickupFromTextIntent
```

流程：

```text
Shortcuts
 ↓
App Intent
 ↓
Parser
 ↓
SwiftData
 ↓
ActivityManager
 ↓
ActivityKit
```

需要保证：

```text
Intent 执行完成之前
数据已经保存
Live Activity 已更新
```

---

# 48. Live Activity 交互

第一版只允许一个主要操作：

```text
查看
```

点击：

```text
Live Activity
```

直接进入：

```text
首页
```

或者：

```text
指定驿站详情
```

不要在 Live Activity 里面堆：

```text
复制
已取
删除
分享
```

Apple 对 Live Activity 的设计建议也是保持交互简单、直接，并避免大量按钮占用展示空间。

---

# 49. 视觉颜色

使用系统颜色。

主要：

```text
.primary
.secondary
.tertiary
```

辅助色可以非常克制。

推荐：

```text
背景：
systemBackground

次级背景：
secondarySystemBackground

玻璃：
Material / Liquid Glass 系统材质

强调色：
systemBlue
```

不要建立复杂的品牌色体系。

---

# 50. 圆角

推荐：

```text
16
20
24
```

大卡片：

```text
24
```

按钮：

```text
14~18
```

不要使用：

```text
40+
```

避免“糖果 App”感觉。

---

# 51. 字体

页面标题：

```text
.largeTitle
.bold()
```

驿站名称：

```text
.title3
.semibold()
```

验证码：

```text
.title2
.monospacedDigit()
.semibold()
```

辅助信息：

```text
.subheadline
.secondary
```

尽量使用系统字体。

---

# 52. 动画

动画必须克制。

新增包裹：

```text
卡片轻微出现
```

复制：

```text
按钮状态变化
```

已取：

```text
卡片淡出/收缩
```

不要：

```text
❌ 大幅缩放
❌ 粒子
❌ 彩带
❌ 复杂转场
```

Liquid Glass 本身已经有足够视觉表现。

---

# 53. Empty State

没有待取包裹：

```text
        📦

      暂时没有包裹

收到取件短信后，
取件码会自动出现在这里。
```

下面：

```text
配置快捷指令
```

按钮。

---

# 54. 首次启动

第一次启动：

```text
┌───────────────────────────┐
│                           │
│           📦              │
│                           │
│       取件，简单一点       │
│                           │
│  自动整理短信里的取件码，   │
│  按驿站帮你放好。           │
│                           │
│       [开始设置]           │
│                           │
└───────────────────────────┘
```

下一页：

```text
快捷指令

让快捷指令把短信内容
交给取件。

[配置快捷指令]
```

---

# 55. 快捷指令配置

App Intent 要有用户友好的名称。

例如：

```text
添加取件短信
```

Shortcuts 中：

```text
添加取件短信
```

参数：

```text
短信内容
```

最终用户体验：

```text
收到短信
 ↓
快捷指令
 ↓
添加取件短信
```

---

# 56. 快捷指令不要依赖 App 前台

目标：

```text
快捷指令执行
 ↓
App 不需要打开界面
 ↓
Intent 在后台处理
 ↓
数据库更新
 ↓
Live Activity 更新
```

Apple 的 `LiveActivityIntent` 就是为系统执行相关 Live Activity 操作而设计的。

---

# 57. 本地通知

第一版可以提供一个简单通知：

```text
新增取件码

菜鸟驿站
6-5218
```

但是不要默认频繁通知。

设置：

```text
通知
[开启]
```

如果系统权限允许，再发送。

---

# 58. 数据隐私

设置页面增加：

```text
隐私

所有取件信息仅保存在此 iPhone。

本 App 不上传短信内容，
不连接服务器，
不使用 AI，
不收集使用数据。
```

这应该成为产品卖点。

---

# 59. 不需要登录

App 启动直接进入首页。

不要：

```text
登录
注册
手机号
验证码登录
```

---

# 60. 不需要联网

代码层面避免：

```text
URLSession
Alamofire
Firebase
Supabase
CloudKit
```

第一版不要加入。

---

# 61. 不使用 AI

解析完全：

```text
Regex
+
Keyword
+
Template
+
Score
```

AI 永远不是第一版依赖。

---

# 62. 测试短信

开发阶段必须建立 Parser Test Suite。

至少包含：

```text
菜鸟驿站
丰巢
妈妈驿站
兔喜
中通
圆通
申通
韵达
极兔
顺丰
京东
邮政
```

以及：

```text
纯数字取件码
带 - 取件码
字母数字
多个取件码
没有取件码
有订单号但没有取件码
验证码短信
营销短信
银行短信
验证码短信
```

---

# 63. 典型测试

输入：

```text
【菜鸟驿站】
您的包裹已到达XX路菜鸟驿站，
请凭取件码 6-5218 取件。
```

输出：

```text
stationName = 菜鸟驿站
stationAddress = XX路菜鸟驿站
code = 6-5218
confidence > 0.8
```

---

# 64. 第二个测试

输入：

```text
【丰巢】
您的快递已存入XX小区3号柜
取件码：3829
```

输出：

```text
stationName = 丰巢
stationAddress = XX小区3号柜
code = 3829
```

---

# 65. 第三个测试

输入：

```text
【妈妈驿站】
包裹已到店，请凭 A1298 领取。
```

输出：

```text
stationName = 妈妈驿站
code = A1298
```

---

# 66. 错误测试

输入：

```text
您的订单编号为：
20261007123891
```

结果：

```text
不要创建 PickupItem
```

---

# 67. 重复短信

相同短信连续传入两次：

```text
第一次 → 创建
第二次 → 忽略
```

不能出现：

```text
菜鸟驿站
6-5218

菜鸟驿站
6-5218
```

两条重复数据。

---

# 68. UI 状态

首页必须支持：

```text
loading
empty
normal
error
```

但不要出现复杂 loading 页面。

SwiftUI 使用：

```text
ProgressView
```

即可。

---

# 69. 无法识别的短信

如果 App 收到：

```text
这是一条看不懂的短信
```

不要强行猜。

返回：

```text
无法识别
```

Intent 可以返回：

```text
未发现明确的取件码
```

同时不要创建数据。

---

# 70. 手动添加

虽然主要入口是快捷指令，但 V1 建议保留：

```text
+
```

手动添加。

页面：

```text
验证码
驿站
地址
```

这样开发测试也非常方便。

---

# 71. 搜索

第一版搜索只搜索：

```text
验证码
驿站名称
地址
快递公司
```

例如：

```text
搜索：
菜鸟
```

得到：

```text
菜鸟驿站
```

---

# 72. 排序

待取：

```text
最新收到的在前
```

历史：

```text
最新完成的在前
```

驿站组：

```text
最近收到包裹的驿站在前
```

---

# 73. 数据生命周期

默认：

```text
waiting
```

用户点击：

```text
已取
```

变：

```text
completed
```

历史保留。

不要自动删除。

以后可以增加：

```text
自动清理超过 30 天记录
```

但第一版不要。

---

# 74. Live Activity 聚合数据

建议：

```swift
struct PickupActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var waitingCount: Int
        var stations: [StationSummary]
        var updatedAt: Date
    }

    let activityID: String
}
```

注意：

Live Activity 的数据必须尽量小。

不要把完整：

```text
rawMessage
```

放进去。

---

# 75. StationSummary

```swift
struct StationSummary: Codable, Hashable {
    let name: String
    let codes: [String]
}
```

例如：

```text
[
    {
        name: "菜鸟驿站",
        codes: ["6-5218", "382917"]
    },
    {
        name: "丰巢",
        codes: ["3829"]
    }
]
```

---

# 76. ActivityManager

集中处理：

```text
start()
update()
end()
refresh()
```

不要让 View 直接操作 ActivityKit。

例如：

```swift
final class PickupActivityManager {

    func refreshFromDatabase() async

    func startIfNeeded() async

    func update() async

    func endIfEmpty() async
}
```

---

# 77. Repository

所有数据库操作通过：

```text
PickupRepository
```

不要在 View 里面直接：

```text
modelContext.insert()
```

业务逻辑必须集中。

---

# 78. Parser

Parser 必须是纯函数式设计。

输入：

```text
String
```

输出：

```text
PickupParseResult?
```

这样可以非常容易写 Unit Test。

---

# 79. Parser 不允许依赖 UI

禁止：

```text
Parser → SwiftUI
```

Parser 只负责：

```text
文本
 ↓
结构化数据
```

---

# 80. App Intent 不允许负责 UI

Intent：

```text
接收数据
 ↓
业务处理
```

UI：

```text
SwiftUI
```

完全分离。

---

# 81. 项目 Target

建议：

```text
Pickup
PickupWidget
```

其中：

```text
Pickup
```

负责：

* App
* SwiftUI
* SwiftData
* Parser
* App Intents
* ActivityManager

```text
PickupWidget
```

负责：

* Widget
* Live Activity
* Dynamic Island

---

# 82. App Group

由于 App 与 Widget Extension 需要共享本地数据，优先设计：

```text
App Groups
```

例如：

```text
group.com.xxx.Pickup
```

数据库放在共享容器。

注意：

> SwiftData 的共享存储方案必须从项目一开始设计好，不要等 Widget 做完以后再改。

---

# 83. Widget

V1 可以提供：

```text
小组件
```

内容：

```text
待取 3 件
```

中号：

```text
待取 3 件

菜鸟驿站
6-5218
382917

丰巢
3829
```

但 Widget 不是第一优先级。

优先级：

```text
快捷指令
>
解析
>
数据库
>
Live Activity
>
首页
>
Widget
```

---

# 84. 开发顺序

不要一次性生成整个项目。

严格按照：

## Phase 1

```text
Xcode Project
SwiftUI
SwiftData
基础页面
```

确认：

```text
可以运行
```

---

## Phase 2

实现：

```text
PickupParser
```

先不做 UI。

测试：

```text
20~50 条短信
```

---

## Phase 3

实现：

```text
App Intent
```

让快捷指令可以：

```text
传字符串
```

进入 App。

---

## Phase 4

实现：

```text
SwiftData
```

保存解析结果。

---

## Phase 5

实现：

```text
首页
驿站分组
复制
已取
历史
```

---

## Phase 6

实现：

```text
ActivityKit
Live Activity
Dynamic Island
Lock Screen
```

---

## Phase 7

实现：

```text
Widget
```

---

## Phase 8

做整体 Liquid Glass UI polish。

---

# 85. Vibe Coding 要求

AI Coding Agent 必须遵守：

### 不要一次生成全部代码。

必须：

```text
分析
 ↓
拆任务
 ↓
实现
 ↓
编译
 ↓
修复
 ↓
测试
 ↓
再进入下一阶段
```

每完成一个 Phase：

```text
必须保证项目可以编译
```

---

# 86. Coding Agent 工作规则

要求 AI：

```text
1. 不随意更换技术栈
2. 不引入第三方库
3. 不引入网络请求
4. 不加入 AI
5. 不创建后端
6. 不增加账号系统
7. 不自行增加产品功能
8. 不为了“方便”使用 Firebase
9. 不为了 UI 使用第三方组件库
10. 优先使用 Apple 原生 API
```

---

# 87. UI Coding 规则

SwiftUI 优先：

```text
Material
System Colors
SF Symbols
System Typography
Native Animation
```

Liquid Glass 要：

```text
克制
统一
系统化
```

不要自己实现一个假的：

```text
Blur + Opacity + Shadow
```

去模拟所有玻璃效果。

优先使用 iOS 27 提供的原生视觉能力。

---

# 88. SF Symbols

推荐：

```text
shippingbox
shippingbox.fill
building.2
doc.on.doc
checkmark
clock
tray
gearshape
plus
magnifyingglass
```

不要使用 emoji 作为主要 UI 图标。

Emoji 只可以在 Empty State 中作为轻微视觉元素。

---

# 89. 首页视觉重点

优先级：

```text
验证码
>
驿站
>
包裹数量
>
地址
>
时间
```

用户打开 App 的第一眼应该看到：

```text
6-5218
```

而不是：

```text
“您的包裹已经到达……”
```

---

# 90. 核心交互

最常用动作：

```text
复制验证码
```

必须做到：

```text
打开 App
 ↓
看到验证码
 ↓
一键复制
```

最多两步。

---

# 91. 已取

已取操作：

```text
长按验证码
```

出现：

```text
标记为已取
```

或者：

```text
滑动操作
```

第一版优先使用：

```text
contextMenu
```

避免复杂 Swipe UI。

---

# 92. 站点排序

例如：

```text
菜鸟驿站  2件
丰巢      1件
```

按照：

```text
最近收到时间 DESC
```

而不是按照：

```text
名称 ASC
```

---

# 93. 多站点场景

用户可能同时拥有：

```text
菜鸟驿站
XX小区菜鸟驿站

菜鸟驿站
XX路菜鸟驿站
```

不能简单根据：

```text
stationName == 菜鸟驿站
```

合并。

应该：

```text
stationName + address
```

作为逻辑分组依据。

这样：

```text
菜鸟驿站 / XX小区
```

和：

```text
菜鸟驿站 / XX路
```

可以分别显示。

---

# 94. Live Activity 多驿站展示

例如：

```text
待取 4 件

菜鸟驿站
6-5218 · 382917

丰巢
3829

妈妈驿站
A1298
```

但是 Compact：

```text
📦 4
```

Expanded：

```text
📦 待取 4 件

菜鸟驿站
6-5218 · 382917

丰巢
3829
```

Lock Screen：

```text
📦 4 个包裹待取

菜鸟驿站
6-5218
382917

丰巢
3829
```

超过容量：

```text
还有 2 个包裹
```

---

# 95. App 内顶部状态

如果存在待取：

```text
3 个包裹待取
```

如果只有一个：

```text
1 个包裹待取
```

如果没有：

```text
今天没有待取包裹
```

不要使用：

```text
3 Tasks
```

全中文。

---

# 96. 错误处理

如果快捷指令传入空字符串：

```text
没有收到短信内容
```

如果没有解析出取件码：

```text
没有发现明确的取件码
```

如果数据库错误：

```text
保存失败，请稍后重试
```

不要展示：

```text
CoreData error
SwiftData error
Fatal error
```

---

# 97. 日志

开发阶段允许：

```text
os.Logger
```

例如：

```text
[Parser]
[Intent]
[Database]
[Activity]
```

Release：

```text
不要记录短信原文
```

特别是：

```text
rawMessage
```

不能写入系统日志。

---

# 98. 隐私原则

禁止：

```text
print(rawMessage)
```

禁止：

```text
logger.info(rawMessage)
```

禁止：

```text
上传 rawMessage
```

禁止：

```text
Analytics event
```

---

# 99. App Icon

第一版 App Icon：

极简。

方向：

```text
一个抽象的包裹盒子
+
轻微玻璃质感
```

不要：

```text
快递员
卡通人物
快递车
复杂文字
“取件”两个字
```

图标应该像一个真正的 iOS 原生效率工具。

---

# 100. 最终产品结构

```text
                    ┌──────────────┐
                    │    短信       │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   快捷指令    │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │  App Intent  │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │  本地解析器   │
                    │ Regex/规则   │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   SwiftData  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
           首页列表      历史记录     Live Activity
              │                         │
              │                    ┌────┴────┐
              │                    ▼         ▼
              │                  灵动岛     锁屏
              │
              ▼
          按驿站分组
```

---

# 101. V1 完成标准

只有满足以下条件，才算 V1 完成：

### 数据

* [ ] 完全本地
* [ ] SwiftData 正常
* [ ] 可以保存取件码
* [ ] 可以保存驿站
* [ ] 可以保存地址
* [ ] 可以保存原始短信
* [ ] 可以去重

### 快捷指令

* [ ] App Intent 可以被快捷指令发现
* [ ] 可以传入短信文本
* [ ] App 不需要打开前台
* [ ] 可以自动解析
* [ ] 解析成功后自动保存

### 解析

* [ ] 菜鸟
* [ ] 丰巢
* [ ] 妈妈驿站
* [ ] 兔喜
* [ ] 常见快递
* [ ] 纯数字验证码
* [ ] `6-5218`
* [ ] 字母数字验证码
* [ ] 多验证码
* [ ] 错误短信过滤
* [ ] 重复短信过滤

### UI

* [ ] Liquid Glass 风格
* [ ] 首页
* [ ] 驿站分组
* [ ] 验证码大字体
* [ ] 一键复制
* [ ] 已取
* [ ] 历史
* [ ] 设置
* [ ] Empty State

### Live Activity

* [ ] Dynamic Island Compact
* [ ] Dynamic Island Expanded
* [ ] Minimal
* [ ] Lock Screen
* [ ] 多驿站
* [ ] 多验证码
* [ ] 自动更新
* [ ] 全部取完后结束

### 隐私

* [ ] 无服务器
* [ ] 无网络
* [ ] 无 AI
* [ ] 无第三方 SDK
* [ ] 不记录短信原文日志

---

# 102. 给 AI Coding Agent 的最终指令

你现在是这个项目的主程和 UI 工程师。

请严格按照本文档实现一个：

**iOS 27 原生 SwiftUI 本地取件码管理 App。**

核心产品：

> 快捷指令把短信文本传入 App，App 本地使用规则 + 正则识别驿站和取件码，以驿站为组保存和展示，并通过 ActivityKit / Live Activities 展示待取包裹数量和取件码。

技术要求：

```text
Swift
SwiftUI
SwiftData
App Intents
ActivityKit
WidgetKit
UserNotifications
```

严格禁止：

```text
网络
后端
API
AI
第三方 SDK
云同步
账号系统
广告
```

UI：

```text
iOS 27
Liquid Glass
Apple Native
极简
高级
克制
```

数据：

```text
本地存储
```

核心分组：

```text
Station
 ├── PickupCode
 ├── PickupCode
 └── PickupCode
```

而不是：

```text
PickupCode
PickupCode
PickupCode
```

Live Activity：

```text
所有待取包裹
        ↓
一个 Live Activity
        ↓
按驿站聚合
```

开发必须采用：

```text
Phase 1 → 编译
Phase 2 → 编译
Phase 3 → 编译
...
```

不要一次生成全部代码。

每一个阶段完成以后：

1. 检查编译错误
2. 修复错误
3. 检查架构
4. 运行测试
5. 再继续下一阶段

不要擅自增加功能。

如果发现 Apple API 在 iOS 27 上存在差异，优先采用 iOS 27 官方 API，而不是为了兼容旧版本而降低实现质量。

最终目标不是“代码能跑”，而是：

> **做出一个真正像 Apple 原生 App 的、极简、高级、完全本地化的取件码工具。**

第一优先级：

```text
快捷指令
→
本地解析
→
驿站分组
→
验证码展示
→
Live Activity
→
灵动岛
→
锁屏
```

第二优先级：

```text
历史
→
Widget
→
细节优化
```

不要在第一版加入任何与“取件码整理”无关的功能。

---

# 103. 最终用户体验

理想状态下：

用户收到：

```text
【菜鸟驿站】
您的包裹已到达XX路菜鸟驿站，
请凭取件码 6-5218 取件。
```

几乎无需操作。

快捷指令：

```text
↓
添加取件短信
```

App：

```text
解析成功

菜鸟驿站
6-5218
```

首页：

```text
菜鸟驿站
1 个包裹

6-5218
```

灵动岛：

```text
📦 1
```

展开：

```text
📦 待取 1 件

菜鸟驿站
6-5218
```

锁屏：

```text
📦 菜鸟驿站
6-5218
```

到驿站：

```text
打开锁屏
↓
看到验证码
↓
复制
↓
取件
↓
标记已取
```

整个流程应该让用户感觉：

> **“我根本没管理过快递，它自己就把取件码放好了。”**

这就是这个产品 V1 最重要的体验目标。
