# 减脂追踪 App: Ease (个人自用版 v1.2)

## 1. 产品愿景与边界 (Vision & Boundaries)
* **愿景**：客观记录，聚焦趋势。提供一个安静、无压力且具极简现代质感的数据看板。
* **平台**：iOS 18+，仅 Light Mode。单位固定为 kg / cm，数值精度体重 0.1 kg、体脂 0.1%、围度若后续加入则为 0.1 cm。
* **Non-Goals (绝对禁止)**：
    * 禁止计算卡路里、三大营养素（碳水/蛋白质/脂肪）。活动消耗仅作为 HealthKit 客观读数展示，不设热量目标、不据此打分或给饮食建议。
    * 禁止连续打卡火焰 (Streaks)、庆祝动效、目标达成彩蛋等制造情绪波动的机制。
    * 禁止 BMI 的 WHO 色档或「偏瘦 / 正常 / 超重」文案；BMI 只显示数字。
    * 禁止任何社交、社区分享或第三方账号登录。
    * 禁止应用内语言切换。
    * 禁止 Tab 栏。Health 详情只用 Sheet，不新开一级导航。
    * 经期预测仅为本地启发式展示，禁止写成医疗结论或「Apple 官方预测」。
* **本期范围 (v1.1)**：一天多次体重 (`WeightLog`)、顶部周/月日期切换、睡眠详情 Sheet、经期周期详情 Sheet、语义色健康卡（睡眠 / 经期 / Active Energy）。
* **本期范围 (v1.2)**：Ease CSV 再导入、扩展指标（围度 / 饮水等）、达标日估算、自定义提醒时刻。规格见 §8。
* **仍不做**：桌面 Widget、体重+体脂双轴图、月历饮食视图、**饮食变量标签**自定义、Dark Mode、第三方格式导入（MyFitnessPal 等）、为扩展指标单独做催打卡通知。

## 2. 信息架构与页面流转 (Information Architecture)
采用单页面无 Tab 栏架构。全 App 界面：Dashboard、录入 Sheet、设置 Sheet、睡眠详情 Sheet、经期详情 Sheet；另加首次启动的 Onboarding。

「当天」一律指 **Day Picker 所选日**（默认今天）。不可选未来日期。

### 2.1 主控台 (Dashboard View) — 自上而下固定顺序
1. **导航**：标题 `Ease`；右上角设置入口。
2. **Day Picker Header**：周 / 月切换。选中某一天驱动进度环、健康卡、体重主卡、FAB 与录入默认日期。不可选未来。
3. **进度环**：紫色厚描边圆环。文案为已减 kg 与剩余 kg。目标达成后停在 100%，顶部改为冷淡事实 `Target 55.0 kg`，无庆祝动效。低于目标时不继续加圈；若当前体重大于初始体重，进度为 0%。
4. **语义健康卡**（有权限且有数据才出现，无数据/无权限则整卡隐藏，不显示占位「—」）：
    * **Sleep**（青绿底）：所选日前夜 asleep 时长。点击打开睡眠详情 Sheet。
    * **Period**（粉红底）：所选日若为经期日（HealthKit 或手动标签，去重后）则显示。点击打开经期详情 Sheet。
    * **Active Energy**（暖橙底）：所选日 HealthKit Active Energy kcal。只展示读数，不可点进热量目标页，不设卡路里目标。
    * 饮食与差旅/排空标签仍用中性展示（不进马卡龙卡）：已选饮食显示对应 SF Symbol，未选显示待打卡态；`travel` / `bowel` 有则显示。
5. **主卡**：所选日**最新一条** `WeightLog` 的体重（大数字）。该条有体脂则在次要行显示。BMI 纯数字，例如 `BMI 21.4`，不做评估语。所选日没有任何 `WeightLog` 时，回退为全局最新一条体重；仍无则显示不可用态，不算进度。
6. **图表卡**：标题行提供 `7 / 30 / 90` 天分段控件（只改 X 轴可见范围，均线窗口始终为 7 日）。画出范围内**每一次** `WeightLog` 打卡点（按 `timestamp`）；单次点视觉弱化；7 日均线高亮。变量标签以单色 SF Symbol 附着于对应日期。图表下方一排近 7 日饮食 icon 流水。
7. **FAB**：底部圆形 `+`，避开 Home Indicator。点击打开录入 Sheet，日期为 **所选日**（不是永远今天）。

