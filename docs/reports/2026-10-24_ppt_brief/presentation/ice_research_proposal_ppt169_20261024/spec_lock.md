<!-- ppt-master-schema: spec-lock/v1 -->
# Execution Lock

## canvas
- viewBox: 0 0 1280 720
- format: PPT 16:9

## communication
- primary_language: zh-CN
- audience: 课题组或导师
- objective: 介绍新课题的需求、可检验问题与研究路线，使听众理解源表示优先级和单点起步的验证门槛，而非将起步仿真理解为材料能力。
- core_message: 探索ICE成像定位与局部超声作用协同，先建立可信声场和体外单点证据，再推进材料成线与双功能流程。
- consumption_mode: balanced

## mode
- mode: custom
- mode_references: instructional, pyramid
- mode_behavior: 按需求、问题、方法、基础、认识、任务和验证递进，每页以明确研究任务或判断起笔；P01—P07主讲、P08—P09答问备份。

## visual_style
- visual_style: custom
- visual_style_references: swiss-minimal, editorial
- visual_style_behavior: 精确对齐、留白和少量大色面组织概念关系，不对称分栏和短注承载解释；深蓝标题、青绿重点、琥珀待验证，固定无衬线字体通过字号粗细分层。

## colors
- background: #FFFFFF
- secondary_bg: #EFF3F7
- primary: #142B45
- accent: #C27B22
- secondary_accent: #008C95
- body_text: #203247
- secondary_text: #516176
- divider: #CBD5DF
- grid: #E2E8EF

## typography
- font_family: Microsoft YaHei, Arial
- title_family: Microsoft YaHei, Arial
- body_family: Microsoft YaHei, Arial
- body: 30
- title: 40
- subtitle: 28
- lead: 28
- annotation: 20
- footnote: 16
- data: 36
- display: 48
- index: 22

## icons
- library: none
- inventory: none

## images
- shallow-field: images/widegrid_shallow.png | source=user | crop=adaptive
- spectrum-audit: images/source_sampling.png | source=user | crop=no-crop

## page_rhythm
- P01: anchor
- P02: dense
- P03: dense
- P04: dense
- P05: dense
- P06: dense
- P07: anchor
- P08: dense
- P09: dense

## page_visualizations
- P08: table/metric_table

## pptx_structure
- mode: flat

## forbidden
- `mask`, `<style>`, `class`, external CSS, `<foreignObject>`, `textPath`, `@font-face`, `<animate*>`, `<set>`, `<script>` / event attributes, `<iframe>`
- HTML named entities in text; write typography as raw Unicode and escape XML reserved characters
