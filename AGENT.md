# Role and Persona
You are an expert iOS developer specializing in Swift 5.10 and SwiftUI for iOS 18.
Your goal is to build the "Ease" app based strictly on the provided PRD.
You must strictly follow the Design System defined below. DO NOT use default SwiftUI styling if it conflicts with these rules.

# Technical Constraints
- Frameworks: SwiftUI, HealthKit, SwiftData, Swift Charts, Vision, UserNotifications.
- Architecture: MVVM with `@Observable` macro.
- Platform: iOS 18+, Light Mode ONLY. Units are kg / cm. No in-app language or unit toggle.
- Local First: SwiftData + CloudKit.
- Two models, split by duty:
  - Exactly one `DailyRecord` per local calendar day. Read/write `dietStatus`, `tags`, `note` only.
  - **Keep** `DailyRecord.weight` and `DailyRecord.bodyFat` on the SwiftData schema as `Double?` forever (CloudKit). Never delete these properties, never change them to non-optional, never assign `nil` just to “clean up”. Treat them as legacy read-only snapshots. After v1.1, new weigh-ins never write these fields.
  - `WeightLog`: one row per weigh-in (`id`, `timestamp`, `weight`, `bodyFat?`). Many per day. Insert on save; do not overwrite the day's other logs. No Unique Constraint. No CloudKit `@Relationship` to `DailyRecord`. Runtime source of truth for weight.
  - Startup migrator (idempotent, `UserProfile.hasMigratedWeightLogs`): copy each `DailyRecord` that still has `weight` into a `WeightLog` only if that `dayKey` has no `WeightLog` yet. Leave the old optional fields populated.
- CloudKit conflicts: same `DailyRecord.dayKey` or same `WeightLog.id` → keep the newer `updatedAt`. Multiple `WeightLog`s on one day are valid — never collapse them by date.
  - v1.2 models: `MetricDefinition` + `MetricLog`, split like weight vs day journal. No CloudKit `@Relationship`. No Unique Constraint. Enabled metrics appear in the Metric Sheet; disabled keys stay out of the entry form even if that day has `MetricLog`s. Home **measurements** tile is the daily entry; Settings only toggles definitions + secondary History.
  - `UserProfile.homeModulesRaw` persists which Morandi tiles are on the Weight tab.
- Keep views modularized. Extract reusable UI components (cards, buttons, chart markers, health-detail sheets) into separate files. New `.swift` files must be registered in `Ease.xcodeproj/project.pbxproj`.

# ⚠️ Design System & Visual Guidelines (Strictly Enforced)

## 1. Aesthetic: Milk & Card Minimalist（奶油极简）
Core feel: generous whitespace, soft hierarchy via fill color (not borders/shadows), low-saturation milk/gray card surfaces, high-contrast rounded display numbers, and quiet coral / mint accents for direction feedback.

- **ALLOW**: 4-Tab root (Weight / Trend / Calendar / **Settings**); large hero weight number; stage-goal card with linear progress; customizable Morandi home tiles; segmented trend ranges; black chart tooltip; month calendar with dual-line day cells; weight-history sheet; quiet sleep/period/energy detail tints inside their sheets only.
- **ABSOLUTELY FORBIDDEN**:
    - NO calorie counting, NO macros (carbs/protein/fats), NO calorie goal ring. Diet shortcuts show check-in only — never kcal totals or “热量目标”. Active Energy may show HK kcal as a fact only.
    - NO streak flames, celebration animations, or goal-reached confetti (including “import succeeded” and “you will hit your goal”).
    - NO WHO BMI color bands (green/yellow/red charts). NO BMI judgment labels or status chips (e.g. 偏高 / underweight / overweight). BMI is a **number only**.
    - NO social share buttons, NO in-app language switcher.
    - NO Dark Mode.
    - NO purple-as-brand theme. NO heavy drop shadows as the main depth cue.
    - NO third-party CSV dialects. NO water tracking / water reminder nags.
    - NO Weight-tab trailing gear. NO floating `+` FAB on Weight tab (logging via Weight / Diet tiles or list rows).

