# Ease 体感与流畅度

对照现有 **SwiftUI + SwiftData + HealthKit**、`PRD.md` / `AGENT.md`，以及 4-Tab 路径上已经落地的交互。原则：安静账本。体感来自确认反馈、少一次磁盘读、数字会走位，不靠玻璃拟态、弹跳和彩蛋。

饮食录入 UI 已从 4-Tab 拿掉（schema / CSV 列仍保留）。下面按**当前代码**写可执行规格；拒绝项不改产品边界。文档与已上线 UI 对齐，不要把旧的 2+4 Overview 或「再点开日明细 Sheet」写回去。

## 当前已落地

### 1. 四 Tab 版式

Weight / Trend / Calendar / Settings 共用 `EaseLayout`：左右 16pt、块间距 16pt、指标网格 12pt、滚动底 inset 100pt。四个页都用系统 Large Title（Weight 用 `tab.weight`，不要居中 “Ease”）。设置页保持 inset-grouped，不要 Done。

**Weight Tab 滚动**：主内容用 **edge-to-edge `ScrollView`**，水平 16pt 只加在内部 `easeTabScrollContent()`，勿给 `ScrollView` 包 horizontal padding（滚动条贴右缘）。

**主查询窗口**（`MainTabView`）：`DailyRecord` 180 天，`WeightLog` / `MetricLog` 365 天。设置 CSV 用完整 fetch，不要用 Tab 窗口截断导出。

### 2. 触觉（确认，不是庆祝）

只在「系统已经认定一次结果」时触发：

* `ScaleOCR` 解析出合法体重/体脂 → `.success`（失败保持 `.error`）。
* 保存体重成功 → `.success`（`saveSuccessPulse`）。
* 滑动或上下文菜单删除 `WeightLog` → `.warning`。
* 日历 Tab 换月、选中日变化、趋势图按日 scrub、区间切换、阶段卡点按 → `.selection`（同一天不连震）。

禁止：点 Tab、点莫兰迪方块、拖图表每像素、进度到 100%。不要在已有 `.sensoryFeedback` 上再叠 `UIImpactFeedbackGenerator`。饮食芯片触觉已随饮食 UI 移除，不要加回来。

### 3. 趋势图 scrub（单轴体重）

* 拖动：竖线 `RuleMark` + 黑胶囊。胶囊用 `chartOverlay` 按点定位，**不要** `chartPlotStyle` 顶 padding。
* Tooltip：日期、当日最后一次体重；若该日有 7 日均线，secondary 附一行。不要体脂、不要经期点。竖线 X 用该日最后一次称重时刻。
* X 位移小于 **2pt** 不更新 scrub（`scrubMinDeltaX`）。
* 松手后读数钉住到下一次拖动或点空白。拖动不得打开体重 Sheet。点已有日（位移 &lt; 8pt）才打开 Sheet，并立刻清掉选择。体重 / 均线 / 目标共用同一个 Y 编码名。

### 4. HealthKit / 估算：缓存，不 detached

* `HealthKitReader.loadAll` 保持 async；结果带时间戳缓存在 `DashboardViewModel`。前台且未过期（**TTL 300s**，`HealthKitCachePolicy`）则跳过全量查询。
* Sheet 关闭、切 Tab **不要**无条件 `reloadHealthAndNotifications`。改体重后只重排通知；HK 用缓存。
* `AdvancedPaceEstimator` / `HealthInsightEngine` 在 Trend 出现时算（`analysisComputeToken` 与图表 range 分离，切 7/30/90 不重算洞察）。禁止 `Task.detached` 碰 `ModelContext`。
* 睡眠/经期/消耗 Sheet：缓存未就绪时 `.redacted` + 淡入。体重 Tab 本地数字不要骨架。

### 5. 数字过渡

白名单：`WeightHeroView` 体重、首页 BMI、阶段卡剩余 kg。趋势统计数字可用 `.numericText()`。无数字的「—」不要套。Weight Forecast 主行是旬区间，**天数不是主数字**。禁止进度条弹跳、卡片缩放。

