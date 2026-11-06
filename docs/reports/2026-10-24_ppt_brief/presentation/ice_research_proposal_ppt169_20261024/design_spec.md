<!-- ppt-master-schema: design-spec/v1 -->
# ICE Research Proposal - Design Spec

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | ICE Research Proposal |
| Canvas Format | ppt169, 1280 × 720 |
| Page Count | 9; P01—P07主汇报，P08—P09技术备份 |
| Primary Language | zh-CN |
| Target Audience | 课题组或导师，了解一个刚起步课题的需求、问题、研究路径与验证计划。 |
| Communication Intent | 先建立研究设想与三个可检验问题，再用起步探索解释近期优先级，最后对齐体外验证门槛与所需条件。 |
| Desired Audience Outcome | 理解课题希望解决什么、已有证据到哪里、下一步为什么先验证源表示，以及如何依次进入单点、短线与双功能流程。 |
| Core Message / Ask / Action | 希望探索ICE成像定位与局部超声作用协同，先建立可信声场和体外单点证据，再推进材料成线与双功能流程；当前仍是起步探索。 |
| Delivery Context | 7页中文主讲约9—11分钟；2页备份只作答问，不默认讲完。 |
| Artifact Afterlife | 新可编辑PPTX及逐页讲稿，含原始来源、数值口径与硬件手册；原5页产物保留。 |
| Reading Mode | balanced |
| Content Strategy | 按2026-10-24新制作说明书9页内容组织；研究逻辑和计划为主，最新结果只支撑优先级；保留假设、比较预算与未实现项。 |
| Design Style | 问题驱动，见analysis/design_decisions.md的三方向与选择理由。 |
| AI Image Acquisition Path | not applicable |
| Generation Mode | continuous |
| Spec Refinement | disabled |
| Speaker Notes | enabled — explicit prior user delegation, final production decision |
| Custom Animations | disabled — delegated final production decision, all-motion scope |
| Narration Audio | disabled — delegated final production decision |
| Created Date | 2026-10-24 |

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | PPT 16:9 |
| Dimensions | 1280 × 720 |
| viewBox | `0 0 1280 720` |
| Margins | 左右48 px，顶部32 px，底部24 px |
| Content Area | x=48…1232, y=32…696 |

## III. Visual Theme

### Theme Style

- **Mode**: custom
- **Mode References**: instructional, pyramid
- **Mode Behavior**: instructional负责需求—问题—方法—基础—认识—任务—验证的研究递进，pyramid负责每页用清楚的判断或研究任务起笔；严格保留七主讲加两备份的顺序。
- **Visual style**: custom
- **Visual Style References**: swiss-minimal, editorial
- **Visual Style Behavior**: swiss-minimal负责精确对齐、留白与少量大色面，editorial负责不对称分栏、短注和来源；深蓝标题、青绿研究重点、琥珀待验证；固定无衬线字体，以字号和粗细建立层级。
- **Theme**: 从定位到局部作用的路径作为概念母题，实线表达已连接离线基础，虚线表示拟建立物理环节；根据页面任务改变尺度与结构。
- **Tone**: 新课题、问题明确、结果审慎、计划可检验。

### Color Scheme

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | #FFFFFF | 主画布 |
| Secondary background | #EFF3F7 | 研究或任务上下文 |
| Primary | #142B45 | 标题与主结构 |
| Accent | #C27B22 | 拟验证、限制与未知 |
| Secondary accent | #008C95 | 重点与已有离线连接 |
| Body text | #203247 | 正文 |
| Secondary text | #516176 | 图注与来源 |
| Divider | #CBD5DF | 分隔和轻边界 |
| Grid | #E2E8EF | 数值表规则线 |

## IV. Typography System

### Font Plan

| Role | Character (Reference) | Primary | English if non-English | Fallback tail |
| --- | --- | --- | --- | --- |
| Title | 清楚、有分量的无衬线 | Microsoft YaHei | Arial | sans-serif |
| Body | 中性易读无衬线 | Microsoft YaHei | Arial | sans-serif |

- **Title stack**: Microsoft YaHei, Arial
- **Body stack**: Microsoft YaHei, Arial

### Font Size Hierarchy

| Purpose | Anchor Size (px) |
| --- | ---: |
| Body | 30 |
| Title | 40 |
| Subtitle | 28 |
| Lead | 28 |
| Annotation | 20 |
| Footnote | 16 |
| Data | 36 |
| Display | 48 |
| Index | 22 |