图表交互：按住/拖动预览该点的体重、均线、饮食、标签；单击已有 `WeightLog` 点打开编辑**该条体重**（不是整日 DailyRecord）。无体重点的日期不能靠「点空图」补录，须走表单。删一条 `WeightLog` 不得删除当天饮食/标签/备注。

体重图下不再叠淡灰 HealthKit 睡眠/消耗柱：睡眠与消耗改由语义健康卡 + 详情 Sheet 承担。

### 2.2 录入表单 (Log Sheet)
半屏 Modal。内部自上而下：

1. 日期选择（默认所选日；不可选未来）。
2. 体重（大数字输入）+ 行内「相册识图」入口。新增体重 = **insert 一条 `WeightLog`**，不覆盖当天已有体重。从图表点进来时为编辑该 `WeightLog`（可改体重/体脂或删除该条）。
3. 体脂（可选；识图成功可预填；写在同一条 `WeightLog` 上）。
4. 饮食三选一：Clean / Normal / Cheat。写入当天 `DailyRecord`（字段级 upsert）。
5. 变量标签多选：经期 / 差旅 / 排空。写入当天 `DailyRecord`。
6. 备注（可选）。写入当天 `DailyRecord`。
7. 底部黑色 Capsule `Save`。编辑已有 `WeightLog` 时给弱化 Delete（只删该条体重）。若当天仅有饮食/标签、没有任何 `WeightLog`，可另给弱化 Delete 删除该日 `DailyRecord`。

识图不另开页面。保存规则：本次提交必须至少包含「一条有效体重」或「饮食状态」其中一项。晚上只改饮食时，不得插入空体重，也不得改动已有 `WeightLog`。

### 2.3 极简设置 (Settings Sheet)
右上角入口。v1.1 可改：身高、初始体重、目标体重、**睡眠目标时长**（默认 8.0 h，精度 0.5 h，范围 4–12 h）、通知总开关、导出 CSV、清除全部数据。改初始/目标后进度环立刻重算。不提供语言切换、单位切换、饮食变量标签自定义。

v1.2 在同一 Sheet 追加：体重提醒时刻、饮食提醒时刻、导入 CSV、扩展指标的启用/新增（见 §8）。不新开设置 Tab。

### 2.4 启航 (Onboarding)
2～3 步，不把权限和数据挤在一屏：

1. 原则说明（客观记录、无卡路里计算、无社交）。
2. 录入身高 (cm)、当前体重、目标体重。保存时**插入一条当天 `WeightLog`（含体重）**，并将该体重同时存为初始体重，避免首页有进度、图表却为空。当天 `DailyRecord` 仅在需要写饮食/标签时才创建。
3. 可选授权 HealthKit 与通知（可跳过；之后不反复弹窗）。相册权限延迟到用户第一次点识图时再申请。睡眠目标使用默认 8.0 h，不在启航里追问。

### 2.5 睡眠详情 (Sleep Detail Sheet)
由 Sleep 健康卡打开。HealthKit 只读。无权限或无数据时不打开空页，卡片本身已隐藏。

* 顶部：昨夜 asleep 时长（如 `7h 59m`）+ 相对睡眠目标的环形图。昨夜无数据则隐藏环，不画 0%。
* 中部：近 30 天每晚 asleep 时长柱状图（Swift Charts）。
* 底部：这 30 天有数据的夜晚的平均 asleep。无任何夜则不显示平均。
* 睡眠定义与首页一致：asleep，不用 in-bed；跨午夜间归属为「该日的昨晚」。

### 2.6 经期详情 (Cycle Detail Sheet)
由 Period 健康卡打开。HealthKit 只读，拉取近 **180 天** 经期样本。

* 周期环：用历史经期起始日估算周期长度（见 §5），展示当前周期进度与预测的下一经期开始日。
* 时间轴：历史经期日/段。
* 预测仅为启发式，UI 用冷淡事实语气（如 `Next period around Mar 12`），不做健康建议。
* 手动 `period` 标签仍可标记某日；与 HK 当天经期合并去重。预测只使用 HealthKit 历史，不用手动标签反推（避免差旅误标污染周期）。

