# Ease 体感与流畅度

对照现有 **SwiftUI + SwiftData + HealthKit**、`PRD.md` / `AGENT.md`，以及 4-Tab 路径上已经落地的交互。原则：安静账本。体感来自确认反馈、少一次磁盘读、数字会走位，不靠玻璃拟态、弹跳和彩蛋。

第一、二批（缩略图缓存、HK TTL、图表钉住、Sheet detents、numericText、OCR haptic、经期微 tint、旬区间文案、导入 skipped 样本、历史空态 CTA、日历翻月 `.selection`）**已落地**。饮食录入 UI 已从 4-Tab 拿掉（schema / CSV 列仍保留）。下面按**当前代码**写可执行规格；拒绝项不改产品边界。

## 当前已落地

### 1. 四 Tab 版式

Weight / Trend / Calendar / Settings 共用 `EaseLayout`：左右 16pt、块间距 16pt、指标网格 12pt、滚动底 inset 100pt。四个页都用系统 Large Title（Weight 用 `tab.weight`，不要居中 “Ease”）。设置页保持 inset-grouped，不要 Done。

### 2. 触觉（确认，不是庆祝）

只在「系统已经认定一次结果」时触发：

* `ScaleOCR` 解析出合法体重/体脂 → `.success`（失败保持 `.error`）。
* 保存体重成功 → `.success`（`saveSuccessPulse`）。
* 滑动或上下文菜单删除 `WeightLog` → `.warning`。
* 日历 Tab 换月、趋势图按日 scrub、区间切换 → `.selection`（同一天不连震）。

禁止：点 Tab、点莫兰迪方块、拖图表每像素、进度到 100%。不要在已有 `.sensoryFeedback` 上再叠 `UIImpactFeedbackGenerator`。饮食芯片触觉已随饮食 UI 移除，不要加回来。

### 3. 趋势图 scrub（单轴体重）

* 拖动：竖线 `RuleMark` + 黑胶囊。胶囊用 `chartOverlay` 按点定位，**不要** `chartPlotStyle` 顶 padding。
* Tooltip：日期、当日最后一次体重；若该日有 7 日均线，secondary 附一行。不要体脂、不要经期点。竖线 X 用该日最后一次称重时刻。
* 松手后读数钉住到下一次拖动或点空白。拖动不得打开体重 Sheet。点已有日（位移 &lt; 8pt）才打开 Sheet，并立刻清掉选择。体重 / 均线 / 目标共用同一个 Y 编码名。

### 4. HealthKit / 估算：缓存，不 detached

* `HealthKitReader.loadAll` 保持 async；结果带时间戳缓存在 `DashboardViewModel`。前台且未过期（约 60s）则跳过全量查询。
* Sheet 关闭、切 Tab **不要**无条件 `reloadHealthAndNotifications`。改体重后只重排通知；HK 用缓存。
* `AdvancedPaceEstimator` 在 Trend 出现时算。禁止 `Task.detached` 碰 `ModelContext`。
* 睡眠/经期/消耗 Sheet：缓存未就绪时 `.redacted` + 淡入。体重 Tab 本地数字不要骨架。

### 5. 数字过渡

白名单：`WeightHeroView` 体重、首页 BMI、阶段卡剩余 kg。趋势统计数字可用 `.numericText()`。无数字的「—」不要套。高级估算主行是旬区间，**天数不是主数字**。禁止进度条弹跳、卡片缩放。

### 6. 录入 / 详情 Sheet

体重、围度、BMI、Sleep、Cycle、Energy、日历日明细、导入预览：`.easeSheetPresentation()`（medium/large、可见拖条、内容可滚）。动画走系统 sheet spring。关闭用系统关闭控件，不要让「关闭」在 leading 折行。

Sleep / Energy 日柱与 Cycle 时间轴：横向 `chartScrollableAxes`，约 7 天（经期约 14 天）清楚可见，默认停在最近日期。

`CycleDetailSheet` 摘要卡可用低饱和粉细条，不是全屏渐变，不是首页方块换皮。

### 7. 软性达标区间

内部仍算精确 `eta` / `daysRemaining`。UI 共用旬桶：1–10 上旬、11–20 中旬、21–月末下旬；英文 `early / mid / late {Month}`。距今 ≤7 天用「本周内」/ `later this week`。阶段卡与高级卡都不要具体日号、不要「还有 N 天」。