## 2. Color Palette
- **Theme**: Light Mode ONLY.
- **App Background**: `#F7F8F9` or `Color(.systemGroupedBackground)`. Global wash behind all tabs.
- **Card Surface (primary)**: `#FFFFFF` — main content cards on the milk background.
- **Card Surface (recessed / nested)**: `#F2F3F5` or `#F5F5F7` — stage-goal strips, metric cells, table headers. Hierarchy via fill, not stroke.
- **Border**: Prefer none. If needed, at most `0.5pt` hairline at `Color.black.opacity(0.06)`.
- **Shadow**: Prefer none. Do not use FAB-style multi-layer shadows on content cards.
- **Primary Accent (loss / positive direction)**: Coral `#FF5252` / `#E53935` — week delta ↓, loss days, progress fill toward target.
- **Secondary Accent (gain / caution)**: Quiet mint / soft green for ↑ gain deltas when contrast is needed; keep saturation low.
- **Primary Text**: Near-black (`Color.primary` / `#111111`). Hero numbers stay high contrast.
- **Secondary Text**: Medium gray (`Color.secondary` / `#8E8E93`).
- **Primary Button**: Capsule, solid black fill, white icon/text.
- **Tooltip**: High-contrast black rounded rectangle, white text (chart point callout).
- **Deprecated**: Vibrant purple progress rings, mint/pink/orange macaron health cards as the home language. Sleep / Period / Energy sheets may keep a quiet tint inside their own sheets only.

## 3. Typography & Icons
- **Primary Font**: SF Pro / 苹方 (system). DO NOT use third-party fonts.
- **Hero Numbers** (home weight, key stats): SF Pro Display, **44pt–56pt**, Regular or Medium, rounded + `.monospacedDigit()`.
  Example: `.font(.system(size: 48, weight: .medium, design: .rounded)).monospacedDigit()`
- **Section Titles**: 17–20pt, Semibold / Medium, black.
- **Supporting / delta lines**: 13–15pt Regular, secondary gray; coral/mint only on the signed delta itself.
- **Table / history cells**: 15pt Regular, monospaced digits for numeric columns.
- **Icons**: STRICTLY single-color `SF Symbols` (`Image(systemName:)`).
  - DO NOT use emojis (NO 🩸, ✈️, 🚽 — use SF Symbols; delta arrows via SF Symbol or consistent localized glyphs).
  - Diet: Clean (`leaf.fill`), Normal (`fork.knife`), Cheat (`takeoutbag.and.cup.and.straw`).
  - Variables: Period (`drop.fill`), Travel (`airplane`), Bowel (`wind`).
  - Tabs: Weight (`scalemass`), Trend (`chart.xyaxis.line`), Calendar (`calendar`), Settings (`gearshape`).
  - Built-in metrics (v1.2): circumferences use `ruler`. No water tracking.
  - Home modules: Morandi squares — BMI, Measurements, Weight, Diet (+ optional Sleep / Period / Energy).

## 4. Screen Layout — 4-Tab Root (match PRD §2)

Root is a **TabView** with four tabs: **Weight / Trend / Calendar / Settings**.
Sheets (weight log, diet log, metrics, weight history, sleep, cycle, energy) remain modal overlays — not extra tabs.

「当天」默认今天；日历选中日可驱动明细。不可选未来日期。

### Tab 1 — 体重 (Dashboard)
1. **Hero**：居中巨幅当前体重（所选日最新 `WeightLog`，否则全局最新）。下方一行小字周增减（如 `▼1.8 kg 本周`），coral on loss / quiet green on gain.
2. **阶段目标卡片**：recessed `#F2F3F5` / `#F5F5F7` rounded card — linear progress bar, start / target weight, optional **basic** pace ETA line (PRD §8.3.A). No purple ring.
3. **可自定义莫兰迪方块**：默认 BMI / 围度 / 体重 / 饮食。可新增睡眠、经期、活动消耗。虚线「添加」打开模块编辑。
4. **体重列表**：默认近 **30** 天；早（太阳）/ 晚（月亮）、相对昨日涨跌、备注。点行编辑。点 **All** → 体重历史 Sheet（全部记录）。**不要**在本页原地折叠展开全部历史。
5. **无 FAB**；无右上角齿轮。

### Tab 2 — 趋势 (Trend)
1. **顶部**：segmented 胶囊 `7天 | 30天 | 90天 | 全部`。
2. **折线**：按日最后一次体重连成主线；X/Y 轴有刻度；目标虚线带文案；拖动黑色 Tooltip。**不显示经期/标签标记。**
3. **数据卡片网格 (3×2)**：最高（含日期）、最低（含日期）、平均、体重变化、距离目标、记录天数。
4. **高级估算卡**（PRD §8.3.B）：体重斜率 + 轻度睡眠/消耗/经期修正；与阶段卡基础 pace 分开展示。

图表交互：预览不改数据；点已有日可编辑体重。删体重不得删当日饮食/标签/备注。

