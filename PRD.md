# 减脂追踪 App: Ease (个人自用版 v1.2)

## 1. 产品愿景与边界 (Vision & Boundaries)
* **愿景**：客观记录，聚焦趋势。提供安静、无压力的 **iOS 奶油极简（Milk & Card）** 数据看板：高留白、浅灰卡片分层、大字报数字、珊瑚红提示减重方向。
* **平台**：iOS 18+，仅 Light Mode。单位固定为 kg / cm，数值精度体重 0.1 kg、体脂 0.1%、围度 0.1 cm。
* **Non-Goals (绝对禁止)**：
    * 禁止计算卡路里、三大营养素（碳水/蛋白质/脂肪）。活动消耗若展示仅为 HealthKit 客观读数，不设热量目标、不据此打分或给饮食建议。
    * 禁止连续打卡火焰 (Streaks)、庆祝动效、目标达成彩蛋等制造情绪波动的机制。
    * 禁止 BMI 绿黄红色档图或状态 chip。BMI **可以**用灰色文案标注中国成人区间（偏瘦 / 正常 / 超重 / 肥胖），并在详情 Sheet 说明切点；禁止写成医疗诊断。
    * 禁止任何社交、社区分享或第三方账号登录。
    * 禁止应用内语言切换。
    * 禁止紫色品牌主色、重阴影堆叠卡片。视觉规范见 `AGENT.md`。
    * 经期预测仅为本地启发式展示，禁止写成医疗结论或「Apple 官方预测」。
* **本期范围 (v1.1)**：一天多次体重 (`WeightLog`)、4-Tab 根导航、睡眠/经期详情 Sheet。
* **本期范围 (v1.2)**：Ease CSV 再导入、扩展指标（围度）、达标日估算（含趋势页高级估算）、自定义提醒时刻、可配置首页模块。规格见 §8。
* **仍不做**：桌面 Widget、体重+体脂双轴图、**饮食变量标签**自定义、Dark Mode、第三方格式导入（MyFitnessPal 等）、为扩展指标单独做催打卡通知、卡路里合计、饮水追踪。

## 2. 信息架构与页面流转 (Information Architecture)
采用 **4-Tab 根导航**。全 App 界面：体重 Tab、趋势 Tab、日历 Tab、**设置 Tab**；叠加体重/饮食录入 Sheet、围度 Sheet、体重历史 Sheet、BMI / 睡眠 / 经期 / 活动消耗详情 Sheet；另加首次启动的 Onboarding。

「当天」默认今天；日历选中日可驱动明细。不可选未来日期。视觉参数以 `AGENT.md` 为准（背景 `#F7F8F9`、卡片白/`#F2F3F5`、圆角 16–20、珊瑚强调色）。**无**体重 Tab 右上角齿轮、**无**右下角 FAB。

### 2.1 体重 Tab（Dashboard）
自上而下：
1. **导航**：标题 `Ease`（无 trailing 设置按钮；设置在第四 Tab）。
2. **Hero**：居中巨幅当前体重（所选日最新 `WeightLog`，否则全局最新；仍无则不可用态、不算进度）。下方一行周增减小字（如 `▼1.8 kg 本周`）。
3. **阶段目标卡片**：浅灰圆角卡 — 线性进度条、起始体重、目标体重；可选一行 **基础 pace ETA**（§8.3.A）。进度公式不变：`(start - display) / (start - target)`，clamp `0...1`；达 100% 后冷淡展示目标，无庆祝。当前体重大于初始 → 0%。**不再使用紫色进度环。**
4. **可配置莫兰迪方块**：默认 BMI（数字 + 灰色区间文案）、围度、体重、饮食。用户可追加睡眠、经期、活动消耗；虚线「添加」打开模块编辑。点 BMI → BMI 详情 Sheet（公式、中国成人切点、WHO 对照）；点体重 → 体重 Sheet；点饮食 → 饮食 Sheet；点围度 → 围度 Sheet（录入 + 历史列表，**无围度趋势图**）；点睡眠 / 经期 / 消耗 → 对应详情 Sheet。**不做饮水。**
5. **体重列表 (Weight log)**：默认只展示**近 30 天**；按日展示早（太阳）/ 晚（月亮）、相对昨日涨跌、备注。点行编辑该日最新 `WeightLog`（或补录）。点 **All** 打开独立「体重历史」Sheet（全部日期，同一行样式），不在本页原地展开。