## 3. 数据模型与业务规则 (Data Rules - SwiftData)

### 3.1 两条模型，职责分开
* **`DailyRecord`**：每个本地日历日至多一条。**读写职责**只覆盖 `dietStatus`、`tags`、`note`。
* **`WeightLog`**：一次称重一条。允许同一日历日多条。无 Unique Constraint（CloudKit / SwiftData 限制）。运行时体重/体脂的唯一真相源。

**CloudKit 平滑过渡（强制）：**
* `DailyRecord.weight` 与 `DailyRecord.bodyFat` **必须继续留在 SwiftData Schema 里**，类型保持 `Double?`。禁止从 `@Model` 上物理删除这两个属性，禁止改成非 Optional。旧设备若仍按 v1.0 schema 同步，删字段会导致 CloudKit 物化失败或对方崩溃。
* 这两个字段视为 **legacy 只读快照**：v1.1 起新录入、编辑、删除体重都只动 `WeightLog`，**永远不再写入** `DailyRecord.weight` / `bodyFat`（包括不要为了「干净」去赋 `nil`）。
* 启动迁移（幂等）：对每条仍带非空 `weight` 的 `DailyRecord`，若该 `dayKey` 下还没有任何 `WeightLog`，则 insert 一条 `WeightLog`（`timestamp`：若 `updatedAt` 落在该日则用之，否则该日本地 08:00；拷贝 `weight` / `bodyFat`）。该日已有 `WeightLog` 则跳过，避免重复。
* 用 `UserProfile.hasMigratedWeightLogs`（默认 `false`）标记已扫完一遍；成功后置 `true`。已为 `true` 则不再扫。清除全部数据时复位为 `false`。
* UI / 均线 / 通知 / CSV 导出体重列只读 `WeightLog`。仅当某日没有任何 `WeightLog`、且 legacy `DailyRecord.weight` 仍有值时，才允许把该快照当作只读回退（迁移尚未跑完或对端旧数据刚同步下来的窗口）。

### 3.2 `DailyRecord`
* `date`: Date（按本地日历日唯一，忽略时分秒；实现可用 `dayKey`）
* `weight`: Double? — **legacy，Schema 保留，v1.1 起只读不写**
* `bodyFat`: Double? — **legacy，Schema 保留，v1.1 起只读不写**
* `dietStatus`: Enum?（Clean / Normal / Cheat，每日至多一个）
* `tags`: [String]（稳定英文 key：`period` / `travel` / `bowel`；UI 分别用 `drop.fill` / `airplane` / `wind`，可多选，不可自定义）
* `note`: String?
* `updatedAt`: Date（同一 `dayKey` 两条冲突时保留较新者）

字段级 Upsert 仅适用于本模型：同一天再次保存饮食/标签/备注时，只更新本次改过的字段。未改的保持原值。允许「只打饮食、不记体重」。

### 3.3 `WeightLog`
* `id`: UUID（本地插入时生成；CloudKit 物化需要默认值）
* `timestamp`: Date（精确到时分；不可是未来）
* `weight`: Double（必填，精度 0.1 kg，范围 30–150）
* `bodyFat`: Double?（精度 0.1%，范围 5–50）
* `updatedAt`: Date（同一 `id` 冲突时保留较新者）

新增称重 = insert，禁止用「覆盖当天唯一体重」模拟多次打卡。

### 3.4 `UserProfile` 增补
* 保留：`heightCm`、`startWeight`、`targetWeight`、`notificationsEnabled`、`hasCompletedOnboarding`、`updatedAt`
* v1.1 新增：`sleepTargetHours`（默认 8.0，精度 0.5，范围 4–12）、`hasMigratedWeightLogs`（默认 `false`）
* v1.2 新增：`weightReminderHour` / `weightReminderMinute`（默认 8 / 0）、`dietReminderHour` / `dietReminderMinute`（默认 22 / 30）。只存整数，**不存 TimeZone / UTC 偏移**。语义永远是**当前设备本地墙钟**（0–23 / 0–59）：北京设的 8:00，飞到纽约仍是纽约当天 8:00，不得把旧时区换算成新时区的绝对时刻。详见 §8.4。