### Tab 3 — 日历 (Calendar)
1. **月历网格**：7 列。每格 — 日号、当日体重、涨跌（`▼0.2` / `▲0.2`）。
2. **周均 / 月均**体重卡（选中日所在周 / 当前浏览月）。
3. **月度统计横栏**：打卡天数、减重天数、增重天数、日均变化、本月变化。
4. **底部明细**：早晚体重、日间波动、饮食打卡。**禁止**卡路里合计或宏量营养素。

### Tab 4 — 设置 (Settings)
Full-tab settings (not a sheet, no Close unless reused as sheet elsewhere).
身高 / 起止体重 / 睡眠目标 / 首页模块 / 通知与提醒时刻 / CSV 导出导入 / 扩展指标开关与 History / 睡眠·经期次级入口 / **两次确认**的清除全部数据。

### Shared Sheets
- **Weight Log Sheet**：可展开图形日历 → 体重 + OCR → 体脂 → 黑 Capsule Save（不含饮食）。
- **Diet Log Sheet**：可展开日历 → 饮食三选一 → 标签 → 备注 → Save（不含体重）。
- **Weight History Sheet**：全部体重日列表（与首页行同构）；点行编辑。
- **Metrics Sheet**：日期 → 已启用围度 → Save → **历史列表**（无围度趋势图）。主入口 = 首页围度格。
- **Sleep / Cycle / Energy Detail**：只读 HealthKit；sheet 内可用安静 tint；Sleep/Energy 图需有轴。
- **Onboarding**：三步不变；奶油底 + 黑 Capsule 主按钮。

## 5. UI Components & Styling

### Cards
- Default fill `#FFFFFF` on `#F7F8F9` background; nested / stage blocks use `#F2F3F5` or `#F5F5F7`.
- **Corner Radius**: cards `16pt–20pt`; capsules / primary buttons `24pt` (full capsule OK).
- **No hard borders**; no heavy shadows on content cards.
- **Padding**: `16–20pt` inside cards; section spacing generous (`24pt+` between major blocks).

### Buttons
- **Primary** (`Save`, `Continue`): Capsule, solid black, white bold text, height 50–56pt, corner ~24pt.
- **No FAB** on Weight tab.
- **Segmented range control**: milk capsule track, selected segment high-contrast — no purple tint.

### Progress
- Prefer **linear** progress in the stage-goal card (coral fill on milk track).
- Formula (from PRD): `(startWeight - displayWeight) / (startWeight - targetWeight)`, clamped `0...1`.
  `displayWeight` = selected day's latest `WeightLog`, else global latest. **Not** the 7-day MA.
- At 100%: show target factually, no celebration.
- Optional gray **basic** pace line under the stage card per PRD §8.3.A.
- Trend **advanced** estimate is a separate card (§8.3.B).

### Charts
- Smooth weight lines: `interpolationMethod(.catmullRom)`.
- Target: dashed rule.
- Selection callout: black rounded tooltip, white text.
- Non-zero Y domain so a single point still renders.
- Quiet but **visible** axes on Trend / Sleep / Energy charts.
- Diet / variable markers: SF Symbols only; not on the Trend weight chart.

## 6. Localization (Strict Requirement)
- NEVER hardcode UI strings.
- All UI text MUST use SwiftUI localization (`Text("Key")` or `String(localized: "...")`).
- Apple String Catalog (`.xcstrings`) for Simplified Chinese and English. English is the base key language.

# Execution Rules
1. ALWAYS wrap primary content in Milk & Card surfaces (`#FFFFFF` / `#F2F3F5` on `#F7F8F9`). No purple brand chrome. No heavy card shadows.
2. Never use default blue buttons; primary actions are black capsules.
3. Do not overcomplicate the code. Provide complete, runnable SwiftUI views without omitting code blocks.
4. If a compiler error is pasted, fix it directly without verbose explanations.
5. When PRD and this file conflict on product rules, PRD wins; this file wins on visual styling.
6. Do not reintroduce "one weight per `DailyRecord`" or "main-card weight = 7-day MA". Those rules are retired as of v1.1.
7. v1.2 is in scope: CSV import, `MetricLog`, basic + advanced pace ETA, reminder time pickers, home modules, Settings as Tab. Do not add water/waist reminder nags, dual-axis charts, third-party CSV dialects, Weight-tab FAB, or a History Tab.
8. Never drop `DailyRecord.weight` / `bodyFat` from the schema. Never nil them after copying to `WeightLog`. Weight writes go only to `WeightLog`.
9. Root navigation is Weight / Trend / Calendar / Settings. Do not collapse back into a single scrolling dashboard without tabs. Do not resurrect History as a fourth tab unless the PRD changes again.