### 2.2 趋势 Tab（Trend）
1. 顶部 segmented 胶囊：`7天 | 30天 | 90天 | 全部`（只改 X 可见范围）。
2. **主折线**：范围内**每个日历日最后一次** `WeightLog` 连成清晰主线；X/Y 轴有刻度；目标体重虚线带文案；拖动黑色 Tooltip（日期 + 体重）。**不显示经期/标签标记。**
3. 2×3 数据卡：最高、最低、平均、体重变化、距离目标、记录天数。
4. **高级估算卡**（§8.3.B）：在基础体重斜率上，用近期睡眠、活动消耗、经期日做**轻度乘数修正**，展示大约剩余天数与预估日期。数据不足则隐藏整卡数字区，不写「无法预测」。非医疗建议；不与阶段卡基础 pace 混写成一句。

交互：预览不改数据；点已有日可编辑该日体重。删体重不得删当日饮食/标签/备注。

### 2.3 日历 Tab（Calendar）
1. 7 列月历；每格：日号 + 当日体重 + 涨跌幅（`▼0.2` / `▲0.2`）。
2. **周均 / 月均**体重卡：周均 = 当前选中日所在自然周内有记录日的平均；月均 = 当前浏览月内有记录日的平均。
3. 月度统计横栏（5 列）：打卡天数、减重天数、增重天数、日均变化、本月变化。
4. 选中日后底部明细：早晚体重、日间波动（同日晚−早）、饮食打卡。**禁止**卡路里合计或宏量营养素。跨日的夜间代谢（前晚−今早）不在此硬塞。

### 2.4 设置 Tab（Settings）
第四 Tab（非 Sheet）。可改：身高、生日、生理性别、初始体重、目标体重、**睡眠目标时长**（默认 8.0 h，精度 0.5 h，范围 4–12 h）、首页模块开关、通知总开关与提醒时刻、导出 / 导入 CSV、扩展指标启用与自定义、清除全部数据。改初始/目标后阶段进度立刻重算。不提供语言切换、单位切换、饮食变量标签自定义。

* 次级入口：设置内可打开睡眠 / 经期详情（与首页方块同一套 Sheet）。
* **清除全部数据**：须**两次确认**（先确认对话框「继续」，再 alert 最终清除）；清除后回到 Onboarding。

### 2.5 录入表单 (Log Sheets)
体重与饮食拆成两个独立半屏 Modal（不再合成一表）。

**体重 Sheet**：可展开图形日历改日期（默认所选日 / 今天；不可未来）→ 体重 + 行内相册识图 → 体脂（可选）→ Save。新增 = **insert `WeightLog`**。编辑已有条可改或 Delete 该条。今天用当前时刻；补过去的日子用当天 08:00。

**饮食 Sheet**：可展开日历改日期 → 饮食三选一 → 标签 → 备注 → Save。写入当天 `DailyRecord`（字段级 upsert）。可 Delete 当日日记（不动体重）。

围度不在上述 Sheet，也不参与体重/饮食校验。

### 2.6 围度 Sheet (Metric Sheet)
独立半屏 Modal。**主入口**：体重 Tab 围度方块。**次入口**：设置里某指标的 History。内部：日期 → 已启用指标数字行 → Save → 下方该指标**历史列表**（v1.2 不做围度趋势图；体重趋势只在 Trend Tab）。

保存规则：至少一行有效值；空行不写；任一行越界/无法解析则**整次零写入**并标红。不要求体重、不写 `DailyRecord`、不触发饮食/体重提醒。今天用当前时刻，补过去的日子用当天 08:00。删一条历史只删该次 `MetricLog`。

### 2.7 启航 (Onboarding)
2～3 步，不把权限和数据挤在一屏：