### 6. 录入 / 详情 Sheet

体重、围度、BMI、Sleep、Cycle、Energy、导入预览、**Weight Forecast 详情**、**Lifestyle Insight 详情**：`.easeSheetPresentation()`（medium/large、可见拖条、内容可滚）。动画走系统 sheet spring。

**体重 / 围度录入**（`LogSheetView` / `MetricSheet`）：
* **Save** 在导航栏 **trailing**（`EaseToolbarSaveButton`），禁用 secondary 40%、启用 `morandiRed` 字色；**无底部 Save 胶囊、无 `.ultraThinMaterial` 吸底条。**
* **Close** 为 **`xmark.circle.fill`**（`EaseCloseToolbarButton`），勿用文字胶囊 Close。
* Save / 关闭 / Delete 前先 **`@FocusState` 清焦点 + `EaseKeyboard.dismiss`**；体重 Sheet 成功保存后 **~80ms** 再 `dismiss`，避免键盘与 Sheet 动画打架。
* `ScrollView` / `List` 加 `.scrollDismissesKeyboard(.interactively)`；背景点按收键盘。

其它 Sheet 关闭控件可与上保持一致或沿用各页现有样式；不要让 leading 关闭文案折行。

Sleep / Energy 日柱与 Cycle 时间轴：横向 `chartScrollableAxes`，约 7 天（经期约 14 天）清楚可见，默认停在最近日期。

`CycleDetailSheet` 摘要卡可用低饱和粉细条，不是全屏渐变，不是首页方块换皮。

### 7. 软性达标区间

内部仍算精确 `eta` / `daysRemaining`。UI 共用旬桶：1–10 上旬、11–20 中旬、21–月末下旬；英文 `early / mid / late {Month}`。距今 ≤7 天用「本周内」/ `later this week`。阶段卡与 Weight Forecast 都不要具体日号、不要「还有 N 天」。

### 8. 导入 skipped 样本

`CSVImporter.Preview.skippedSamples` 封顶 20：行号（表头第 1 行）+ invalid/duplicate + 原因 key。`ImportPreviewSheet` 用 `DisclosureGroup` 展开。禁止整表 diff。

### 9. 空状态与无障碍

* `WeightHistorySheet` 空态「去记录」→ 今天体重 Sheet。Trend 无称重走 `EaseEmptyState` CTA。已有 CTA 的空态不要叠第二颗按钮。禁止「同步 HealthKit」。
* 首页方块说明最多 2 行，不要固定 11–13pt 截成 `…`。
* `StageGoalCard` 进度条 `accessibilityLabel` 含百分比与剩余 kg。进度条 16pt、无 tooltip/thumb；填充为矩形宽比例 + 外层 Capsule 裁剪。
* 睡眠 / 经期 / Overview 打卡环：环本身 `accessibilityHidden` 或把事实放在 enclosing 的 `accessibilityLabel`。

### 10. 日历（当前 UI）

* 月份选择器在 **ScrollView 内容顶部**（`CalendarMonthHeader`），奶油底，不是 `safeAreaInset` 钉栏。不可翻到未来月。
* 月历格：日号 + 色点（体重 / 经期 / 睡眠）+ 体重数字。**格内无涨跌。** 动态字号格子约 64 / 92pt。
* 今天未选中：`EasePalette.accent.opacity(0.12)` 日号圆填；选中：1.5pt 珊瑚细环。不是白字实心红圆。
* 点格只选中日期。选中日后的 **Daily Snapshot** 点整卡打开体重 Sheet；无记录则虚线 CTA。消耗格图标 `flame.fill`，填色 `HomeModule.energy.fill`。
* **Overview**：等宽两列净变化 + Logged days 圆环；footer 月均 / 周均（`secondarySystemFill`，无垂直 `Divider`）。标签 `.caption` + `primary.opacity(0.8)`；净变化 / 圆环数字 rounded title2 bold。**不要**改回「月均+净变化 / 四列打卡减重增重」。
* `CalendarPremiumPanel`：白底、0.04 描边、轻阴影；Overview `contentInset` 16。

