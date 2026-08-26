# Ease 体感与流畅度（评估后规格）

原稿把「材质阴影、双轴图、Widget、Task.detached 预加载」打包成质感升级。对照现有 **SwiftUI + SwiftData + HealthKit**、`PRD.md` / `AGENT.md`，以及仓库里已经落地的交互，下面是逐条裁决。只把**采用**的写进可执行规格；拒绝的不改产品边界。

原则：安静账本，不靠玻璃拟态、弹跳和彩蛋制造高级感。体感来自确认反馈、少一次磁盘读、数字会走位，而不是换一套视觉语言。

## 裁决一览

| 建议 | 裁决 | 原因（对照现状） |
|---|---|---|
| OCR / 打卡 / 滑动时 `.sensoryFeedback` | **采用（收窄）** | `LogSheetView` 已有 success/error/selection；列表删除已有 warning。补 OCR 成功、饮食芯片、滑动删除即可。不要每个按钮都震。 |
| 趋势图拖拽 + 十字线 + 7 日均线 + **体脂** | **部分采用** | `TrendChartCard` 已有 `DragGesture`、`RuleMark`、黑色 Tooltip、7 日均线虚线。缺的是松手后仍钉住读数、Tooltip 附带均线。体脂上主图 = 双轴，PRD **仍不做**。 |
| WidgetKit 一键体重 / 三餐拍照 | **不采用（本期）** | PRD 写明不做桌面 Widget。Extension 写 SwiftData/CloudKit 成本高；锁屏 Widget **不能**直接调相机，「三餐快捷拍照」只能跳回 App，路径并不更短。 |
| `MealPhotoStore` + `NSCache` | **采用** | 缩略图每次 `.task` 都 `Data(contentsOf:)`。日历三餐格滚动会打磁盘。缓存 + 解码缩略图，不改文件名契约。 |
| `Task.detached` 预加载 HK 与 pace | **不采用原文；改缓存** | `loadAll` 已在 `scenePhase == .active` 异步跑。`Task.detached` 容易打穿 MainActor / HK 客户端约定。Sheet 关闭时又全量 `reload` 才是卡顿源。改为 TTL 缓存，禁止 detached + `ModelContext`。 |
| `.contentTransition(.numericText())` | **采用（白名单）** | 英雄体重、BMI 数字、剩余 kg、估算天数。短 `snappy`。禁止弹跳、放大、彩带动效（PRD 禁庆祝）。 |
| 首页 `ultraThinMaterial` + 0.04 阴影 | **不采用** | Milk & Card 用填色分层（白 / `#F2F3F5`），AGENT 禁重阴影。毛玻璃在 Light 奶油底上会变 iOS 默认玻璃，不像现有账本。 |
| 经期 Accent 渐变铺首页 | **仅详情 Sheet** | AGENT 允许睡眠/经期/消耗 **Sheet 内**安静 tint。首页莫兰迪方块保持单色填，不做粉橙渐变看板。 |
| 全局骨架屏 `.redacted` | **仅 HK 首屏** | 体重/饮食是本地 SwiftData，瞬时有数，套骨架会假跳动。只给睡眠/经期/消耗第一次 `loadAll` 未完成时用。 |
| Sheet `.presentationDetents` + Spring | **采用（补齐）** | 日历日明细、模块编辑已有 medium/large。体重/饮食/围度/BMI/HK 详情 Sheet 未统一。用系统 detent，不自写弹跳曲线。 |

## 采用规格

### 1. 触觉（确认，不是庆祝）

只在「系统已经认定一次结果」时触发：

* `ScaleOCR` 解析出合法体重/体脂 → `.success`（失败保持现有 `.error`，不要再加一层）。
* 饮食三选一 / 变量标签选中 → `.selection`（`LogSheetView` / 日历日明细已有，勿重复叠两下）。
* 保存体重或饮食成功 → `.success`（已有 `saveSuccessPulse`）。
* 滑动或上下文菜单删除 `WeightLog` → `.warning`（已有）。

禁止：点 Tab、点莫兰迪方块、拖图表每像素、进度到 100%。图表 scrub **最多**按日变化节流 `.selection`（同一天不连震）。

### 2. 趋势图 scrub（单轴体重）

在现有 `chartOverlay` + 黑 Tooltip 上补齐，不换手势库：