1. 原则说明（客观记录、无卡路里计算、无社交）。
2. 录入身高 (cm)、当前体重、目标体重。保存时**插入一条当天 `WeightLog`（含体重）**，并将该体重同时存为初始体重。当天 `DailyRecord` 仅在需要写饮食/标签时才创建。
3. 可选授权 HealthKit 与通知（可跳过；之后不反复弹窗）。相册权限延迟到用户第一次点识图时再申请。睡眠目标使用默认 8.0 h，不在启航里追问。

### 2.8 睡眠详情 (Sleep Detail Sheet)
入口：首页睡眠方块或设置。HealthKit 只读。

* 顶部：昨夜 asleep 时长 + 相对睡眠目标的环。昨夜无数据则隐藏环，不画 0%。
* 中部：近 30 天柱状图，**X/Y 轴可见**；目标虚线可选。
* 近期夜列表 + 有数据夜的平均 asleep。
* 睡眠定义：asleep，不用 in-bed；跨午夜间归属为「该日的昨晚」。

### 2.9 经期详情 (Cycle Detail Sheet)
入口：首页经期方块或设置。HealthKit 只读，近 **180 天**。

* 周期环：进度与预测下一经期开始日；可选展示周期长度、上次持续天数。
* 时间轴 + **迷你月历高亮**经期日 + 近期周期段列表（含天数）。
* 预测仅为启发式，冷淡事实语气；不做健康建议。
* 手动 `period` 标签可与 HK 当天合并去重用于展示；**预测只用 HealthKit 历史**，不用手动标签反推。

### 2.10 活动消耗详情 (Energy Detail Sheet)
入口：首页消耗方块。HealthKit Active Energy 只读；展示当日值、近窗柱状图（带轴）、近期列表与平均。**不设热量目标、不据此给饮食建议。**

### 2.11 BMI 详情 (BMI Detail Sheet)
入口：体重 Tab 的 BMI 方块。只读。展示当前 BMI 数字、中国成人档名、本次用到的身高/体重/年龄/性别、公式（年龄性别不进乘法）、中国成人切点表、WHO 对照表、正常 BMI 对应体重区间。冷淡免责声明。未满 18 不给成人档。无绿黄红图。不打开体重录入。

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
* v1.2 新增：`weightReminderHour` / `weightReminderMinute`（默认 8 / 0）、`dietReminderHour` / `dietReminderMinute`（默认 22 / 30）。只存整数，**不存 TimeZone / UTC 偏移**。语义永远是**当前设备本地墙钟**（0–23 / 0–59）。详见 §8.4。
* v1.2 新增：`homeModulesRaw`（逗号分隔模块 key；空则默认 `bmi,measurements,weight,diet`）。合法 key：`bmi` / `measurements` / `weight` / `diet` / `sleep` / `period` / `energy`。
* 新增：`birthDate`（`Date?`，默认 `nil`）、`sexRaw`（`unspecified` / `female` / `male`，默认 `unspecified`）。生日不能是未来、年龄不超过 120。不进 CSV。启航不追问；设置里补。性别仅档案展示，不改变 BMI 公式或成人切点。

### 3.5 展示与均线（定义不得混用）
* **Hero / BMI 用的体重**：所选日最新一条 `WeightLog`（`timestamp` 最大）；该日没有则全局最新一条。
* **阶段进度 `displayWeight`**：与 Hero 相同。**不用 7 日均线。**
* **进度公式**（不变）：`progress = (startWeight - displayWeight) / (startWeight - targetWeight)`，clamp 到 `0...1`。UI 用线性条，不用紫色环。
* **BMI**：`BMI = displayWeight(kg) / height(m)^2`，精度 0.1。首页方块显示数字 + **灰色**中国成人档名；点开详情 Sheet 展示公式、输入、中国成人切点表、WHO 对照表、正常 BMI 对应体重区间。禁止绿黄红色档。
    * 中国成人（当前采用）：&lt; 18.5 偏瘦；18.5–23.9 正常；24.0–27.9 超重；≥ 28.0 肥胖。
    * WHO 成人仅对照：正常到 24.9，超重 25.0–29.9，肥胖 ≥ 30。
    * 有生日且未满 18：仍显示数字，档名为「未评价」，不套成人切点。不做儿童百分位。
    * 无生日：按成人分档，Sheet 脚注说明未填生日。
    * 年龄、性别不进入 BMI 公式。非医疗结论；不据此改阶段目标。