### 11. 趋势分析卡（当前 UI）

* `TrendPremiumCard`：白底、0.04 描边、轻阴影、内边距 24。
* Weight Forecast / Lifestyle Insights **行背景透明**。禁止再给行动行加莫兰迪或灰色色块。
* 可点暗示：整行 `Button` + `TrendCardRowButtonStyle`（仅 `isPressed` 时 `primary.opacity(0.06)`）+ `.tertiary` chevron。
* 左文案 `.secondary`，右核心数据 `.primary` + `.semibold`。
* Sleep / Energy 详情底部仍可用 `HealthInsightNoteCard`（与趋势主卡行样式不同，保持即可）。

### 12. 设置（当前 UI）

* 去掉 List 级 `.tint(EasePalette.coral)`。Toggle 用 `Color(.systemGreen)`；Export/Import 主色；性别/生日/时刻 `.secondary`；仅 Delete 为 destructive。
* 提醒总开关关闭：`withAnimation(.easeInOut(duration: 0.2))` 收起体重时刻行，`.disabled` + `.opacity(0.5)`。
* 扩展指标：设置里五条核心 key 仍置顶（`waist`/`hip`/`chest`/`thigh`/`underbust`）；围度 **Sheet 内**按 Core/Limbs/Other **解剖序** 展示。行图标 **`EaseMetricIcon`** 32×32 燕麦底。其余 + 自定义 +「添加指标」进 `settings.metrics.more`。
* Import 就是一行 `Button` + `Label`，不要 trailing `(i)` 叠在「CSV」上。说明进 `settings.import.footer`。
* History chevron：`.buttonStyle(.borderless)`，点 History 不拨 Toggle。左滑仍可打开 History。

### 13. 文案

禁止间隔号「·」（U+00B7）。并列用逗号、顿号或拆句。趋势卡英文标题：Weight Forecast、Lifestyle Insights。

## 明确不写进实现

* WidgetKit / App Intent / 锁屏组件 / 从 Widget 拍照。
* 趋势图第二轴、Tooltip 体脂、双指缩放。
* 首页与录入 Sheet 底部 **`ultraThinMaterial` 吸底 Save 条**。不要加重 Trend/Calendar 已有轻阴影。
* Trend Forecast / Insights **行内静态色块**（含莫兰迪 fill）。
* `Task.detached` 包 `HealthKitReader` 或 SwiftData。
* 全局 skeleton、庆祝式 haptic、进度 100% 动效。
* 「一键同步 HealthKit」、空状态里的假同步。
* 导入全量行 diff / 原 CSV 高亮。
* 达标日倒计时天数当主数字、精确到日的 ETA 主文案。
* 饮食打卡 / 餐图录入 / 饮食提醒（`DailyRecord` 相关字段与 CSV 列保留；UI 不再写）。
* 设置页珊瑚全局 tint、Import 行上叠 info 图标、实心珊瑚「今天」圆。
* 为扩展指标、饮水做催打卡通知。
* 把日历 Overview 改回四列减重/增重天数，或把 `CalendarDayDetailSheet` 接回主路径。

## 不在 4-Tab 路径上（不要复活来「补功能」）

`HistoryTabView`、`DayPickerHeader`、`TodayStripView`、`ProgressRingView`、`DailyMomentsCard` / `FoodJournalSheet`、`MealPhotoCarousel`、`CalendarDayDetailSheet`。餐图 `NSCache` 与 sidecar 清理逻辑可留着给 `resetAll` / CSV 遗留文件，但日历格和体重 Sheet **不要**再接餐图 UI。

Windows 不能 `xcodebuild`。Mac 真机抽查：日历 Overview 两列+footer 对齐、今天细环可认、Snapshot 莫兰迪格、设置 Toggle 为系统绿、提醒关闭后时刻行变淡、Import 行无重叠图标、趋势拖读数钉住、Forecast/Insights 行无色块、VoiceOver 读阶段卡与睡眠环。