### 8. 导入 skipped 样本

`CSVImporter.Preview.skippedSamples` 封顶 20：行号（表头第 1 行）+ invalid/duplicate + 原因 key。`ImportPreviewSheet` 用 `DisclosureGroup` 展开。禁止整表 diff。

### 9. 空状态与无障碍

* `WeightHistorySheet` 空态「去记录」→ 今天体重 Sheet。已有 CTA 的空态不要叠第二颗按钮。禁止「同步 HealthKit」。
* 首页方块说明最多 2 行，不要固定 11–13pt 截成 `…`。
* `StageGoalCard` 进度条 `accessibilityLabel` 含百分比与剩余 kg。
* 睡眠 / 经期环所在卡读时长或周期事实；环本身 `accessibilityHidden`。

### 10. 日历（近期落地）

* 月份选择器 `safeAreaInset` 钉在 Large Title 下，奶油底，不裁进状态栏。
* Overview：上行月均 + 净变化；发丝分割；下行四等宽列（周均 / 打卡 / 减重 / 增重）。`HStack` + `.frame(maxWidth: .infinity)`，禁止 `LazyVGrid` 三列把第四项挤成孤儿行。
* 星期头 `.caption.weight(.semibold)` + `.secondary`。未来日 `.tertiary`，不要再叠 0.3 opacity。
* 今天 / 选中：`EasePalette.accent.opacity(0.15)` 填 + 1.5pt 细环；日号主色或珊瑚，不是白字实心红圆。
* 格内体重 `.caption2.monospacedDigit()` + `.primary`；涨跌箭头 secondary、数值可走 semanticDelta。格子固定高度，避免行高跳动。

### 11. 设置（近期落地）

* 去掉 List 级 `.tint(EasePalette.coral)`。Toggle 用 `Color(.systemGreen)`；Export/Import 主色；性别/生日/时刻 `.secondary`；仅 Delete 为 destructive。
* 提醒总开关关闭：`withAnimation(.easeInOut(duration: 0.2))` 收起体重时刻行，`.disabled` + `.opacity(0.5)`。
* 扩展指标：`waist` / `hip` / `chest` / `thigh` / `underbust` 置顶；其余 + 自定义 +「添加指标」进 `settings.metrics.more`。区头 `settings.metrics.enabled_count`。
* Import 就是一行 `Button` + `Label`，不要 trailing `(i)` 叠在「CSV」上。说明进 `settings.import.footer`。
* History chevron：`.buttonStyle(.borderless)`，点 History 不拨 Toggle。左滑仍可打开 History。

### 12. 文案

禁止间隔号「·」（U+00B7）。并列用逗号、顿号或拆句。

## 明确不写进实现

* WidgetKit / App Intent / 锁屏组件 / 从 Widget 拍照。
* 趋势图第二轴、Tooltip 体脂、双指缩放。
* 首页 `ultraThinMaterial`、卡片 drop shadow（含 0.04）。
* `Task.detached` 包 `HealthKitReader` 或 SwiftData。
* 全局 skeleton、庆祝式 haptic、进度 100% 动效。
* 「一键同步 HealthKit」、空状态里的假同步。
* 导入全量行 diff / 原 CSV 高亮。
* 达标日倒计时天数当主数字、精确到日的 ETA 主文案。
* 饮食打卡 / 餐图录入 / 饮食提醒（`DailyRecord` 相关字段与 CSV 列保留；UI 不再写）。
* 设置页珊瑚全局 tint、Import 行上叠 info 图标、实心珊瑚「今天」圆。
* 为扩展指标、饮水做催打卡通知。

## 不在 4-Tab 路径上（不要复活来「补功能」）

`HistoryTabView`、`DayPickerHeader`、`TodayStripView`、`ProgressRingView`、`DailyMomentsCard` / `FoodJournalSheet`、`MealPhotoCarousel`。餐图 `NSCache` 与 sidecar 清理逻辑可留着给 `resetAll` / CSV 遗留文件，但日历格和体重 Sheet **不要**再接餐图 UI。

Windows 不能 `xcodebuild`。Mac 真机抽查：日历 Overview 无孤儿行、今天细环可认、设置 Toggle 为系统绿、提醒关闭后时刻行变淡、Import 行无重叠图标、趋势拖读数钉住、VoiceOver 读阶段卡与睡眠环。