* **趋势主线 / pace 序列**：每个日历日只取**当天最后一次** `WeightLog`。
* **7 日均线（仅用于 pace 回归，见 §8.3）**：在 last-per-day 序列上算；回归只用均线点。
* **早晚 / 日间波动 / 夜间代谢**：
  * 同日按 `timestamp` 最早为「早」、最晚为「晚」。
  * **日间波动** = 同日晚−早。当日不足两条则空。
  * **夜间代谢** = 前一日「晚」− 本日「早」。任一侧缺失则空（体重历史行目前以早/晚/日涨跌为主；夜间代谢公式保留供扩展）。

### 3.6 删除
* 删一条 `WeightLog`：只删该次称重。
* 删一日 `DailyRecord`：只删饮食/标签/备注，不动体重。
* 设置「清除全部数据」：删除全部 `DailyRecord`、`WeightLog`、`MetricDefinition` / `MetricLog`，重置 `UserProfile`，回到 Onboarding。须两次确认。

不要在 `DailyRecord` ↔ `WeightLog` 之间建 CloudKit 同步的 `@Relationship`。用 `timestamp` 归入本地日历日查询。`WeightLog` 禁止 Unique Constraint。

## 4. 离线 AI 识图与异常降级 (OCR & Fallbacks)
* **定位**：快捷输入辅助，纯本地 Vision，不强制走识图即可完成录入。
* **流程**：相册选图 → 离线识别数字 → 预填体重与体脂 → **用户确认后点 Save 才落库**。
* **异常阈值**：体重须在 30–150 kg，体脂须在 5–50%。超出范围、解析失败、或一张图无法唯一确定数值，均视为失败。
* **降级**：失败时对应输入框留空，回退手动输入，不弹破坏性错误框。

## 5. HealthKit 静默同步与去重 (HealthKit Integration)
* **权限**：仅 Read-only。拒绝后静默隐藏关联模块，不反复申请。Onboarding 可跳过；首次进入体重 Tab 若仍未决定，不再自动弹。
* **经期去重（展示）**：HealthKit 显示该日经期时，与手动 `drop.fill` 合并，只显示一次。
* **经期历史（详情页）**：`menstrualFlow` 近 180 天。连续经期日视为同一次 cycle start（取该段第一天）。相邻 start 间隔的中位数为周期长度（需至少 2 次 start；不足则不预测）。下次 start = 最近一次 start + 周期长度。排除间隔 &lt; 15 天或 &gt; 45 天的间隔后再取中位数。
* **睡眠**：使用 `asleep` 时长，不用 in-bed。跨午夜间归属为「该日的昨晚」。`< 6h` 才触发提醒追加句。详情页 30 天柱与平均用同一规则。
* **活动消耗**：Active Energy，单位 kcal。无权限则不渲染对应方块。不设热量目标；可打开只读详情 Sheet。

HealthKit Reader 不写 SwiftData。首页可用按日快照；详情页用更完整的夜/经期/消耗序列，内部复用同一套查询。

## 6. 状态感知提醒机制 (Context-Aware Notifications)
本地通知（`UNUserNotificationCenter`），不是远程推送。设置里一个总开关；关闭则调度全部取消。