### 3.5 展示与均线（三个定义不得混用）
* **主卡体重 / BMI 用的体重**：所选日最新一条 `WeightLog`（`timestamp` 最大）；该日没有则全局最新一条。
* **进度环 `displayWeight`**：与主卡相同（所选日最新 → 否则全局最新）。**不用 7 日均线。**
* **进度环公式**（不变）：`progress = (startWeight - displayWeight) / (startWeight - targetWeight)`，clamp 到 `0...1`。
* **BMI**：`BMI = displayWeight(kg) / height(m)^2`，仅主卡数字。
* **7 日均线（仅趋势图）**：窗口固定 7 个日历日。每个日历日只取**当天最后一次** `WeightLog` 进入窗口。一天称 5 次不得把均线变成 5 点平均。窗口内不足 7 个「有体重的日历日」时：只画已有散点与折线，**不画均线**。
* **趋势图散点**：范围内每一次 `WeightLog`，X 轴用 `timestamp`。

### 3.6 删除
* 删一条 `WeightLog`：只删该次称重。
* 删一日 `DailyRecord`：只删饮食/标签/备注，不动体重。
* 设置「清除全部数据」：删除全部 `DailyRecord`、`WeightLog`、v1.2 的 `MetricDefinition` / `MetricLog`，重置 `UserProfile`，回到 Onboarding。

不要在 `DailyRecord` ↔ `WeightLog` 之间建 CloudKit 同步的 `@Relationship`。用 `timestamp` 归入本地日历日查询。`WeightLog` 禁止 Unique Constraint。

## 4. 离线 AI 识图与异常降级 (OCR & Fallbacks)
* **定位**：快捷输入辅助，纯本地 Vision，不强制走识图即可完成录入。
* **流程**：相册选图 → 离线识别数字 → 预填体重与体脂 → **用户确认后点 Save 才落库**（落为新的或正在编辑的 `WeightLog`）。
* **异常阈值**：体重须在 30–150 kg，体脂须在 5–50%。超出范围、解析失败、或一张图无法唯一确定数值，均视为失败。
* **降级**：失败时对应输入框留空，回退手动输入，不弹破坏性错误框。

## 5. HealthKit 静默同步与去重 (HealthKit Integration)
* **权限**：仅 Read-only。拒绝后静默隐藏关联模块，不反复申请。Onboarding 可跳过；首次进入 Dashboard 若仍未决定，不再自动弹。
* **经期去重（首页/图表）**：HealthKit 显示该日经期时，与手动 `drop.fill` 合并，只画一个 `drop.fill`。
* **经期历史（详情页）**：`menstrualFlow` 近 180 天。连续经期日视为同一次 cycle start（取该段第一天）。相邻 start 间隔的中位数为周期长度（需至少 2 次 start；不足则不预测）。下次 start = 最近一次 start + 周期长度。排除间隔 &lt; 15 天或 &gt; 45 天的间隔后再取中位数。
* **睡眠**：使用 `asleep` 时长，不用 in-bed。跨午夜间归属为「该日的昨晚」。`< 6h` 才触发提醒追加句。详情页 30 天柱与平均用同一规则。
* **活动消耗**：Active Energy，单位 kcal。无权限则暖橙卡不渲染。不设热量目标，不在详情 Sheet 展开。

HealthKit Reader 不写 SwiftData。首页可用按日快照；详情页用更完整的夜/经期序列，内部复用同一套查询。

## 6. 状态感知提醒机制 (Context-Aware Notifications)
本地通知（`UNUserNotificationCenter`），不是远程推送。设置里一个总开关；关闭则调度全部取消。

* **分项防打扰（体重与饮食互不影响）**：
    * 体重提醒文案 `今日体重待记录。` — 仅当**当天没有任何 `WeightLog`** 时发送。v1.1 固定 **08:00**；v1.2 改用 `UserProfile` 里的体重提醒时刻。
    * 饮食提醒文案 `今日饮食状态待打卡。` — 仅当当天 `DailyRecord.dietStatus == nil`（含没有 DailyRecord）时发送。v1.1 固定 **22:30**；v1.2 改用饮食提醒时刻。
    * 两个时刻互相独立；若设成同一分钟，仍发两条，不合并。
    * 改时刻或打开总开关后，取消旧 pending 再按新时刻重排。当天该时刻已过则从次日开始。
    * v1.2：调度必须用设备**当前** `TimeZone` 组装墙钟，`DateComponents` 不要钉死出发地时区。监听到系统时区变化（以及显著时间变化）后，取消 pending 再按新本地墙钟重排，避免跨时区漫游后半夜响铃。
