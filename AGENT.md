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
  - v1.2 models: `MetricDefinition` + `MetricLog`, split like weight vs day journal. No CloudKit `@Relationship`. No Unique Constraint. Enabled metrics may appear in Weight-tab shortcuts / sheets; disabled keys stay out of home surfaces even if that day has `MetricLog`s.
- Keep views modularized. Extract reusable UI components (cards, buttons, chart markers, day picker, health-detail sheets) into separate files.

# ⚠️ Design System & Visual Guidelines (Strictly Enforced)

## 1. Aesthetic: Milk & Card Minimalist（奶油极简）
Core feel: generous whitespace, soft hierarchy via fill color (not borders/shadows), low-saturation milk/gray card surfaces, high-contrast rounded display numbers, and quiet coral / mint accents for direction feedback.

- **ALLOW**: 4-Tab root navigation; large hero weight number; stage-goal card with linear progress; 2×2 health grid; segmented trend ranges; black chart tooltip; month calendar with dual-line day cells; history table; black FAB.
- **ABSOLUTELY FORBIDDEN**:
    - NO calorie counting, NO macros (carbs/protein/fats), NO calorie goal ring. Diet shortcuts show check-in / photo only — never kcal totals or “热量目标”.
    - NO streak flames, celebration animations, or goal-reached confetti (including “import succeeded” and “you will hit your goal”).
    - NO WHO BMI color bands (green/yellow/red charts). NO BMI judgment labels or status chips (e.g. 偏高 / underweight / overweight). BMI is a **number only**.
    - NO social share buttons, NO in-app language switcher.
    - NO Dark Mode.
    - NO purple-as-brand theme. NO heavy drop shadows as the main depth cue.
    - NO third-party CSV dialects. NO water/waist reminder nags in v1.2.

## 2. Color Palette
- **Theme**: Light Mode ONLY.
- **App Background**: `#F7F8F9` or `Color(.systemGroupedBackground)`. Global wash behind all tabs.
- **Card Surface (primary)**: `#FFFFFF` — main content cards on the milk background.
- **Card Surface (recessed / nested)**: `#F2F3F5` or `#F5F5F7` — stage-goal strips, metric cells, table headers. Hierarchy via fill, not stroke.
- **Border**: Prefer none. If needed, at most `0.5pt` hairline at `Color.black.opacity(0.06)`.
- **Shadow**: Prefer none. If a floating control needs lift (FAB only), use an extremely soft shadow — never stacked multi-layer card shadows.
- **Primary Accent (loss / positive direction)**: Coral `#FF5252` / `#E53935` — week delta ↓, loss days, progress fill toward target.
- **Secondary Accent (gain / caution)**: Quiet mint / soft green for ↑ gain deltas when contrast is needed; keep saturation low.
- **Primary Text**: Near-black (`Color.primary` / `#111111`). Hero numbers stay high contrast.
- **Secondary Text**: Medium gray (`Color.secondary` / `#8E8E93`).
- **Primary Button / FAB**: Solid black fill, white icon/text.
- **Tooltip**: High-contrast black rounded rectangle, white text (chart point callout).
- **Deprecated**: Vibrant purple progress rings, mint/pink/orange macaron health cards as the home language. Sleep / Period sheets may keep a quiet tint inside their own sheets only.

## 3. Typography & Icons
- **Primary Font**: SF Pro / 苹方 (system). DO NOT use third-party fonts.
- **Hero Numbers** (home weight, key stats): SF Pro Display, **44pt–56pt**, Regular or Medium, rounded + `.monospacedDigit()`.
  Example: `.font(.system(size: 48, weight: .medium, design: .rounded)).monospacedDigit()`
- **Section Titles**: 17–20pt, Semibold / Medium, black.
- **Supporting / delta lines**: 13–15pt Regular, secondary gray; coral/mint only on the signed delta itself.
- **Table / history cells**: 15pt Regular, monospaced digits for numeric columns.
- **Icons**: STRICTLY single-color `SF Symbols` (`Image(systemName:)`).
  - DO NOT use emojis (NO 🩸, ✈️, 🚽, ▼ as emoji — use SF Symbol `arrow.down` / text `▼` consistently via localized string if needed).
  - Diet: Clean (`leaf.fill`), Normal (`fork.knife`), Cheat (`takeoutbag.and.cup.and.straw`).
  - Variables: Period (`drop.fill`), Travel (`airplane`), Bowel (`wind`).
  - Tabs: Weight (`scalemass` / `house`), Trend (`chart.xyaxis.line`), Calendar (`calendar`), History (`list.bullet`).
  - Built-in metrics (v1.2): circumferences use `ruler`; water `drop` (not `drop.fill`, which is period).

## 4. Screen Layout — 4-Tab Root (match PRD §2)

Root is a **TabView** with four tabs. Sheets (log, metrics, settings, sleep, cycle) remain modal overlays — not fifth tabs.

「当天」默认今天；日历 / 历史选中日可驱动明细。不可选未来日期。

### Tab 1 — 体重 (Dashboard)
1. **Hero**：居中巨幅当前体重（所选日最新 `WeightLog`，否则全局最新）。下方一行小字周增减（如 `▼1.8 kg 本周`），coral on loss / quiet green on gain.
2. **阶段目标卡片**：recessed `#F2F3F5` / `#F5F5F7` rounded card — linear progress bar, start weight, remaining days (or pace ETA when available), target weight. No purple ring.
3. **双列健康网格 (2×2)**：至少 BMI（number only）与体脂率；其余两格可为饮水 / 围度入口或已启用扩展指标。无数据时隐藏格子或整行，不画占位「—」硬凑。
4. **底部快捷打卡**：喝水、饮食两张平行卡片，带 `+` 快捷。右下角 **黑色圆形 FAB** 打开日更录入 Sheet（所选日）。围度仍走独立 Metrics Sheet。

