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
* 饮食四选一 / 变量标签选中 → `.selection`（`LogSheetView` / 日历日明细已有，勿重复叠两下）。
* 保存体重或饮食成功 → `.success`（已有 `saveSuccessPulse`）。
* 滑动或上下文菜单删除 `WeightLog` → `.warning`（已有）。

禁止：点 Tab、点莫兰迪方块、拖图表每像素、进度到 100%。图表 scrub **最多**按日变化节流 `.selection`（同一天不连震）。

### 2. 趋势图 scrub（单轴体重）

在现有 `chartOverlay` + 黑 Tooltip 上补齐，不换手势库：

* 拖动时保持竖线 `RuleMark` + 黑胶囊（十字线）。胶囊用 `chartOverlay` 按点定位，**不要** `chartPlotStyle` 顶 padding，否则点和 Y 轴会对不齐。
* Tooltip 内容：日期、**当日最后一次体重**；若该日有 7 日均线，用 secondary 附一行均线。不要体脂、不要经期点。竖线 X 用该日最后一次称重时刻，不要当天 00:00。
* 松手后读数**钉住**到下一次拖动或点空白。拖动只更新 Tooltip，**不得**打开体重 Sheet。点已有日（位移 < 8pt）才打开 Sheet，并立刻清掉选择。体重 / 均线 / 目标共用同一个 Y 编码名。

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
* 首页 `ultraThinMaterial`、卡片 drop shadow（含 0.04）。餐图抠图主体层可用 `opacity(0.12) radius 8`，不要加到卡片或首页方块。
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

第一批（缩略图缓存、HK TTL、图表钉住、Sheet detents、numericText、OCR haptic、经期 tint）**已落地**。下面是第二批对照代码后的裁决。

## 第二批建议（录入 / 图 / 导入 / 空状态 / a11y）