* **分项防打扰（体重与饮食互不影响）**：
    * 体重提醒文案 `今日体重待记录。` — 仅当**当天没有任何 `WeightLog`** 时发送。用 `UserProfile` 体重提醒时刻。
    * 饮食提醒文案 `今日饮食状态待打卡。` — 仅当当天 `DailyRecord.dietStatus == nil` 时发送。用饮食提醒时刻。
    * 两个时刻互相独立；若设成同一分钟，仍发两条，不合并。
    * 改时刻或打开总开关后，取消旧 pending 再按新时刻重排。当天该时刻已过则从次日开始。
    * 调度必须用设备**当前** `TimeZone` 组装墙钟。监听到系统时区变化（以及显著时间变化）后，取消 pending 再按新本地墙钟重排。
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
    * `dietStatus` / `tags` / `note` **只填该日按时间排序后的第一行**，同日后续行这三列留空。
    * `dietStatus` 为 `clean|normal|cheat`；`tags` 为 `period;travel;bowel` 这类稳定 key。
    * 某日只有饮食、没有 `WeightLog`：仍输出一行，`time/weight/bodyFat` 留空。
    * 扩展指标**另导出** `ease-metrics.csv`（见 §8.2）。
    * 支持按同一方言再导入（§8.1）。

## 8. v1.2 规格

原则：仍然是安静的个人账本。导入不是云同步，扩展指标不是第二个健康 App，达标日不是激励倒计时，自定义时刻不是再加一堆催打卡。

### 8.1 CSV 再导入
* **入口**：设置 Tab 里 Export 下方 `Import CSV`。系统文件选择器，仅本地文件。
* **方言**：只认 Ease 自己导出的 UTF-8 逗号分隔。
    * 体重/日记：表头必须是 `date,time,weight,bodyFat,dietStatus,tags,note`。
    * 兼容 v1.0 **六列**无 `time`（`date,weight,bodyFat,dietStatus,tags,note`）：该行体重的 `timestamp` 记为该日本地 08:00。
    * 扩展指标：表头 `date,time,metricKey,value`（§8.2）。与体重视为两个文件，一次导入选一个。
* **不做**：MyFitnessPal / 薄荷 / Apple Health 导出 XML、照片、任意 Excel 多 Sheet。
* **容量（截断，不整文件拒绝）**：按行流式读取，最多接受表头 + **5000 行数据**。超出的行不读入内存、不导入，也不算 invalid。预览用一行 secondary 文案标明截断。
    * 已读超过 **2 MB** 仍未结束：停止继续读，按截断处理。
    * 只有文件打不开、编码不是 UTF-8、或表头无法识别时，才拒绝整文件、零写入。
* **预览后才落库**：解析完弹出确认 Sheet；用户点 Confirm 才写入。取消则零写入。
* **合并，不覆盖全库**：用户若要清空再进，先用「清除全部数据」。
* **行规则**：
    * 未来日期、体重/体脂/围度越界、无法解析的行：计入 invalid，跳过。
    * `WeightLog` 去重键：同一本地日 + 同一 `HH:mm` + 体重（0.1 kg）相同 → 视为重复跳过；否则 insert。
    * `DailyRecord`：有 `dietStatus` / `tags` / `note` 的单元格才 upsert；空单元格 = 未改。tags 只接受 `period|travel|bowel`。
    * `MetricLog`：同一日 + 同一 `HH:mm` + 同一 `metricKey` + 同一圆整后数值 → 跳过；未知 `metricKey` 若不是内置 key 且用户未定义，计入 invalid。
* **不导入**：睡眠、Active Energy、经期历史（继续只读 HealthKit）。
* **结果**：导入结束后用一行 secondary 文案回报写入条数；不弹成功彩蛋。

### 8.2 扩展指标（围度）
目标：可记腰围等围度，但首页不被指标卡淹没；饮食三标签仍然不可自定义。**不做饮水。**

* **模型（无 CloudKit `@Relationship`）**：`MetricDefinition` 与 `MetricLog` 用 `metricKey` 字符串对齐，禁止 `@Relationship`。
    * `MetricDefinition`：`key`、`kind`（`builtin` / `custom`）、`unit`（`cm` | `ml` | `count`）、`symbolName`、`displayName`、`isEnabled`、`sortOrder`、`updatedAt`。
    * `MetricLog`：`id`、`timestamp`、`metricKey`、`value`、`updatedAt`。一天可多条。无 Unique Constraint。