Sleep / Period / Active Energy：不再作为首页马卡龙主卡；有需要时从设置或次级入口进既有 Detail Sheet。

### Tab 2 — 趋势 (Trend)
1. **顶部**：segmented 胶囊 `7天 | 30天 | 90天 | 全部`（X 范围；7 日均线窗口不变）。
2. **平滑折线**：Catmull-Rom；目标体重虚线；点弱化、均线清晰。点击/拖动弹出 **黑色 Tooltip**（如 `6/18  61.8 kg`）。
3. **数据卡片网格 (2×3)**：最高、最低、平均、体重变化、距离目标、记录天数 — recessed milk cells, large monospaced numbers.

图表交互：预览不改数据；点已有 `WeightLog` 可编辑该条。删体重不得删当日饮食/标签/备注。

### Tab 3 — 日历 (Calendar)
1. **月历网格**：7 列。每格双行 — 上行当日体重，下行涨跌（`▼0.2` / `▲0.2`），coral/mint on signed delta.
2. **月度统计横栏**：5 列浅色整栏 — 打卡天数、减重天数、增重天数、日均变化、本月变化。
3. **底部明细**：选中日后展开早晚体重、早晚差、饮食打卡（icon / 可选照片）。**禁止**卡路里合计或宏量营养素。

### Tab 4 — 历史 (History)
1. **表头**：灰色横条 — `日期 | 早 | 晚 | 日间波动 | 夜间代谢`。
   - 日间波动 = 同日晚−早；夜间代谢 = 前晚−今早。缺数据则空。
2. **列表**：单行极简文字表；长按或侧滑编辑/删除对应 `WeightLog`（或当日记录，按现有数据规则）。

### Shared Sheets (unchanged product rules, restyled to milk cards)
- **Log Sheet**：日期 → 体重 + OCR → 体脂 → 饮食三选一 → 标签 → 备注 → 黑色 Capsule Save.
- **Metrics Sheet**：日期 → 已启用指标 → Save → 历史。
- **Settings**：身高 / 起止体重 / 睡眠目标 / 通知 / CSV / 扩展指标；入口放体重 Tab 导航栏 trailing。
- **Sleep / Cycle Detail**：仍为 Sheet；仅 sheet 内可用安静 tint。
- **Onboarding**：三步不变；视觉跟随奶油底 + 黑 Capsule 主按钮。

## 5. UI Components & Styling

### Cards
- Default fill `#FFFFFF` on `#F7F8F9` background; nested / stage blocks use `#F2F3F5` or `#F5F5F7`.
- **Corner Radius**: cards `16pt–20pt`; capsules / primary buttons `24pt` (full capsule OK).
- **No hard borders**; no heavy shadows on content cards.
- **Padding**: `16–20pt` inside cards; section spacing generous (`24pt+` between major blocks).

### Buttons
- **Primary** (`Save`, `Continue`): Capsule, solid black, white bold text, height 50–56pt, corner ~24pt.
- **FAB**: Circle, **solid black** fill, white `+`, sits above Home Indicator on Weight tab (and anywhere logging is primary).
- **Segmented range control**: milk capsule track, selected segment white or near-black text per iOS segmented clarity — no purple tint.

### Progress
- Prefer **linear** progress in the stage-goal card (coral fill on milk track).
- Formula (from PRD): `(startWeight - displayWeight) / (startWeight - targetWeight)`, clamped `0...1`.
  `displayWeight` = selected day's latest `WeightLog`, else global latest. **Not** the 7-day MA.
- At 100%: show target factually, no celebration.
- Optional gray pace line under the stage card (`At this pace, around 12 Oct 2026.`) per PRD §8.3.

### Charts
- Smooth weight lines: `interpolationMethod(.catmullRom)`.
- Target: dashed rule.
- Selection callout: black rounded tooltip, white text.
- Non-zero Y domain so a single point still renders.
- Quiet axes; hide clutter when readable.
- Diet / variable markers: SF Symbols only.

## 6. Localization (Strict Requirement)
- NEVER hardcode UI strings.
- All UI text MUST use SwiftUI localization (`Text("Key")` or `String(localized: "...")`).
- Apple String Catalog (`.xcstrings`) for Simplified Chinese and English. English is the base key language.

# Execution Rules
1. ALWAYS wrap primary content in Milk & Card surfaces (`#FFFFFF` / `#F2F3F5` on `#F7F8F9`). No purple brand chrome. No heavy card shadows.
2. Never use default blue buttons; primary actions are black capsules / black FAB.
3. Do not overcomplicate the code. Provide complete, runnable SwiftUI views without omitting code blocks.
4. If a compiler error is pasted, fix it directly without verbose explanations.
5. When PRD and this file conflict on product rules, PRD wins; this file wins on visual styling.
6. Do not reintroduce "one weight per `DailyRecord`" or "main-card weight = 7-day MA". Those rules are retired as of v1.1.
7. v1.2 is in scope: CSV import, `MetricLog`, pace-ETA, and reminder time pickers follow PRD §8. Do not add water/waist reminder nags, dual-axis charts, or third-party CSV dialects.
8. Never drop `DailyRecord.weight` / `bodyFat` from the schema. Never nil them after copying to `WeightLog`. Weight writes go only to `WeightLog`.
9. Root navigation is the 4-Tab structure in §4. Do not collapse back into a single scrolling dashboard without tabs.
