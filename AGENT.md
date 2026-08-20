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
  - v1.2 models: `MetricDefinition` + `MetricLog`, split like weight vs day journal. No CloudKit `@Relationship`. No Unique Constraint. Dashboard gray metric line shows only `isEnabled` metrics; disabled keys stay out of the home card even if that day has `MetricLog`s.
- Keep views modularized. Extract reusable UI components (cards, buttons, chart markers, day picker, health-detail sheets) into separate files.

# ⚠️ Design System & Visual Guidelines (Strictly Enforced)

## 1. Aesthetic Override & Non-Goals
The UI must replicate a clean, modern, soft-shadowed card aesthetic with generous spacing and high contrast.
- **ALLOW**: Weight goal circular progress ring; BMI shown as a **number only** (e.g. `BMI 21.4`); sleep-target ring on the Sleep sheet; tinted health cards (mint / pink / orange).
- **ABSOLUTELY FORBIDDEN**:
    - NO calorie counting, NO macros (carbs/protein/fats), NO calorie goal ring.
    - NO streak flames, celebration animations, or goal-reached confetti (including “import succeeded” and “you will hit your goal”).
    - NO BMI WHO color bands or labels like underweight / normal / overweight.
    - NO social share buttons, NO in-app language switcher.
    - NO Dark Mode.
    - NO Tab bar.
    - NO third-party CSV dialects. NO water/waist reminder nags in v1.2.

## 2. Color Palette
- **Theme**: Light Mode ONLY.
- **App Background**: Very light gray / off-white (`Color(UIColor.secondarySystemBackground)` or `#F6F6F8`). DO NOT use pure white for the main screen background.
- **Card Surface (default)**: Pure White (`Color.white`) for weight, BMI, progress, chart, log, settings.
- **Semantic card tints** (health cards only; pastel fill, never loud):
    - Sleep: mint / teal wash (e.g. `#D8F3EE` or equivalent).
    - Period: pink wash (e.g. `#F8DDE6` or equivalent).
    - Active Energy: warm orange wash (e.g. `#FBE4D0` or equivalent). Orange is a **surface tint for the energy readout card only** — never for streaks or diet judgment.
- **Primary Accent**: Vibrant Purple (weight progress rings, Day Picker selection, active states, FAB border/icon).
- **Secondary Accent**: Soft Gray.
- **Primary Text**: Pure Black (`Color.black`) even on tinted cards.
- **Secondary Text**: Medium Gray (`Color.gray`).
- **Primary Button Background**: Solid Black (`Color.black`).

## 3. Typography & Icons
- **Primary Font**: iOS System Font (SF Pro). DO NOT use third-party fonts.
- **Numbers (Weight, BMI, Remaining kg, sleep duration)**:
  Rounded + monospaced digits to prevent layout jumping.
  Example: `.font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()`
- **Text Hierarchy**: High-emphasis `Color.black` + `.bold`; low-emphasis `Color.gray` + `.regular`.
- **Icons**: STRICTLY single-color `SF Symbols` (`Image(systemName:)`).
  - DO NOT use emojis (NO 🩸, ✈️, 🚽).
  - Diet: Clean (`leaf.fill`), Normal (`fork.knife`), Cheat (`takeoutbag.and.cup.and.straw`).
  - Variables: Period (`drop.fill`), Travel (`airplane`), Bowel (`wind`).
  - Sleep card: `moon.fill`. Energy card: `bolt.fill`.
  - Built-in metrics (v1.2): circumferences use `ruler`; water `drop` (not `drop.fill`, which is period).

## 4. Screen Layout (match PRD §2)

### Dashboard (single scrolling page, no Tab bar)
Top → bottom, this order is mandatory:
1. Nav: title `Ease` + trailing settings button.
2. Day Picker Header (week / month). Selected day drives the ring, health cards, weight card, FAB, and the metrics sheet default date. No future dates.
3. Purple weight-goal progress ring (already lost kg / remaining kg). At 100%, show `Target X.X kg` with no celebration. Clamp progress to 0...1.
   v1.2: optional gray pace line under the ring (`At this pace, around 12 Oct 2026.`). Hide per PRD §8.3 (incl. MAD filter then OLS, and all hide-guards). Never a countdown badge.
4. Semantic health cards (hide any card with no permission or no data — no placeholder dashes):
   - Sleep (mint) → Sleep Detail Sheet.
   - Period (pink) → Cycle Detail Sheet.
   - Active Energy (orange) → display only, not tappable into a calorie goal.
   Diet pending/selected and travel/bowel icons stay neutral, not tinted.
5. Main card: large **selected-day latest** `WeightLog` weight; optional body fat on a secondary line; `BMI 21.4` as a number only. If that day has no log, fall back to the global latest weight.
   v1.2: one extra gray line when any metric is enabled. Readings only for enabled metrics that have a log that day; otherwise a quiet `Measurements` entry. Tap opens the metrics sheet, not the daily log. Disabled metrics never appear in the readings, even if logs exist. No extra macaron cards for waist/water.
