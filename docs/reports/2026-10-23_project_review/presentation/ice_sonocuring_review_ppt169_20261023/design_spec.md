<!-- ppt-master-schema: design-spec/v1 -->
# ICE-Sonocuring Progress Review - Design Spec

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | ICE-Sonocuring Progress Review |
| Canvas Format | ppt169, 1280 × 720 |
| Page Count | 5 |
| Primary Language | zh-CN |
| Target Audience | 课题组与导师，关注工程进展、当前64元奇偶方案、数值证据与后续条件。 |
| Communication Intent | 汇报2026年9—10月进展，解释空间选择性问题，对齐单点、短线和双功能流程的验证优先级。 |
| Desired Audience Outcome | 区分已实现工具、模型数值证据和未验证物理能力，理解负结果与所需输入。 |
| Core Message / Ask / Action | 可追溯工具链已形成；目标附近声压集中有模型证据，焦移、长轴向焦区和目标外暴露仍需解释；先取得有标定、有对照的体外单点证据。 |
| Delivery Context | 8—10分钟中文主讲汇报，五页均承载内容；会后结合备注复核。 |
| Artifact Afterlife | 可编辑PPTX供汇报、讨论和修改；备注保留讲稿、假设、完整来源及硬件手册版本页码。 |
| Reading Mode | balanced |
| Content Strategy | 参考五页大纲，核对报告和仓库保存结果；允许精炼和优化构图，保留负结果、假设及未验证边界。 |
| Design Style | 证据审阅；在用户授权下从三种完整方向中选定，见analysis/design_decisions.md。 |
| AI Image Acquisition Path | not applicable |
| Generation Mode | continuous |
| Spec Refinement | disabled |
| Speaker Notes | enabled — delegated final Stage-2 production decision |
| Custom Animations | disabled — delegated final Stage-2 production decision, all-motion scope including transitions |
| Narration Audio | disabled — delegated final Stage-2 production decision |
| Created Date | 2026-10-23 |

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | PPT 16:9 |
| Dimensions | 1280 × 720 |
| viewBox | `0 0 1280 720` |
| Margins | 48 px horizontal; 36 px top; 30 px bottom |
| Content Area | x=48…1232, y=36…690 |

## III. Visual Theme

### Theme Style

- **Mode**: custom
- **Mode References**: pyramid
- **Mode Behavior**: 保留五页主题顺序，每页以有证据支持的判断开场，接事实和图形，再指出解释边界或下一步依据。
- **Visual style**: custom
- **Visual Style References**: swiss-minimal, data-journalism
- **Visual Style Behavior**: swiss-minimal提供精确对齐、少量大色面与留白；data-journalism提供数据注释、来源行与结果侧栏。固定无衬线字体，以粗细和字号建立层级；图形承担关系，颜色承担证据状态。
- **Theme**: 细线、断开的验证路径与青绿/琥珀状态标记在不同页面变化，连接“已形成工具—仍需物理证据”的同一主线。
- **Tone**: 清楚、克制、可核查。

### Color Scheme

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | #FFFFFF | 主画布 |
| Secondary background | #EFF3F7 | 方法或模型上下文 |
| Primary | #142B45 | 标题、主线、大字段 |
| Accent | #C27B22 | 未验证、解释边界、未通过项 |
| Secondary accent | #008C95 | 已实现工具、局部数值证据 |
| Body text | #203247 | 正文 |
| Secondary text | #516176 | 图注、来源和参数性质 |
| Divider | #CBD5DF | 分隔线 |
| Surface | #F7F9FB | 轻量数据底面 |
| Grid | #E2E8EF | 数值参照线 |

## IV. Typography System

### Font Plan

| Role | Character (Reference) | Primary | English if non-English | Fallback tail |
| --- | --- | --- | --- | --- |
| Title | 结构清晰的粗体无衬线 | Microsoft YaHei | Arial | sans-serif |
| Body | 易读中性无衬线 | Microsoft YaHei | Arial | sans-serif |

- **Title stack**: Microsoft YaHei, Arial
- **Body stack**: Microsoft YaHei, Arial

### Font Size Hierarchy

| Purpose | Anchor Size (px) |
| --- | ---: |
| Body | 28 |
| Title | 42 |
| Subtitle | 30 |
| Lead | 30 |
| Annotation | 20 |
| Footnote | 16 |
| Data | 40 |
| Display | 52 |
| Index | 22 |

## V. Layout Principles

### Deck-wide Direction

- **Hierarchy direction**: 判断标题 → 主图与关键事实 → 解释边界和来源。
- **Composition tendency**: 围绕关系形成时间演进、三条方法线、阵列与交替时序、结果对照和验收路线五种不同构图。
- **Cross-page continuity**: 页眉小字、页码与结论行一致；青绿标记可追溯进展，琥珀标记待验证和失败边界。
- **Spacing posture**: 首尾明确聚焦，中间三页按证据密度展开。
- **Spacing anchors**: page margin 48 px; block gap 24 px; column gutter 36 px; corner radius 4 px; body leading 40 px。

