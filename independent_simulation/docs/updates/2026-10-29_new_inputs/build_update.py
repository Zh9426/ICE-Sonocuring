"""Summarize human-supplied requirements and existing evidence; no new simulation."""
from pathlib import Path
import csv,hashlib,html,json,shutil,sys
from PIL import Image,ImageDraw
from pypdf import PdfReader
import pypdfium2 as pdfium
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,PageBreak

sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent
MOD=HERE.parents[2]
ROOT=MOD.parent
OUT=MOD/'results/research_update_2026-10-29';OUT.mkdir(parents=True,exist_ok=True)
QA=OUT/'qa';QA.mkdir(exist_ok=True)
EV=HERE/'evidence';EV.mkdir(exist_ok=True)
TITLE='ICE双功能课题新信息与工作进度整合'
PDF=OUT/(TITLE+'_20261029.pdf')
shots=[
('E01','codex-clipboard-d2842ec4-d2f1-4a4e-bc56-c88616248707.png','诊断探头限值及超额驱动的口头判断'),
('E02','codex-clipboard-51b16b6f-7041-48d4-93ad-ebdd1ab82f50.png','传统介入路径与简化目标'),
('E03','codex-clipboard-39b3b50d-4c0a-423c-97eb-3c8f4c0cbb15.png','传统封堵器展开回收难点及手术分级说法'),
('E04','codex-clipboard-5ecbb44e-0fdf-422a-861e-39a5aefbc10b.png','临时球囊挡口及适形材料设想'),
('E05','codex-clipboard-7ba45fba-8706-4ffb-97ce-be9606ec3795.png','球囊撤回 PTFE表面及固化后保持设想'),
('E06','codex-clipboard-cba8cf83-bfa3-4641-9ba3-924339fd647b.png','对方体外FUS路线 CT规划及知识产权述称'),
]
manifest=[]
for sid,name,meaning in shots:
    src=Path('C:/Users/Zh89/AppData/Local/Temp')/name;dest=EV/(sid+'.png');shutil.copy2(src,dest)
    manifest.append({'id':sid,'source':str(src),'copy':str(dest.relative_to(HERE)),'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'meaning':meaning,'evidence_status':'user-provided communication; not independent performance evidence'})
(EV/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

sources={
'S01':('最新宽域结论','../../findings_2026-10-24.md'),
'S02':('宽域完整结果','../../widegrid_2026-10-24.md'),
'S03':('体外单点与短线计划','../../ice_bench_poc_plan_2026-10-21.md'),
'S04':('奇偶序列说明','../../../../docs/verasonics/linear64_oddeven_2026-10-12.md'),
'S05':('源表示尚未实现的验证记录','../../../results/kwave_widegrid_2026-10-24/validation.json'),
'S06':('三维HTML的实现与验证边界','../../widefield_viewer_2026-10-24.md'),
'W01':('2025 SCAI/HRS临床指南','https://www.hrsonline.org/resource/2025-scai-hrs-clinical-practice-guidelines-on-transcatheter-left-atrial-appendage-occlusion/'),
'W02':('FDA Ultrasound Imaging','https://www.fda.gov/radiation-emitting-products/medical-imaging/ultrasound-imaging'),
'W03':('Kuang等 Science 2023原始研究 DOI','https://doi.org/10.1126/science.adi1563'),
'W04':('Kuang等原始研究可读全文','https://www.statnews.com/wp-content/uploads/2024/02/madness-24-2.pdf'),
'W05':('同团队DAVP方法论文 在线2025 卷期2026','https://www.nature.com/articles/s41596-025-01258-1'),
'W06':('PTFE与水凝胶界面实验示例','https://pmc.ncbi.nlm.nih.gov/articles/PMC12759228/'),
}
# Resolve source paths relative to this note, independent of the PDF location.
for sid,(label,ref) in list(sources.items()):
    if not ref.startswith('https:'):
        sources[sid]=(label,str((HERE/ref).resolve()))

pdfmetrics.registerFont(TTFont('YH','C:/Windows/Fonts/msyh.ttc'))
pdfmetrics.registerFont(TTFont('YHB','C:/Windows/Fonts/msyhbd.ttc'))
pdfmetrics.registerFontFamily('YH',normal='YH',bold='YHB',italic='YH',boldItalic='YHB')
S={
'title':ParagraphStyle('title',fontName='YHB',fontSize=22,leading=31,spaceAfter=12,wordWrap='CJK'),
'h':ParagraphStyle('h',fontName='YHB',fontSize=17,leading=25,spaceAfter=12,wordWrap='CJK'),
'p':ParagraphStyle('p',fontName='YH',fontSize=10.4,leading=17,spaceAfter=10,wordWrap='CJK',textColor=colors.HexColor('#193047')),
'small':ParagraphStyle('small',fontName='YH',fontSize=8.6,leading=13.5,spaceAfter=8,wordWrap='CJK',textColor=colors.HexColor('#526879')),
'cell':ParagraphStyle('cell',fontName='YH',fontSize=9,leading=14.2,wordWrap='CJK'),
'head':ParagraphStyle('head',fontName='YHB',fontSize=9,leading=14.2,wordWrap='CJK',textColor=colors.white),
}
flow=[];md=[];titles=[]
def page(title):
    if flow:flow.append(PageBreak());md.append('\n---\n')
    titles.append(title);flow.append(Paragraph(html.escape(title),S['title' if len(titles)==1 else 'h']));md.append('# '+title+'\n')
def p(text,small=False):
    flow.append(Paragraph(html.escape(text).replace('\n','<br/>'),S['small' if small else 'p']));md.append(text+'\n')
def table(headers,rows,widths):
    rows=[headers]+rows
    data=[[Paragraph(html.escape(str(v)),S['head' if i==0 else 'cell']) for v in row] for i,row in enumerate(rows)]
    t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT');t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#16465b')),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#f0f5f7')]),('GRID',(0,0),(-1,-1),.35,colors.HexColor('#d6e2e8')),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]));flow.extend([t,Spacer(1,11)])
    md.extend(['|'+'|'.join(headers)+'|','|'+'|'.join(['---']*len(headers))+'|']+['|'+'|'.join(str(v).replace('\n','；') for v in row)+'|' for row in rows[1:]]+[''])

page(TITLE)
p('2026年10月29日  |  新研究输入与现存证据对照',True)
p('本次最重要的澄清是：截图描述的是合作方既有的体外聚焦超声路线，用户已明确确认，自己的主线仍继续研究ICE成像与照射双功能。新增信息用于补全应用需求、设置对照和调整验证优先级，不代表当前课题改用体外声源。')
p('系统目标可概括为：在临时限制材料外流的条件下，将可注射声响应材料置于目标腔体，利用超声形成适形固化体，撤出临时工具后评估封堵和保持效果。上述是对方描述的研究设想；尚无本项目实测证明完整流程成立。')
table(['路线','来源与角色','当前处理'],[
['本课题主线','ICE负责成像定位，并研究由同一探头承担局部照射','保留64线阵及奇偶交替研究；全64为离线配置对照，最终活动方式未定'],
['合作方既有路线','体外聚焦换能器承担固化，术前CT用于几何/声源位置规划','作为应用背景和性能参照；其设备、参数及成功记录需获取'],
['共同应用接口','注射材料、临时挡口球囊、固化体与组织/球囊界面、撤出与保持','分解为可测工作包；不能由声压图推断材料或封堵成功'],
],[94,203,202])
p('进度基准：本次检查到的最新数值传播记录仍为10月24日宽域52 μm结果；10月29日本轮只整理截图、复核来源和形成路线说明，没有新增求解、硬件发射、材料实验或许可操作。',True)
p('已保留6张原始截图并记录SHA-256。截图中的建议和个人判断仅作资料，不构成实验结果、法定操作资质依据或放宽硬件限制的授权。',True)

page('01 新信息明确了哪些系统细节')
table(['证据','沟通中明确的方案描述','尚需确认的内容'],[
['E01','对方认为诊断设备的输出控制可能限制探头用途，提出提高驱动的可能性','该意见没有给出本支探头额定电压、burst、占空比、电流或声压标定，不能据此修改上限'],
['E02-E03','传统封堵涉及导管输送、定位、展开和可能的重定位；希望用液态材料适形固化简化器械匹配','简化程度、是否改变材料/球囊进入路径、跨房间隔需求及实际操作步骤均未证实'],
['E04','定制球囊旨在临时挡住左心耳开口、限制打印期间材料流出；与长期留置封堵器的功能区分','球囊支撑/定位方式、开口覆盖、密封、注射通道和撤出空间未给出设计数据'],
['E05','固化后球囊收拢撤回；拟采用PTFE表面促进脱离；固化体预期与腔体形状结合并保持','对具体材料的黏附/脱离、残留、破损及固化体稳定性都待试验，不把几何嵌合写成已测胶黏强度'],
['E06','合作方既有固化声源为体外聚焦换能器，以术前CT帮助寻找可放置位置','外部声源型号、频率、焦距、穿透路径、测量结果以及与ICE的配准/同步均unknown'],
['E06','对方述称已有3项专利、2项软著','题名、编号、权属、公开文本及技术范围未知；不能写成本项目已取得的成果'],
],[56,235,208])
p('用户本轮直接确认：体外FUS为对方既有路线，ICE双功能继续研究。此条用于确定课题定位；其余截图内容按“沟通资料”记录，不自动升级为已验证事实。')
p('液体可适应复杂腔体，是应用动机；“一种材料适用于所有心耳形状”尚无证据。需要定义拟覆盖的几何、容积、流动和固化时间范围后逐步验证。',True)

page('02 现有工作在新背景下的意义')
table(['现有工作及保存结果','现在支撑什么','还不能证明什么'],[
['64线阵SetUp、成像/照射/交替三模式；10月12日相关软件测试43/43','为ICE双功能的发射掩码、延时、事件和恢复等待建立离线基础','尚未运行VSX/实物；不能证明可替代合作方体外治疗声源'],
['独立k-Wave与20 mm单点；52 μm主焦峰深18.460 mm，轴向压力半幅宽约13.48 mm','回答导管附近假设声场能否局部集中；指出焦移与轴向选择性问题','不能直接代表实际解剖距离、材料固化范围或封堵形状'],
['有限PML与扩域控制；公共场差约0.077%/0.022%，原浅层峰稳定','缩小原浅层离轴结构的边界成因解释范围','不等于所有边界排除或完整收敛'],
['32/64等源端预算对照；全64对原离轴测点的改善在52 μm保留','提示ICE活动配置可能影响目标外暴露；最终不必预设固定32元最优','数量、间距、填充率等一起改变，未完成单因素归因或硬件验证'],
['32元近源/浅层65→52 μm场L2差约11.68%/6.89%；源谱显示离散表示差异','为继续验证源表示建立依据；保证后续器械场景使用可信的计算基线','空间带限源替换与传播尚未实现；不能把误差线索当作已解决'],
['Qp、区域积分与三维HTML；Qp不是热量，max_t|p|不是瞬时快照','已有输出/审计方法可迁移到后续真实参数和球囊样品场景','当前均匀无损、无球囊/材料/组织模型，不支持完整原位封堵预测'],
],[219,143,137])
p('结论：已有工作仍属于ICE双功能路线的声学与序列可行性底座。合作方体外FUS提供系统目标与参照，不能用其材料成功来替代本支ICE的电声能力证据。[S01-S06]')

page('03 需要校正的四类解释')
p('第一，材料原位固化是目标，手术降级是尚待证明的潜在效益。对方关于“四级”“只有主任”等属于口头描述，不作为法定分级或资质结论。体外声源也不会自动消除材料输送、球囊布置或其他介入需求。')
p('第二，静态CT可以帮助几何规划，但不等于实时目标定位或CT到ICE/声束坐标配准。2025 SCAI/HRS指南区分术前CT/TEE与术中TEE/ICE。本课题应研究实际定位误差、运动范围、更新延迟和恢复时间；截图“不用太准，因为心脏会跳”不能成为误差容许依据。[W01]')
p('第三，PTFE表面是低黏附设计候选，不能写为对任何材料都绝对不粘。公开PTFE/水凝胶界面实验也显示黏附与材料和表面处理有关，不能替代本项目配方测试。应分别评价材料对球囊的释放和对腔壁的保持；“贴合”“几何嵌锁”“化学黏附”需分开描述。[W06]')
p('第四，“不烧坏压电陶瓷即可提高功率”不足以建立硬件或生物适用范围。FDA资料讨论热学和机械效应；Vantage手册还明确系统保护不等于探头或实际声输出合格。本次不调整任何限值或驱动处方。[W02]')
table(['本次核对的原始手册','章节与关键边界'],[
['D00108 Rev. L Product Specification','§1.4，印刷8页/PDF9页：高功率选件需另核实；软件自保护主要保护系统，不保护探头过热或限制实际声输出'],
['D00107 Rev. K System User Manual','§4.4.1-4.4.2，第30页：成像电源用于短burst、低duty；Profile5扩展发射为选项'],
['D00163 Rev. K Sequence Programming Manual','§12.0-12.1，第95-96页：最严格的Trans/TPC限值优先；切换与电源恢复需留足时间'],
['D00109 Rev. D Initial Setup Instructions','§4.5，第9页：自检与日志用于设备就绪证据；本次未执行'],
],[203,296])

page('04 将下一阶段拆成可验证工作包')
table(['工作包','具体需要形成的证据','与现有工作的连接'],[
['A 可信声源与场分布','带限源几何/支撑/尺度检查、同网格源对照及宽域网格复核；保留失败结果','优先延续现有诊断，先稳定近源/浅层，再处理焦深与焦宽'],
['B 本支ICE的电声能力','完整型号与来源明确的允许驱动；实测p(t)、实际焦区、探头状态与输出不确定度','建立电气请求到声压的联系；不把软件电压上限等同长期照射能力'],
['C 材料单点到短线','确定实际配方/批次、触发机制、反应判据、样品几何；目标内及目标外反应和重复性','保留现有体外单点→短线最小验收，不因应用设想直接跳到心内封堵'],
['D 球囊与材料界面','注射/暂时限流、固化前外流、涂层完整性、固化后脱离/撤出、残留及固化体保持','新增独立台架工作；先用明确模型腔体测试，不假定球囊仅挡口就能密封'],
['E ICE定位与交替恢复','实际坐标、照射前后图像、接收饱和/振铃/噪声与恢复判据；条件相关等待时间','将SetUp中的assumed等待转化为有测量依据的参数，再评价运动条件'],
['F 对照与系统整合','获取合作方体外FUS的真实基线、材料条件和几何；在相同评价任务上建立可比指标','参照已有路线评价ICE双功能的收益与限制；不直接比较不同功率口径或不同材料结果'],
],[91,255,153])
p('对长期原位目标，还需要动态腔体、容器/球囊/组织声学边界、流动、材料留存及撤出后的封闭性等证据。静态声压图和Qp代理只能支撑前序筛选，不能代替长期留置、安全或临床有效性验证。')
p('阶段目标与长期应用分开：近期仍是可信声场→本支ICE标定→静态材料单点/短线；球囊和界面可并行做台架资料与样品准备。上述为建议工作包，本次没有执行新实验或承诺时间表。',True)

page('05 优先补齐的输入与汇报口径')
table(['输入','目前状态与所需资料'],[
['ICE探头及适配','完整型号后缀、阵元尺寸/俯仰透镜、复阻抗与额定burst/duty、温度和接收保护依据仍unknown'],
['系统','实际Vantage NXT型号、模块、许可、软件版本及自检记录需独立核实'],
['材料','当前实际配方是否对应SonoInk/DAVP文献未知；需要配方/批次、流变、声学吸收/散射、反应与后处理资料'],
['临时球囊','型号/图纸、尺寸范围、布置与支撑方式、注射通道、PTFE涂层工艺及回收方式未知'],
['合作方参考实验','体外FUS型号、频率/焦距/口径、实测波形、扫描/固化条件、样品及原始结果未提供'],
['成像与坐标','ICE在对方系统中是否参与术中定位、与FUS是否共坐标及同步，截图均未明确回答'],
['知识产权','3专利2软著的题名、编号、权属及公开文件尚缺，先作为对方述称记录'],
],[113,386])
p('建议汇报表述：我们的课题继续研究ICE成像与局部照射双功能。合作方既有体外FUS原位固化路线，为本课题提供材料封堵场景和系统参照；新明确的临时球囊承担挡口、限制材料外流及固化后撤回的角色。我们已完成离线序列和三维声场诊断，目前优先解决源表示与浅层数值稳定性，再建立本支ICE的电声、材料及接收恢复证据。')
p('公开研究边界：Kuang等Science 2023已有经导管将sono-ink置入离体山羊心左心耳、经12 mm心壁聚焦固化的概念验证（图4E-F）；这不是本项目实测，也不证明截图中的定制球囊流程、活体跳动条件或本支ICE已可实现。2025在线的方法论文进一步描述FUS与sono-ink技术，但不能假定是本项目配方。[W03-W05]')

page('06 来源与本轮完成范围')
p('截图证据保存在本文同目录evidence/，没有裁剪、改写图中文字或将对方观点当作操作指令；SHA-256见manifest.json。')
table(['编号','截图内容'],[[sid,meaning] for sid,_,meaning in shots],[48,451])
for sid,(label,ref) in sources.items():
    # PDF embeds clickable references; Markdown retains plain source links.
    href=ref if ref.startswith('https:') else Path(ref).as_uri()
    flow.append(Paragraph(f'{sid}  <link href="{html.escape(href,quote=True)}" color="#096d78">{html.escape(label)}</link>',S['small']))
    md.append(f'- {sid} [{label}]({ref.replace(chr(92),"/")})')
p('本轮已完成：六张截图归档与来源核对、用户主线确认、现有阶段结果复核、四份原始手册相关章节回查，以及公开文献/指南核验。未新增仿真、材料试验、上机发射或临床验证；本轮不是对专利新颖性或临床操作资质的审查。',True)

def hf(canvas,doc):
    canvas.saveState();canvas.setFont('YH',8);canvas.setFillColor(colors.HexColor('#526879'))
    canvas.drawString(48,814,'ICE-Sonocuring / 新输入与课题工作整合');canvas.drawString(48,27,'2026.10.29  |  研究输入归档与阶段说明');canvas.drawRightString(547,27,f'{doc.page:02d}');canvas.restoreState()
doc=SimpleDocTemplate(str(PDF),pagesize=(595.276,841.89),leftMargin=48,rightMargin=48,topMargin=50,bottomMargin=45,title=TITLE,author='')
doc.build(flow,onFirstPage=hf,onLaterPages=hf)
MD=HERE/(TITLE+'_20261029.md');MD.write_text('\n'.join(md),encoding='utf-8')
pdf=pdfium.PdfDocument(str(PDF))
for i in range(len(pdf)):pdf[i].render(scale=1.4).to_pil().save(QA/f'page-{i+1:02}.png')
sheet=Image.new('RGB',(3*314+16,((len(pdf)+2)//3)*452+16),'#e6edf2');draw=ImageDraw.Draw(sheet)
for i in range(len(pdf)):
    im=Image.open(QA/f'page-{i+1:02}.png');im.thumbnail((298,422));x=16+(i%3)*314;y=16+(i//3)*452;sheet.paste(im,(x,y));draw.text((x,y+424),str(i+1),fill='black')
sheet.save(QA/'contact_sheet.png')
reader=PdfReader(PDF);alltext='\n'.join(p.extract_text() for p in reader.pages);(QA/'readback.txt').write_text(alltext,encoding='utf-8')
missing=[sid for sid,(_,ref) in sources.items() if not ref.startswith('https:') and not Path(ref).exists()]
checks={'pages':len(reader.pages),'planned_pages':len(titles),'screenshots':len(manifest),'screenshot_hashes_match':all(hashlib.sha256((HERE/m['copy']).read_bytes()).hexdigest()==m['sha256'] for m in manifest),'missing_local_sources':missing,'user_confirmed_mainline':'ICE dual function continues; external FUS is collaborators existing route','new_solver_or_hardware_runs':False,'visual_review':'pending','pdf':str(PDF),'markdown':str(MD),'text_chars':len(alltext)}
(QA/'delivery_checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(checks,ensure_ascii=False))