6. Chart card: `7 / 30 / 90` segmented control (X range only; MA window stays 7 calendar days). Plot **every** `WeightLog` in range. De-emphasize individual points; highlight 7-day MA (last weigh-in per calendar day). SF Symbol markers on days. A row of last-7-day diet icons under the chart. If fewer than 7 calendar days have a weight, draw points/line only — **no MA**. Do not overlay gray HealthKit sleep/energy bars on this chart.
7. FAB `+` above the Home Indicator; opens the **daily** log sheet (weight / diet / tags / note) for the **selected day**. Circumferences use a separate metrics sheet from the weight-card gray line.

Chart: drag to preview a point; tap an existing `WeightLog` point to edit **that log**. Backfill via the sheet, not by tapping empty chart space. Deleting a weigh-in must not delete that day's diet/tags/note.

### Log Sheet
Date picker (default selected day, no future dates) → weight + in-row photo OCR → optional body fat → diet triple toggle → multi-select variable tags → optional note → black Capsule Save.
- New weight **inserts** a `WeightLog`.
- Opening from a chart point edits that `WeightLog` (de-emphasized Delete removes only that log).
- Diet/tags/note field-merge into that day's `DailyRecord`.
- Metrics are **not** on this sheet.
OCR is not a separate screen; on failure leave fields empty, no error alert.

### Metrics Sheet
Date picker (default selected day, no future dates) → enabled-metric fields → black Capsule Save → history chart/list.
- At least one valid filled field; empty fields write nothing; any invalid field aborts the whole save.
- Filled metrics insert `MetricLog`s. Does not write weight or `DailyRecord`. No OCR.

### Settings Sheet
Height, start weight, target weight, sleep target hours, notifications master switch, export CSV, delete all data (records + weight logs + v1.2 metrics + profile). Changing start/target recomputes the ring immediately.
v1.2 on the same sheet: weight/diet reminder times (`hourAndMinute`, device-local wall clock; reschedule on system time-zone change), Import CSV (preview sheet before write; truncate after 5000 rows, do not reject the whole file), metric enable/add. Import preview is a white card list of counts (incl. truncated), not a spreadsheet editor.

### Sleep Detail Sheet
Last-night duration (`7h 59m`) + sleep-target ring (hide the ring if last night has no data). 30-day asleep bar chart. Average of nights that have data. Mint/teal accents allowed on this sheet only.

### Cycle Detail Sheet
Cycle ring, 180-day timeline, predicted next start (heuristic, factual copy only). Pink accents allowed on this sheet only.

### Onboarding
Step 1: philosophy. Step 2: height + current weight + target; saving **inserts today's `WeightLog`** and stores that weight as start weight. Step 3: optional HealthKit + notification permission (skippable). Photo library permission only when the user first taps OCR. Sleep target stays at the 8.0 h default.

## 5. UI Components & Styling

### Cards
- Weight, BMI, progress, chart, log, and settings content use **white** cards.
- Sleep / Period / Active Energy dashboard cards use the semantic pastel fills above. Text stays black / gray.
- **Corner Radius**: strictly `24pt`.
- **Drop Shadow**: `.shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)`
- **Padding**: `.padding(20)` inside the card.

### Buttons
- **Primary** (`Save`, `Continue`): Capsule, solid black, white bold text, height 50pt–56pt.
- **FAB**: Circle, white fill, purple border/icon, same soft shadow as cards.

### Progress Rings
- Thick rounded stroke: `StrokeStyle(lineWidth: 12, lineCap: .round)`.
- Weight-goal ring: purple gradient for the active arc.
- Sleep-target ring (Sleep sheet only): mint/teal gradient. Hide entirely when last-night sleep is missing. Do not draw a 0% ring.
- Track: `Color.gray.opacity(0.1)`.
- Weight formula (from PRD): `(startWeight - displayWeight) / (startWeight - targetWeight)`, clamped `0...1`.
  `displayWeight` = selected day's latest `WeightLog`, else the global latest weight. **Not** the 7-day MA.

### Charts
- Smooth weight lines: `interpolationMethod(.catmullRom)`.
- Give a non-zero Y domain so a single point still renders.
- Hide unnecessary grid lines (`.chartXAxis(.hidden)` where it stays readable).
- Diet and variable markers use the SF Symbols listed above, single color, no emoji.
- Sleep detail bars may use mint fill; cycle timeline may use pink. Keep them quiet, not neon.

## 6. Localization (Strict Requirement)
- NEVER hardcode UI strings.
- All UI text MUST use SwiftUI localization (`Text("Key")` or `String(localized: "...")`).
- Apple String Catalog (`.xcstrings`) for Simplified Chinese and English. English is the base key language.

# Execution Rules
1. ALWAYS wrap dashboard content in the Card style defined above (white or semantic tint per card type).
2. Never use default blue buttons.
3. Do not overcomplicate the code. Provide complete, runnable SwiftUI views without omitting code blocks.
4. If a compiler error is pasted, fix it directly without verbose explanations.
5. When PRD and this file conflict on product rules, PRD wins; this file wins on visual styling.
6. Do not reintroduce "one weight per `DailyRecord`" or "main-card weight = 7-day MA". Those rules are retired as of v1.1.
7. v1.2 is in scope: CSV import, `MetricLog`, pace-ETA, and reminder time pickers follow PRD §8. Do not add water/waist reminder nags, dual-axis charts, or third-party CSV dialects.
8. Never drop `DailyRecord.weight` / `bodyFat` from the schema. Never nil them after copying to `WeightLog`. Weight writes go only to `WeightLog`.