## VI. Icon Usage Specification

- **Primary bundled library**: none

| Icon Path | Suitable Scenarios |
| --- | --- |

## VII. Visualization Reference List

| Page | Family | Template | Usage |
| --- | --- | --- | --- |
| P04 | chart | horizontal_bar_chart | 对照x/y/z连续声压半幅宽，说明轴向焦区偏长。 |

## VIII. Image Resource List

| Filename | Dimensions | Ratio | Purpose | Type | Image pattern | Crop Policy | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

不使用图片资源。原始PNG和视觉草案仅作参考；概念图形与数值摘要均为可编辑对象。

## IX. Content Outline

### Part 1: Progress, evidence and next validation

#### Slide 01 - 从架构设想走向体外单点验证

- **Audience move**: 从不清楚项目范围 → 理解双用途研究问题、近期最小目标及当前交付层级。
- **Relationships**: order: 9月建工具 → 10月上旬接序列 → 10月中旬定64元方案 → 10月下旬找证据缺口；contrast: 长期协同目标与近期单点/短线。
- **Composition**: 研究问题与近期目标构成视觉焦点，四段演进形成另一条阅读路径。
- **Title**: 从架构设想，走向体外单点验证
- **Core message**: 已收缩到可验证目标，当前交付是仿真和离线序列证据，材料固化尚待验证。
- **Cover impact**: 以“先把单点做实”为聚焦短语，保留完整原生标题；近期目标与已有工具之间形成清晰联系。
- **Content**:
  - 同一ICE探头，兼顾成像定位与局部超声作用？长期为协同，近期为固定单点→连续短线。
  - 9月：参数化声场、架构比较、暴露指标；10月上旬：原软件核对、离线三模式、独立仿真。
  - 10月中旬：64元奇偶分区、三维k-Wave；10月下旬：扩大域、Qp代理、体外单点方案。
  - 结论：仿真与离线序列可追溯；材料固化仍待验证。
- **Fact IDs**: S01, S03, S05, S07, S12, S13

#### Slide 02 - 已建立可追溯的声学与序列验证工具

- **Audience move**: 从笼统“做了仿真” → 能说清三条工作线、真实连接和缺失的物理环节。
- **Relationships**: link: 离线序列保存MAT中的选定TX → k-Wave；contrast: Rayleigh与离线序列尚未自动贯通；order: 配置与单位 → 软件检查 → 数值结果 → 解释范围；order: 待连接的电声标定 → 吸收/热 → 材料转化 → 双功能实测。
- **Composition**: 三条工作线清楚并列，连接强弱承载真实集成状态，下方展开尚缺物理链。
- **Title**: 已建立可追溯的声学与序列验证工具
- **Core message**: 声学筛选、离线编排和独立传播可复核，物理闭环尚未建立。
- **Content**:
  - 快速筛选 / Rayleigh：阵列、孔径与扫描；覆盖、目标外暴露、均匀性。
  - 离线编排 / Verasonics对象：成像、候选照射、交替三模式；MAT、事件表和参数来源。
  - 独立复核 / k-Wave：读取选定TX；三维传播、网格/域/PML敏感性、Qp代理。
  - 实线为保存MAT选定TX连接，虚线为未自动贯通；配置与单位、软件检查、数值结果、解释范围均可追溯。
  - 电声标定、吸收/热、材料转化与双功能实测待连接。
- **Fact IDs**: S02, S03, S06, S07, S09, S10, S13

#### Slide 03 - 当前64元奇偶方案仅完成离线编排

- **Audience move**: 从混淆历史矩阵/左右分区 → 理解当前线阵、用途约定及离线验证边界。
- **Relationships**: membership: 64元线阵由奇数32元成像TX/RX和偶数32元候选照射TX组成；order: 物理+x阵元顺序；order: 成像 → 切换等待 → 候选照射 → 接收恢复 → 成像；contrast: 软件检查通过与实物流程未验证。
- **Composition**: 连续线阵明确当前拓扑，下方时序与右侧事实互相解释。
- **Title**: 64元奇偶分配，成像与候选照射交替
- **Core message**: 分区和事件编排已完成，声场、成像质量和材料作用需各自验收。
- **Content**:
  - 64个阵元横向排列，标物理+x；奇数32元成像TX/RX、偶数32元候选照射TX，用途为assumed约定且可交换，保留完整映射。
  - 当前64元线阵；历史12×8矩阵为synthetic分支。pitch 0.13 mm，活动间距0.26 mm，existing_code_unverified，尺寸未标定。
  - 43/43离线相关测试为10月12日保存记录，非本轮重跑；VSX/实物流程尚未验证。
  - 交替时序为示意、非比例；等待值待验证；本机模块/许可及探头额定驱动unknown。
  - 结论：离线编排完成，物理性能待分别验证。