## V. Layout Principles

### Deck-wide Direction

- **Hierarchy direction**: 页面任务或认识 → 主图关系 → 三个以内信息点 → 简短结论与来源。
- **Composition tendency**: 首页对象示意，问题递进、总路线、简洁基线、同尺度声场对照、任务依赖和阶段门槛各自成页；备份容纳数值。
- **Cross-page continuity**: 页眉、来源和主讲/备份标记一致；可复用定位—作用路径，随页面语义变化。
- **Spacing posture**: 主讲疏朗、备份较密，不缩字容纳报告。
- **Spacing anchors**: page margin 48 px; block gap 24 px; column gutter 36 px; corner radius 4 px; body leading 44 px。

## VI. Icon Usage Specification

- **Primary bundled library**: none

| Icon Path | Suitable Scenarios |
| --- | --- |

## VII. Visualization Reference List

| Page | Family | Template | Usage |
| --- | --- | --- | --- |
| P08 | table | metric_table | 两配置在相同52 μm网格上的测点指标以及65→52 μm分区域原始压力场差。 |

## VIII. Image Resource List

| Filename | Dimensions | Ratio | Purpose | Type | Image pattern | Crop Policy | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| widegrid_shallow.png | 1980×1440 | 1.375 | P05同源端预算的52 μm两配置声场 | Scientific result | 右列两图原生裁切，左右同尺度对照，共用原始色条；标签与坐标原生重绘 | adaptive | user | Existing | F1原图右列上偶数32元、下全64元；仅以原生图片裁切重排，热图像素、白圈和共同颜色映射不改；裁出数据区域后原图x/z坐标与Pa量纲用原生标签还原；全64为synthetic离线对照 | none | local |
| source_sampling.png | 1260×720 | 1.75 | P09展示连续矩形参考与65/52 μm离散源谱 | Scientific audit | 完整审计图居左，右侧简述线索与拟验证方法 | no-crop | user | Existing | F3源空间谱原图，6 MHz代表单元；源表示审计，非实物指向性、非传播结果 | none | local |

## IX. Content Outline

### Part 1: Seven-slide main presentation

#### Slide 01 - 课题设想

- **Audience move**: 从陌生课题 → 理解对象、基本设想和体外近期范围。
- **Relationships**: order: 成像定位 → 候选照射与局部材料响应；link: 探头与体外样品目标；contrast: 长期协同与近期单点/短线。
- **Composition**: 探头—样品概念示意与三条研究范围相互解释。
- **Title**: ICE探头成像与局部超声作用协同研究
- **Core message**: 探索成像定位与局部作用协同，近期从体外固定单点起步。
- **Cover impact**: 以“先定位，再研究局部作用”为清楚的研究设想；同页保留题目和副标题，不另加封面。
- **Content**:
  - 副标题：研究思路、初步探索与验证计划；研究对象是现有ICE探头的阵元与时序资源。
  - 先定位目标，再研究局部照射和材料响应；近期为体外固定单点与连续短线。
  - 图题明确“研究设想，非已实现系统”；只画体外样品，未知材料/探头物理参数留备注。
- **Fact IDs**: E7, E8

#### Slide 02 - 三个可验证问题

- **Audience move**: 从应用愿景 → 分辨声学、材料、流程三个可检验问题。
- **Relationships**: order: 声学问题 → 材料问题 → 流程问题；contrast: 前层证据不能代替后层。
- **Title**: 研究目标：先回答三个可验证的问题
- **Core message**: 用可重复的测量与对照决定是否进入下一阶段。
- **Content**:
  - 声场能否局部可控？同时评价焦区聚集和目标外暴露。
  - 能否产生局部材料作用？明确配方、标定和可测材料判据。
  - 能否扩展成线与双功能？分别验证扫描、定位和成像恢复。
  - 共同原则：目标与非目标一起评价，不预设最优分区；创新点仅是拟探索问题。
- **Fact IDs**: E7, E8

#### Slide 03 - 总体研究路线