* 拖动时保持现有竖线 `RuleMark` + 顶上黑胶囊（这就是十字线，不要再画全屏准星）。
* Tooltip 内容：日期、**当日最后一次体重**；若该日有 7 日均线，用 secondary 附一行均线。不要体脂、不要经期点。
* 松手后读数**钉住**到下一次拖动或点空白；现在 `onEnded { preview = nil }` 应改掉。
* 点已有日仍打开体重 Sheet。Y 轴仍是体重；均线只是同轴虚线（已存在）。

### 3. 三餐图内存缓存

`MealPhotoStore`：

* 进程内 `NSCache<NSString, UIImage>`，key = 文件名。`countLimit` 约 30，`totalCostLimit` 按像素估算。
* `loadImage`：命中直接返回；未命中再后台读盘，解码为缩略图（最长边 ≤ 屏幕宽或格宽 × scale），再写入 cache。
* `deleteSync` / 清数据时 `removeObject`。不改 Documents 文件名、不改 `DailyRecord` 只存文件名的契约。
* `MealPhotoThumbnail` 仍 `.task(id: fileName)`，不要在 View 里再搞一套 cache。

### 4. HealthKit / 估算：缓存，不 detached

* `HealthKitReader.loadAll` 保持现有 async；结果缓存在 `DashboardViewModel`（或小型 `HealthKitCache`），带时间戳。前台且未过期（例如 60s）则跳过全量查询。
* Sheet 关闭、切 Tab **不要**无条件 `reloadHealthAndNotifications`。改体重/饮食后只重排通知即可；HK 用缓存。
* `AdvancedPaceEstimator` 继续在 Trend 出现时算。数据是内存里的 `[WeightSample]` + 已缓存的 HK map，不必 `Task.detached`。若以后要后台算，用 `Task { }` + `Sendable` 快照，禁止跨隔离域碰 `ModelContext`。
* 睡眠/经期/消耗 Sheet：缓存未就绪时 `.redacted(reason: .placeholder)` + 淡入；有缓存则直接出数。体重 Tab 本地数字不要骨架。

### 5. 数字过渡

仅白名单：`WeightHeroView` 体重、首页 BMI 数字、阶段卡剩余 kg、趋势高级估算天数。

```swift
.contentTransition(.numericText())
.animation(.snappy(duration: 0.25), value: number)
```

无数字时的「—」不要套 numericText。禁止匹配进度条弹跳、卡片缩放。

### 6. 录入 Sheet 手感

`LogSheetView`、`MetricSheet`、BMI / Sleep / Cycle / Energy 详情：

* `.presentationDetents([.medium, .large])`
* `.presentationDragIndicator(.visible)`
* `.presentationContentInteraction(.scrolls)`（内容可滚时）

动画走系统 sheet spring，不要自定义 `spring(response:damping)` 夸张回弹。模块编辑 Sheet 已符合，勿再套一层。

### 7. 经期 Sheet 内 tint（可选、克制）

只在 `CycleDetailSheet` 摘要卡：经期日用现有 `EasePalette` 粉做 **低饱和** 背景或细条，不是全屏渐变，不是首页方块换皮。文案仍是事实，不写关怀口号。

## 明确不写进实现

* WidgetKit / App Intent / 锁屏组件 / 从 Widget 拍照。
* 趋势图第二轴、Tooltip 体脂、双指缩放（未要求且易和 scrub 抢手势）。
* 首页 `ultraThinMaterial`、卡片 drop shadow（含 0.04）。
* `Task.detached` 包 `HealthKitReader` 或 SwiftData。
* 全局 skeleton、庆祝式 haptic、进度 100% 动效。

## 建议落地顺序

1. `NSCache` 缩略图（滚动掉帧最实）  
2. HK 结果 TTL、去掉多余 reload  
3. 图表钉住 Tooltip + 均线读数  
4. Sheet detents 对齐  
5. numericText 白名单  
6. OCR/保存 haptic 补洞  
7. 经期 Sheet 微 tint（可最后、可砍）

Windows 不能 `xcodebuild`。实现后在 Mac 真机测：日历三餐格快滚、趋势拖读数、VoiceOver 下数字过渡、删体重后 HK 详情是否仍用缓存而不是空白。
