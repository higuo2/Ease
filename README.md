# Ease

个人用的 iOS 减脂记录 App。只记事实和趋势：体重、围度，以及 HealthKit 里的睡眠 / 经期 / 活动消耗。BMI 用中国成人切点做灰色区间说明，不做卡路里、不做打卡火焰、不做社交。

当前版本 **v1.3**。下列文档与**已上线界面**对齐：产品规则 [`PRD.md`](PRD.md)，视觉与工程约束 [`AGENT.md`](AGENT.md)，体感规格 [`UX.md`](UX.md)。

## 能做什么

四个 Tab：

| Tab | 内容 |
|---|---|
| **体重** | 大号当前体重、阶段目标卡（16pt 线性进度）、可配置莫兰迪方块（BMI / 围度 / 体重，可选睡眠、经期、消耗）、近 30 天体重列表（全宽 ScrollView） |
| **趋势** | 7 / 30 / 90 / 全部折线、区间统计、**Weight Forecast**（旬区间 + 详情 Sheet）、**Lifestyle Insights**（最多 3 条交叉对照 + 详情 Sheet） |
| **日历** | 月历（日号 + 体重 + 体重/经期/睡眠色点）、选中日 **Daily Snapshot**（体重 / 睡眠 / 消耗 / 经期莫兰迪格）、**Overview**（净变化 + 打卡圆环 + 月均/周均 footer） |
| **设置** | 档案（含生日/性别/睡眠目标）、提醒、首页模块、围度开关（五条核心 + 更多）、CSV 导入导出、清数据 |

录入拆成独立 Sheet：**体重**（`LogSheetView`：导航栏 Save/关闭、相册识图 OCR）、**围度**（`MetricSheet`：Core/Limbs/Other + 解剖排序 + 统一指标图标）。一天可以有多条体重。睡眠、经期、消耗只读 HealthKit，不从 CSV 导入。饮食 / 标签 / 备注 / 餐图只留在 SwiftData 与 CSV 列里，界面不再录入。

单位固定 kg / cm。界面仅 Light Mode。文案为英文 + 简体中文（跟系统语言，应用内不切换）。文案不用间隔号「·」。

涨跌语义色：体重下降为莫兰迪绿，上升为莫兰迪珊瑚红（`EasePalette.semanticDelta`）。阶段进度条仍用珊瑚渐变填充。

## 技术栈

- iOS 18+，SwiftUI，MVVM（`@Observable`）
- SwiftData + CloudKit（本地优先，多设备同步）
- HealthKit、UserNotifications、Vision（体重秤 OCR）、Swift Charts
- Bundle ID：`com.higuo2.Ease`

体重写在 `WeightLog`；`DailyRecord` 每个日历日至多一条（legacy 体重快照 + 日记列保留）；围度是 `MetricDefinition` + `MetricLog`。模型之间不用 CloudKit `@Relationship`。

Tab 主查询窗口：`DailyRecord` 近 180 天，`WeightLog` / `MetricLog` 近 365 天。设置里 CSV 导出/导入用完整 `FetchDescriptor`，不受该窗口截断。

## 在 Xcode 里跑

需要一台 Mac，Xcode 16+，真机或 iOS 18 模拟器。

```bash
git clone https://github.com/higuo2/Ease.git
open Ease.xcodeproj
```

选 **Ease** scheme，签好自己的 Team（HealthKit / CloudKit / 通知需要）。跑测试：`Cmd+U`（`EaseTests`，内存 SwiftData，日历钉在 `Asia/Hong_Kong`）。Windows 上不能 `xcodebuild`。

## CSV

设置里导出两份方言（只认 Ease 自己的 UTF-8 逗号表，一次选一个文件导入）：

- 体重 / 日记：`date,time,weight,bodyFat,dietStatus,tags,note`
- 围度：`date,time,metricKey,value`

仓库 [`Import/`](Import/) 里有一份可导入的样例。导入是合并，不是整库覆盖；预览确认后才写入。无效/重复最多列出 20 条样本。超过 5000 行或 2 MB 会截断，不整文件拒绝。

## 目录

```
Ease/          App 源码（Models / Data / Views）
EaseTests/     单元测试
Import/        样例 CSV
PRD.md         产品规格（与当前 UI 一致）
AGENT.md       设计系统与实现约束
UX.md          体感：当前已落地与明确不做
```

## 明确不做

卡路里与宏量营养素、饮食打卡 UI、连续打卡、Dark Mode、第三方格式（薄荷 / MyFitnessPal 等）、饮水追踪、围度催打卡通知、桌面/锁屏 Widget、「一键同步 HealthKit」。BMI 不做绿黄红交通灯或医疗结论（首页灰字中国档；Sheet 内安静莫兰迪条可以）。达标日估算用旬区间，不做倒计时。设置页不用珊瑚当全局 tint。