* **客观事实联动**（符合条件时追加在对应那一条后面，不另发一条）：
    * 生理期：`经期数据已同步。水分滞留可能引发正常体重波动。`
    * 睡眠不足（昨晚 asleep &lt; 6h）：`昨晚睡眠不足 6 小时。皮质醇升高可能影响数据表现。`

## 7. 国际化、同步与数据安全 (Localization, Sync & Security)
* **多语言**：简体中文与英文；`String Catalog` (.xcstrings)；跟随系统；无应用内切换。
* **隐私**：无第三方服务器、无 Analytics。SwiftData 本地为主；CloudKit 仅同步到用户个人 iCloud。无网时本地照常读写，联网后静默合。
* **冲突**：
    * `DailyRecord`：同一 `dayKey` 保留 `updatedAt` 较新者。
    * `WeightLog`：同一 `id` 保留 `updatedAt` 较新者。同一天多条是合法数据，不得按日期去重成一条。
* **CSV 导出**（离线备份 / Excel）：
    * 每个 `WeightLog` 一行。列：`date, time, weight, bodyFat, dietStatus, tags, note`。
    * `date` 为本地日历日 `YYYY-MM-DD`；`time` 为本地 `HH:mm`。
    * `dietStatus` / `tags` / `note` **只填该日按时间排序后的第一行**，同日后续行这三列留空，避免饮食被复制成多份。
    * `dietStatus` 为 `clean|normal|cheat`；`tags` 为 `period;travel;bowel` 这类稳定 key。
    * 某日只有饮食、没有 `WeightLog`：仍输出一行，`time/weight/bodyFat` 留空。
    * v1.2 若有扩展指标，**另导出** `ease-metrics.csv`（见 §8.2），不塞进体重文件以免列漂移。
    * v1.2 起支持按同一方言再导入（§8.1）。扩展指标另导出 `ease-metrics.csv`。

## 8. v1.2 规格（先写进文档，实现排在 v1.1 之后）

原则：仍然是安静的个人账本。导入不是云同步，扩展指标不是第二个健康 App，达标日不是激励倒计时，自定义时刻不是再加一堆催打卡。

### 8.1 CSV 再导入
* **入口**：设置里 Export 下方 `Import CSV`。系统文件选择器，仅本地文件。不登录、不拉 iCloud Drive 以外的第三方账号。
* **方言**：只认 Ease 自己导出的 UTF-8 逗号分隔。
    * 体重/日记：表头必须是 `date,time,weight,bodyFat,dietStatus,tags,note`。
    * 兼容 v1.0 七列无 `time`（`date,weight,bodyFat,dietStatus,tags,note`）：该行体重的 `timestamp` 记为该日本地 08:00。
    * 扩展指标：表头 `date,time,metricKey,value`（§8.2）。与体重视为两个文件，一次导入选一个。
* **不做**：MyFitnessPal / 薄荷 / Apple Health 导出 XML、照片、任意 Excel 多 Sheet。
* **容量（截断，不整文件拒绝）**：按行流式读取，最多接受表头 + **5000 行数据**。超出的行不读入内存、不导入，也不算 invalid。预览用一行 secondary 文案标明截断，例如 `Read first 5000 rows.`，语气冷淡，不弹警告。
    * 已读超过 **2 MB** 仍未结束（超长行 / 无换行炸弹）：停止继续读，同样按截断处理，已解析的行保留进预览。
    * 只有文件打不开、编码不是 UTF-8、或表头无法识别时，才拒绝整文件、零写入。