| 建议 | 裁决 | 原因（对照现状） |
|---|---|---|
| `UIImpactFeedbackGenerator`：保存、饮食芯片、`DayPickerHeader` 翻日 | **不采用原文；触觉已收窄落地** | `LogSheetView` 已用 `.sensoryFeedback` 做 save / OCR / diet / tag，再接 UIKit generator 会震两下。`DayPickerHeader` **不在 4-Tab 路径上**（死代码），不要为它加震。日历翻月可补一次 `.selection`（见 §8）。 |
| 锁屏/主屏 Widget 一键体重或拍照三餐 | **不采用** | PRD **仍不做**桌面 Widget。锁屏 Widget 不能直接开相机；Extension 读 SwiftData/CloudKit 成本高，路径并不更短。 |
| 三餐图 Hero 全屏 + 长按替换/删除 | **采用（收窄）** | 日历格单击**有图也打开**来源对话框，看不清原图。改为有图单击全屏预览；空格单击 / 长按走现有拍照·相册·删除。不要 `matchedGeometryEffect`（和 Sheet detent 抢动画）。 |
| 趋势图拖拽 + Tooltip 体重/均线/**体脂** | **图表交互已落地；体脂仍不做** | `TrendChartCard` 已有拖拽竖线、钉住读数、均线附行。体脂上主图 = 双轴，PRD 禁止。 |
| 达标日改成「10 月中旬」软区间 | **采用** | PRD 写「不是激励倒计时」，阶段卡已是 `around` 某日；高级卡却把**精确日期 + 剩余天数**做成主数字，更像倒计时。只改文案桶，不改 OLS。 |
| 导入预览：无效/重复行折叠 + 行号 | **采用（收窄）** | `ImportPreviewSheet` 只有 count。个人校对 CSV 需要行号，但不要表格 diff、不要把最多 5000 条 skipped 全载进视图。最多 20 条样本。 |
| 空状态加「补记体重 / 一键同步 HK」 | **部分采用** | `EaseEmptyState` **已有**主按钮；趋势空态已「去记录」。历史 Sheet 空态缺 CTA，补上。**禁止**「一键同步 HealthKit」：HK 只读静默，没有可点的写入/强制同步 API，造按钮是假能力。 |
| `TodayStripView` / `EaseCard` 特大字号；`ProgressRingView` VoiceOver | **采用（白名单，对着活 UI）** | `EaseCard` 已纵向长高。`TodayStripView` 与 `ProgressRingView` **不在 4-Tab 路径**。补：首页方块说明文字、阶段卡、睡眠/经期环所在卡的 `accessibilityLabel`；日历格在无障碍字号下允许换行/缩放。不要全局重做字号。 |

## 采用规格（第二批）

### 8. 日历翻月触觉

只在日历 Tab 换月（chevron，`visibleMonth` 变化）触发 `.selection`。不要：每个日期格、每个 Tab、每个莫兰迪方块。不要引入 `UIImpactFeedbackGenerator`。

### 9. 三餐图全屏预览（不是 Hero 相册）

`LogSheetView` 饮食餐次横滑与 `CalendarDayDetailSheet` 同一套 `MealPhotoCarousel`：

* **无图**：单击 → 现有来源对话框（拍照 / 相册 / 取消）。
* **有图**：单击 → `fullScreenCover` 看原图（奶油底或黑底均可，关闭用系统关闭控件）。长按 → 替换/删除（现有 `confirmationDialog` / context menu）。
* 预览读 **Documents 原图**，不要把原图像素写进缩略图 `NSCache`。可在 `MealPhotoStore` 加 `loadOriginal`，与 `loadImage`（≤512）分开。
* 默认抠图（本地 Vision PNG sidecar）。魔棒切换单卡覆盖；全屏预览仍是原图。主体轻阴影只打在抠图层。
* 不要 `matchedGeometryEffect`、不要第三方图片浏览器、不要双指相册手势库。

### 10. 软性达标区间（只改文案）

内部仍算精确 `eta` / `daysRemaining`（隐藏护栏、730 天、测试不变）。UI：

* 共用一个旬桶：日 1–10 上旬、11–20 中旬、21–月末下旬；英文 `early / mid / late {Month}`。距今 ≤7 天用「本周内」/ `later this week`，不要「还有 3 天」。
* **阶段卡**（§8.3.A）：`At this pace, around mid-October.` / `按近况大约 10 月中旬。` 不再插入具体日号。
* **高级卡**（§8.3.B）：主行是旬区间，字重可以大；**不要**再并排大号精确日期 + 「大约 N 天」倒计时。睡眠/消耗/经期因子读数保留。
* `numericText` 白名单去掉高级卡天数（天数不再是主数字）。禁止「你将成功」类语气。

### 11. 导入 skipped 样本（最多 20 行）

`CSVImporter.Preview` 在现有 count 之外，增加 `skippedSamples`（封顶 20）：CSV **行号**（含表头，表头为第 1 行）+ 类别（invalid / duplicate）+ 原因 key。原因只限：未来日期、无法解析、越界、未知 `metricKey`、重复。其余条数仍用 `invalidCount` / `duplicateCount` 显示。

`ImportPreviewSheet`：count 摘要保留；count > 0 时用系统 `DisclosureGroup` 展开样本，一行一条，secondary 字号。截断文案保持现状。

禁止：整表 diff、高亮原 CSV 单元格、跳转 Files、把 skipped 全量数组留在预览模型里。

### 12. 空状态 CTA 与无障碍白名单

* `WeightHistorySheet` 空态接上与趋势相同的「去记录」→ 打开今天体重 Sheet。其它已有 CTA 的空态不要叠第二颗按钮。
* 不要「同步 HealthKit」按钮，不要空态里放权限教学长文。
* Dynamic Type / VoiceOver 只补仍渲染的面：
  * 首页莫兰迪方块说明（`module.tapToLog` 等）：用 `.caption` / `.footnote`（或 `@ScaledMetric`），允许最多 2 行，不要固定 11–13pt 截断。
  * `StageGoalCard`：进度条 `accessibilityLabel` 含进度百分比与剩余 kg。
  * 睡眠 / 经期详情里包着 `EaseArcRing` 的摘要卡：`accessibilityLabel` 读时长或周期事实（环本身可 `accessibilityHidden`）。
  * 日历日格在 `dynamicTypeSize.isAccessibilitySize` 时允许体重/涨跌换行或缩小，不要裁成 `…`。
* 不要复活 `TodayStripView` / `ProgressRingView` / `DayPickerHeader` 来「修 a11y」。

## 明确不写进实现（两批合计）

* WidgetKit / App Intent / 锁屏组件 / 从 Widget 拍照。
* 趋势图第二轴、Tooltip 体脂、双指缩放。
* 首页 `ultraThinMaterial`、卡片 drop shadow（含 0.04）。餐图抠图主体层可用轻阴影，不要加到卡片或首页方块。
* `Task.detached` 包 `HealthKitReader` 或 SwiftData。
* 全局 skeleton、庆祝式 haptic、进度 100% 动效、`UIImpactFeedbackGenerator` 叠在已有 `.sensoryFeedback` 上。
* 「一键同步 HealthKit」、空状态里的假同步。
* 导入全量行 diff / 原 CSV 高亮。
* 三餐 `matchedGeometryEffect` Hero。
* 达标日倒计时天数当主数字、精确到日的 ETA 主文案。

## 建议落地顺序（第二批）

1. 软性旬区间文案（改 PRD 口径，焦虑感最大、改动面小）  
2. 三餐单击预览（日历格现有痛点）  
3. 导入 20 条 skipped 样本  
4. 历史空态 CTA + 环/阶段卡/方块 a11y  
5. 日历翻月 `.selection`（可最后、可砍）

Windows 不能 `xcodebuild`。实现后在 Mac 真机测：有图单击预览、无图仍能拍照、导入一张带坏行的 CSV 能看到行号、VoiceOver 读阶段卡与睡眠环、特大字号下首页方块说明不裁成单行省略号。