- **Audience move**: 从问题清单 → 理解由可信声场到物理验证的证据依赖。
- **Relationships**: order: 参数约束核实 → 可信声场/配置筛选 → 标定/材料验证 → 扫描成线 → 双功能评价；link: 验证结果回指参数与模型作修正；contrast: 已有离线前端与拟建物理路径。
- **Title**: 研究路线：从可信声场走向材料验证
- **Core message**: 软件是工具，真实输出与材料输入到位后才能讨论实际作用。
- **Content**:
  - 五步总路线；前两步下标“起步探索：离线序列/声场基线”。
  - 计算：控制几何、源表示、活动配置与预算；物理：拟验证声吸收—温度—材料路径，SonoInk为待明确方向；验证：固定单点先行。
  - 拟建立物理关联与实测用虚线，反馈箭头写“修正模型”，不宣称闭环已实现。
- **Fact IDs**: E1, E7, E8

#### Slide 04 - 起步工作

- **Audience move**: 从不了解已有基础 → 理解当前离线基线与单次发射边界。
- **Relationships**: membership: 64元单行线阵按物理+x由奇数成像和偶数候选照射组成；order: 成像 → 候选照射 → 接收恢复；link: 离线序列的选定单次发射 → 独立三维声场评价。
- **Title**: 起步工作：建立序列与独立声场基线
- **Core message**: 当前是离线探索，真实声压、材料作用与完整流程尚待验证。
- **Content**:
  - 梳理64元线阵，保留奇偶离线基线；当前用途为assumed约定，配置仍需比较。
  - 选定单次发射接入独立三维声场计算与检查；从目标集中开始追踪焦移和浅层暴露。
  - 时序为有限时间交替示意，不表示同时照射与接收；不显示测试计数或上机参数。
- **Fact IDs**: E9, E10

#### Slide 05 - 新的初步认识

- **Audience move**: 从将离轴场视作单一边界问题 → 理解配置趋势与浅层可信度共同决定下一步。
- **Relationships**: contrast: 偶数32元与全64元synthetic离线候选在同一52 μm网格、相同B预算下对照；link: 配置影响及源表示敏感 → 近期计划；contrast: 原测点改善与整体问题未解决。
- **Title**: 初步认识：配置影响离轴场，源表示待验证
- **Core message**: 初步结果用来确定下一步，不能提前宣布方案可用。
- **Content**:
  - 配置值得研究：全64元在原离轴测点保持改善趋势；有限边界改变未明显改变原结构。
  - 模型仍需验证：偶数32元近源/浅层幅值对网格敏感，先处理源表示。
  - 问题尚未解决：焦前偏移、轴向选择性与材料作用仍需独立验证。
  - 图注保留：52 μm；相同源端代理预算B，非实际功率；assumed未标定源、均匀无损、无透镜；颜色为各点时间最大绝对声压，单位Pa；全64为synthetic离线对照。
- **Images**: widegrid_shallow.png右列两配置和同一原始色条，原生裁切重排；共同尺度和图例，不各自归一化，不命名真实栅瓣。
- **Fact IDs**: E1, E2, E3, E5, F1

#### Slide 06 - 近期任务

- **Audience move**: 从泛化开发清单 → 明确数值可信度、配置研究和并行资料准备的先后。
- **Relationships**: order: 验证源表示/浅层网格敏感 → 受控比较配置、焦深和俯仰模型；link: 探头/材料/计量输入与计算任务并行汇入后续标定和材料验证。
- **Title**: 近期计划：先可信，再筛选照射配置
- **Core message**: 先排除数值与口径问题，再讨论物理改进。
- **Content**:
  - 先做：源表示与浅层敏感性 → 能说明适用范围的声场基线。
  - 接着：活动配置、焦深与俯仰模型 → 目标集中/目标外暴露的受控对照。
  - 并行准备：探头输出、样品/容器、SonoInk具体配方 → 标定/材料输入清单。
  - 带限源、焦深补偿、透镜及声热模型均为拟开展；保持物理目标20 mm，未知输入仍unknown；未定工期。
- **Fact IDs**: E1, E2, E7

#### Slide 07 - 分阶段验证