- **Fact IDs**: S07, S08, S15, S16, S17, S18

#### Slide 04 - 局部集中存在而空间选择性尚未解决

- **Audience move**: 从“有焦点即能固化” → 理解焦移、长轴向焦区、域外强峰与Qp代理边界。
- **Relationships**: contrast: 目标附近集中与全域峰值稳定性未通过；contrast: 峰压最大点与Qp最大点不同；membership: x/y/z宽度属于同一10月19日fine52工况；link: 负结果决定下一步诊断。
- **Composition**: 左侧局部结果和宽度图，右侧扩大域负结果，底部共同限定模型和Qp解释范围。
- **Title**: 局部声压集中存在，空间选择性仍待解决
- **Core message**: 局部聚焦证据不能替代局部固化能力。
- **Content**:
  - 模型标签：assumed 1 Pa参考源；均匀无损介质；无俯仰透镜；k-Wave 1.4.1；物理标定unknown。
  - 10月19日fine52：目标深度20.00 mm，峰值18.46 mm，偏移1.540 mm；x/y/z连续声压半幅宽0.717/2.894/13.477 mm（约−6.02 dB压力幅度宽度，非强度FWHM）。
  - 两网格公共ROI L2差0.749%，完整收敛未建立；10月22日新基线fine52差0.7514%为另一比较，放备注。
  - 10月22日wide65：前向离轴峰[6.370,0,2.015] mm，比同工况近目标峰高6.76%，半幅交点触边，全域峰值稳定性未通过，成因待诊断。
  - 峰压最大点不等于Qp最大点；限定8×4×18 mm assumed材料盒内，synthetic 1 mm立方目标Qp比例2.160%，不代表固化率或能量效率，且该盒不含浅层离轴峰。
  - 结论：局部集中已有模型证据，材料固化能力待验证。
- **Visualization**: halfwidths — x/y/z连续声压半幅宽对照；数据为0.717、2.894、13.477 mm，来自10月19日fine52结果，chart/horizontal_bar_chart。
- **Native-ready**: halfwidths=yes
- **Fact IDs**: S10, S11, S13, S14

#### Slide 05 - 先形成单点证据再扩展短线与双功能

- **Audience move**: 从待办清单 → 理解有先后依赖的证据门槛、验收对象与当前所需资料。
- **Relationships**: order: 边界与孔径诊断 → 参数与声压标定 → 固定单点材料试验 → 连续短线 → 双功能流程；contrast: 机械移动与电子扫描分别验证；membership: 所需输入包括探头/系统和材料/台架两组。
- **Composition**: 近期单点目标作为强视觉终点，五步路线与资源需求互相支撑。
- **Title**: 先形成单点证据，再扩展为连续短线
- **Core message**: 以有标定、有对照的单点结果决定后续推进。
- **Closing impact**: 以“单点成立，才推进下一步”为收束判断；不增加空白致谢页。
- **Content**:
  - ①边界与孔径：宽域/PML、32/64元受控对照、真实透镜；②参数与声压：额定范围、样品/容器、p(t)与坐标。
  - ③固定单点：SonoInk具体配方、无超声对照、可测材料判据；④连续短线：机械/电子分别验证，评价连续性、宽厚与线外作用；⑤双功能：定位→照射→接收及图像恢复。
  - 所需探头与系统输入：完整型号、额定burst/duty、模块/许可，当前unknown；所需材料与台架输入：配方、厚度/容器、水听器/位移/温度记录条件。
  - 所有路线均是下一步计划，首步表示近期可继续离线工作，不标已完成；不承诺未确认日期，不把材料目标写成既有结果。
- **Fact IDs**: S12, S13, S14, S15, S16, S17, S18

## X. Speaker Notes Requirements

- **Generation**: enabled
- **Filename**: match each SVG filename under notes/
- **Content**: 用最终可见页面写讲稿与转场；完整来源使用H:/print_transducer下绝对路径；标明历史记录未重跑。硬件相关结论引用四手册版本、章节和页码：D00108 Rev.L §1.4 pp8–9（PDF9–10）；D00109 Rev.D §4.5 pp9–10；D00107 Rev.K §4.4.1–4.4.2 p30；D00163 Rev.K §4.3.2 pp24–25、TX.Delay附录A171（PDF310）。不执行硬件操作。
- **Total duration**: 约9分钟，按90/100/100/150/100秒组织。
- **Notes style**: 清楚、正式而自然，先结论再解释证据与局限。
- **Presentation purpose**: 汇报可追溯进展，解释负结果，对齐单点起步的验证路线与资料需求。