* **预览后才落库**：解析完弹出确认 Sheet，冷淡数字即可，例如 `Import 42 weigh-ins, 12 diet days. Skip 3 duplicates. 2 rows invalid.` 若发生截断，追加截断句。用户点 Confirm 才写入。取消则零写入。
* **合并，不覆盖全库**：导入不是「用文件替换 App」。用户若要清空再进，先用「清除全部数据」。
* **行规则**：
    * 未来日期、体重/体脂/围度越界、无法解析的行：计入 invalid，跳过。
    * `WeightLog` 去重键：同一本地日 + 同一 `HH:mm` + 体重（0.1 kg）相同 → 视为重复跳过；否则 insert。不按「一天一条」折叠。
    * `DailyRecord`：有 `dietStatus` / `tags` / `note` 的单元格才 upsert；空单元格 = 未改。tags 只接受 `period|travel|bowel`，其它 token 丢弃。
    * `MetricLog`：同一日 + 同一 `HH:mm` + 同一 `metricKey` + 同一圆整后数值 → 跳过；未知 `metricKey` 若不是内置 key 且用户未定义，计入 invalid。
* **不导入**：睡眠、Active Energy、经期历史（继续只读 HealthKit）。
* **结果**：导入结束后用一行 secondary 文案回报写入条数；不弹成功彩蛋。部分失败只在预览里已经说过 invalid 数。

### 8.2 扩展指标（围度、饮水等）
目标：可记腰围/饮水，但首页不被指标卡淹没；饮食三标签仍然不可自定义。

* **模型（无 CloudKit `@Relationship`）**：`MetricDefinition` 与 `MetricLog` **禁止**用 `@Relationship` 互指（与 v1.1 体重/日记拆分同一原则，避免 CloudKit 物化死锁）。用 `metricKey` 字符串对齐。
    * `MetricDefinition`：`key`（稳定英文或 `custom.<uuid>`）、`kind`（`builtin` / `custom`）、`unit`（`cm` | `ml` | `count`）、`symbolName`（允许列表内的 SF Symbol）、`isEnabled`、`sortOrder`、`updatedAt`。
    * `MetricLog`：`id`、`timestamp`、`metricKey`、`value`、`updatedAt`。一天可多条。无 Unique Constraint。
* **内置目录**（首次进入 v1.2 写入定义，默认**关闭**，用户在设置里打开才会出现在录入表）：
    | key | 单位 | 精度 | 范围 | SF Symbol |
    |-----|------|------|------|-----------|
    | `waist` | cm | 0.1 | 40–200 | `ruler` | 低腰 |
    | `hip` | cm | 0.1 | 40–200 | `ruler` | 臀围 |
    | `chest` | cm | 0.1 | 40–200 | `ruler` | 上胸围 |
    | `thigh` | cm | 0.1 | 20–120 | `ruler` | 右大腿 |
    | `water` | ml | 50 | 0–6000 | `drop` | 饮水 |
    | `underbust` | cm | 0.1 | 40–200 | `ruler` | 下胸围 |
    | `highWaist` | cm | 0.1 | 40–200 | `ruler` | 高腰 |
    | `navel` | cm | 0.1 | 40–200 | `ruler` | 肚脐 |
    | `leftArm` | cm | 0.1 | 15–60 | `ruler` | 左臂 |
    | `rightArm` | cm | 0.1 | 15–60 | `ruler` | 右臂 |
    | `leftThigh` | cm | 0.1 | 20–120 | `ruler` | 左大腿 |
    | `leftCalf` | cm | 0.1 | 20–60 | `ruler` | 左小腿 |
    | `rightCalf` | cm | 0.1 | 20–60 | `ruler` | 右小腿 |
    | `shoulderWidth` | cm | 0.1 | 20–80 | `ruler` | 肩宽 |
    | `shoulder` | cm | 0.1 | 50–160 | `ruler` | 肩围 |
    | `wrist` | cm | 0.1 | 10–30 | `ruler` | 手腕 |
    | `head` | cm | 0.1 | 40–70 | `ruler` | 头围 |
