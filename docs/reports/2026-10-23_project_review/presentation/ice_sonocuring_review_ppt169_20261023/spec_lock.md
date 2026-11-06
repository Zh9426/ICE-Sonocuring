<!-- ppt-master-schema: spec-lock/v1 -->
# Execution Lock

## canvas
- viewBox: 0 0 1280 720
- format: PPT 16:9

## communication
- primary_language: zh-CN
- audience: 课题组与导师
- objective: 汇报可追溯进展与数值边界，使听众区分软件、数值和物理证据，并理解单点起步的验证优先级及所需输入。
- core_message: 工具链已形成，目标附近声压集中有模型证据；空间选择性、真实声压、材料固化及双功能流程仍待验证，先取得有标定、有对照的体外单点证据。
- consumption_mode: balanced

## mode
- mode: custom
- mode_references: pyramid
- mode_behavior: 保留五页主题顺序，每页以支持充分的判断开场，接事实和图形，再交代解释边界或下一步依据。

## visual_style
- visual_style: custom
- visual_style_references: swiss-minimal, data-journalism
- visual_style_behavior: swiss-minimal负责精确对齐、大色面与留白；data-journalism负责数值注释、来源行与结果侧栏；固定无衬线字体，用粗细和字号建立层级，颜色表示证据状态。

## colors
- background: #FFFFFF
- secondary_bg: #EFF3F7
- primary: #142B45
- accent: #C27B22
- secondary_accent: #008C95
- body_text: #203247
- secondary_text: #516176
- divider: #CBD5DF
- surface: #F7F9FB
- grid: #E2E8EF

## typography
- font_family: Microsoft YaHei, Arial
- title_family: Microsoft YaHei, Arial
- body_family: Microsoft YaHei, Arial
- body: 28
- title: 42
- subtitle: 30
- lead: 30
- annotation: 20
- footnote: 16
- data: 40
- display: 52
- index: 22

## icons
- library: none
- inventory: none

## page_rhythm
- P01: anchor
- P02: dense
- P03: dense
- P04: dense
- P05: anchor

## page_visualizations
- P04: chart/horizontal_bar_chart

## pptx_structure
- mode: flat

## forbidden
- `mask`, `<style>`, `class`, external CSS, `<foreignObject>`, `textPath`, `@font-face`, `<animate*>`, `<set>`, `<script>` / event attributes, `<iframe>`
- HTML named entities in text; write typography as raw Unicode and escape XML reserved characters