* **内置目录**（首次 seed；默认关闭，设置里打开后才进入围度 Sheet 录入区）：
    | key | 单位 | 精度 | 范围 | SF Symbol |
    |-----|------|------|------|-----------|
    | `waist` | cm | 0.1 | 40–200 | `ruler` | 低腰 |
    | `hip` | cm | 0.1 | 40–200 | `ruler` | 臀围 |
    | `chest` | cm | 0.1 | 40–200 | `ruler` | 上胸围 |
    | `thigh` | cm | 0.1 | 20–120 | `ruler` | 右大腿 |
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
* **自定义**：最多 **8** 条。单位只能三选一。图标只能从允许 SF Symbol 列表选。禁止 emoji、禁止自定义单位（kcal、% 宏量素等）。
* **录入**：独立围度 Sheet（§2.6）。保存时对填了的指标 **insert `MetricLog`**。
* **体重 Tab**：围度方块为日常主入口；设置只负责启用/自定义与次级 History。关掉的指标不得出现在录入区读数；历史仍可在 History / Sheet 查看。全部禁用 → 方块可隐藏或仅作空入口（按实现：模块关掉则不显示）。
* **图**：体重趋势图不改成双轴。围度 Sheet **不做**围度趋势图（仅列表）。v1.2 不做指标达标环、不做饮水 streak。
* **导出**：`ease-metrics.csv` 列 `date,time,metricKey,value`。
* **删除 / 禁用**：删一条 `MetricLog` 只删该次。关掉指标只把 `isEnabled = false`，历史保留。清除全部数据时一并删除定义与 log。

### 8.3 达标日估算（体重）
不是机器学习，不是医疗建议。分两层，**不得混写成一句文案**：

#### 8.3.A 基础 pace（阶段目标卡）
* **序列**：每个日历日最后一次 `WeightLog` → 7 日均线；回归**只用均线点**。
* **窗口**：最近 28 个有均线的日历日。
* **MAD 过滤**：`medianY = median(y)`，`MAD = median(|y_i − medianY|)`；`MAD == 0` 不过滤；否则丢掉 `|y_i − medianY| > 3 × MAD`。过滤后不足 **14** 点 → 不展示。
* **拟合**：OLS；斜率须朝向 `targetWeight`。
* **隐藏条件**：点数不足 / 进度已 100% / `|slope| < 0.01` kg/日 / ETA 超今天+730 天 / ETA 在过去 / 无 `displayWeight`。
* **文案**：阶段卡下方一行 gray，例如 `At this pace, around 12 Oct 2026.` / `按近况大约 2026年10月12日。`
* **禁止（仅对本层）**：写成「你将成功 / 落后计划」；用热量缺口反推；用睡眠/经期/消耗修正斜率。

#### 8.3.B 高级估算（仅趋势 Tab）
* 在 8.3.A 同一套均线 + MAD + OLS 得到基础斜率后，用近期窗口内的睡眠（相对睡眠目标）、活动消耗（相对中位数）、经期日占比做**轻度乘数**（大致范围约 0.88…1.08），得到调整斜率，再推剩余天数与日期。
* 仍遵守同一隐藏护栏与 730 天上限。
* 文案冷淡（如「大约 N 天 · 约某日」）；展示因子读数即可，不写激励或医疗结论。
* **禁止**：与 8.3.A 合成一句；把消耗写成卡路里缺口目标；经期周期预测文案与本估算混排。

### 8.4 自定义提醒时刻
* 设置在通知总开关下方：`Weight reminder`、`Diet reminder` 两个 `hourAndMinute` 选择器。默认 08:00 与 22:30。
* **本地墙钟，不是绝对时刻**：`UserProfile` 只同步 hour/minute 整数。
* **时区变化必须重排**：监听系统时区变化及显著时间变化后取消 pending 再重排。
* 只改**何时**发，不改**是否**发。扩展指标 v1.2 **不**增加第三、第四条提醒。
* 总开关关闭 → 取消全部 pending。
* 时刻随整份 `UserProfile` 的 `updatedAt` 冲突策略同步。