* **自定义**：最多 **8** 条。名称用本地化显示字符串（用户输入，不进饮食 tags）。单位只能三选一。图标只能从一小份 SF Symbol 列表选。禁止 emoji、禁止自定义单位（kcal、% 宏量素等）。
* **录入**：Log Sheet 在备注之上增加「已启用指标」可选数字行。保存时对填了的指标 **insert `MetricLog`**，空行不写。不把指标和体重绑在同一条 `WeightLog`。
* **首页**：不新增马卡龙卡。主卡次行之下最多一行 gray 小号数字，只列出 **`isEnabled == true` 且该所选日有 log** 的指标最新值（如 `Waist 68.0 cm`）。关掉的指标即使当天已有 `MetricLog` 也**不得**出现在这一行，以保持界面清爽。没有任何已启用指标的当日值 → 整行隐藏。
* **图**：体重趋势图不改成双轴。指标图放在 Log 里该指标的历史，或设置/主卡点进一个极简 Metric Sheet（白卡 + 单序列图）。v1.2 不做指标达标环、不做饮水 streak。
* **导出**：`ease-metrics.csv` 列 `date,time,metricKey,value`。`value` 按该指标精度输出。
* **删除 / 禁用**：删一条 `MetricLog` 只删该次。关掉内置或自定义指标只把 `isEnabled = false`，**历史 `MetricLog` 全部保留**（设置/Metric Sheet 仍可看历史）；录入表不再出现该字段；首页主卡次行按上条规则立刻不渲染它。清除全部数据时一并删除定义与 log。

### 8.3 达标日估算（体重）
不是机器学习，不是医疗建议，只是把当前斜率说成一个日期。

* **序列**：用与趋势图相同的「每个日历日最后一次 `WeightLog`」。在这串点上算 7 日均线；回归**只用均线点**，不用原始散点。
* **窗口**：取最近 28 个「有均线的日历日」。
* **MAD 过滤（回归前）**：OLS 对单日手滑（如多打 10 kg）仍然敏感，7 日均线不够挡。对这 28 个均线**体重值**做中位数绝对偏差过滤后再拟合：
    * `medianY = median(y)`，`MAD = median(|y_i − medianY|)`。
    * `MAD == 0`（点几乎相同）→ 不过滤。
    * 否则丢掉 `|y_i − medianY| > 3 × MAD` 的点。只影响本次估算，**不删** `WeightLog`、不改趋势图。
    * 过滤后若均线点仍不足 **14** 个 → 不展示估算（与数据不足同一条隐藏条件，不另写文案）。
* **拟合**：过滤后的均线值对日期做普通最小二乘直线。斜率朝向 `targetWeight`（减重则斜率为负，增肌式目标则相反）才有效。
* **隐藏条件**（满足任一则不渲染，不要写「无法预测」警告；这些护栏必须全部实现）：
    * 过滤后均线点不足 14 个。
    * 进度环已达 100%。
    * 斜率绝对值 &lt; 0.01 kg / 日。
    * 外推日期超过今天 + 730 天。
    * 外推落在过去。
    * 所选日没有可用的 `displayWeight`。
* **文案**：进度环下方一行 gray regular，例如 `At this pace, around 12 Oct 2026.` 中文 `按近况大约 2026年10月12日。` 到达该日不庆祝、不改环的 100% 行为。
* **禁止**：把估算写成「你将成功 / 落后计划」、用热量缺口反推、用睡眠/经期修正体重斜率。经期预测仍只用 §5 的周期启发式，两套预测不得混在一句文案里。

### 8.4 自定义提醒时刻
* 设置在通知总开关下方：`Weight reminder`、`Diet reminder` 两个 `hourAndMinute` 选择器。默认 08:00 与 22:30。
* **本地墙钟，不是绝对时刻**：`UserProfile` 只同步 hour/minute 整数。跨设备、跨时区都解读为**那台设备当前时区的墙钟**。iPhone 从北京飞到纽约后，8:00 仍是纽约早上 8:00，不要把「北京 8:00」换算成纽约 20:00 / 19:00。
* **时区变化必须重排**：监听系统时区变化（及显著时间变化）。触发后取消全部 Ease pending，再用当前 `TimeZone` 按 §6 规则重排。不重排会出现漫游后半夜叫醒。
* 只改**何时**发，不改**是否**发：当天已有 `WeightLog` 仍跳过体重提醒；已有 `dietStatus` 仍跳过饮食提醒。经期/睡眠不足仍是追加句，不另调时间。
* 扩展指标（围度、饮水）v1.2 **不**增加第三、第四条提醒。
* 总开关关闭 → 取消全部 pending，选择器可仍显示但调度不生效。
* 时刻存 `UserProfile`，随 iCloud 同步；冲突取较新 `updatedAt` 的整份 profile（与现有 profile 去重策略一致）。hour/minute 冲突随整份 profile 走，不要单独按字段合并出「8 点 + 纽约分钟」这种半套。