- **Audience move**: 从计算路线 → 明确单点、短线和双功能的进入门槛与资源需求。
- **Relationships**: order: 固定单点 → 连续短线 → 双功能流程；parent: 短线有机械移动/电子逐点扫描两个分别验证的候选支路；membership: 资料包括探头/系统、计量、材料/样品/容器/运动条件。
- **Title**: 验证计划：单点 → 短线 → 双功能
- **Core message**: 用最小的体外单点证据决定下一步。
- **Closing impact**: 以“单点证据决定下一步”收束，保留路线供讨论，不增加致谢页。
- **Content**:
  - 固定单点：测实际焦区、材料对照和目标外影响；进入门槛是实际声场与材料判据。
  - 连续短线：单点成立后，分别验证机械移动与电子扫描；关注重复性、连续性、宽厚和线外作用。
  - 双功能：成像定位、照射和接收/图像恢复；进入门槛包括定位与恢复。
  - 待补探头/系统约束、声压测量、明确配方与样品/容器/运动条件；计划语气，不给驱动处方或未知日期。
- **Fact IDs**: E7

### Part 2: Optional technical backup, not part of the main talk

#### Slide 08 - 技术备份A

- **Audience move**: 从定性认识 → 核对同网格测点比和分层场差的具体口径。
- **Relationships**: contrast: 偶数32元与全64元；contrast: 测点Qp比和区域原始压力场L2是不同量。
- **Title**: 备份A｜近期对照的数值口径与限制
- **Core message**: 原测点改善、分区场差通过与所有峰位稳定是不同结论。
- **Content**:
  - 表1为52 μm同网格、同B：离轴/主焦区测点Qp比93.899%对0.0623%；深层峰深18.460对18.460 mm；目标/主焦区测点Qp比0.9164对0.9164。
  - 表2为65→52 μm原始压力场L2，细网格插值至粗网格：0<z<2 mm为11.681%/2.463%；2≤z<5 mm为6.893%/1.157%；z≥5 mm为0.572%/0.474%。
  - proposed 5%场差诊断：32元近源/浅层未通过，全64这些场差通过，但峰位未全通过；两网格不等于完整收敛。
  - Qp仅压力平方时间积分代理；比值非能量占比、全空间旁瓣或材料效率；实际测点差异与有限边界检查细节放备注，不使用旧2.160%作新结果。
- **Visualization**: point-metrics — 测点指标比较表；grid-errors — 分区域原始压力场L2比较表；table/metric_table。
- **Native-ready**: point-metrics=yes; grid-errors=yes
- **Fact IDs**: E2, E3, E5

#### Slide 09 - 技术备份B

- **Audience move**: 从“换源算法就会改善” → 理解源谱线索、尚未完成替换以及验证要求。
- **Relationships**: link: 细阵元空间离散 → 大角度源谱变化 → 拟验证带限源；contrast: 解析源表示审计与实物指向性/传播结果。
- **Title**: 备份B｜源表示为何成为优先项
- **Core message**: 面积守恒不足以保证角谱一致，带限源及其传播仍待验证。
- **Content**:
  - 源码宽0.11 mm矩形单元在65/52 μm网格上占约1.69/2.12格，尺寸existing_code_unverified。
  - F3保留解析连续矩形参考与两离散曲线，明确6 MHz代表单元审计，不是实物指向性。
  - 75°示例偏差−18.39%/−7.38%；不等于实物声压误差，不能解释所有传播差异。
  - 带限源替换与传播尚未完成；拟核对几何、支撑/截断、面积/尺度及网格稳定性，不保证离轴场下降。预算B仅源端代理，定义与单位放备注。
- **Images**: source_sampling.png完整显示，附原生中文标题与结论。
- **Fact IDs**: E2, E4, F3

## X. Speaker Notes Requirements

- **Generation**: enabled
- **Filename**: match each SVG filename under notes/
- **Content**: 逐页根据最终SVG写自然讲稿与转场；主讲7页约550秒，备份按答问独立使用。完整来源使用H:/print_transducer与F:/xwechat_files绝对路径；说明读取保存资料未重跑求解。第4/7页引用四手册版本页码：D00163 Rev.K §4.3.2 pp24–25、TX.Delay A171/PDF310；D00107 Rev.K §4.4.1–4.4.2 p30；D00108 Rev.L §1.4 pp8–9/PDF9–10；D00109 Rev.D §4.5 pp9–10。保留assumed/synthetic/unknown、B与Qp定义、物理/数值证据边界，不给上机处方。
- **Total duration**: 主讲约9—11分钟；两页技术备份不计入。
- **Notes style**: 新课题介绍，清楚自然，研究计划占主导。
- **Presentation purpose**: 用起步探索说明研究问题和验证优先级，形成单点—短线—双功能的证据路径。
