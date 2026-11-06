"""Package existing evidence and typeset a dated project review; never runs solvers."""
from pathlib import Path
import csv, hashlib, html, json, shutil, sys, zipfile
from PIL import Image, ImageDraw, ImageFont
from pypdf import PdfReader
import pypdfium2 as pdfium
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image as RLImage, Table, TableStyle, PageBreak, KeepTogether

sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
FIG=HERE/'figures'; DATA=HERE/'evidence'; QA=HERE/'qa'
for p in [FIG,DATA,QA]: p.mkdir(parents=True,exist_ok=True)
OUT=ROOT/'output/pdf'; OUT.mkdir(parents=True,exist_ok=True)
TITLE='ICE双功能探头关键工作与图片证据汇总'
PDF=OUT/(TITLE+'_20261024.pdf')
images=[
('F01','P0合成双阵列声场','results/p0_probe_compare/dual_96_plus_96.png','原始仿真结果','历史synthetic 96+96，不能解释当前实物'),
('F02','当前奇偶物理分区','results/verasonics_linear64_oddeven/physical_partition.png','配置可视化','不是实物接线照片'),
('F03','奇偶分配与交替时序示意','docs/reports/2026-10-23_project_review/figures/03_partition_sequence.png','已有说明示意图','示意不按比例，不是运行时序实测'),
('F04','解析RF与DAS单点基准','independent_simulation/results/point_target.png','原始仿真结果','共享简化正反演，非实际成像精度'),
('F05','偶数32元52微米局部声场','independent_simulation/results/kwave_oddeven/even32_focus20mm_dx52um.png','原始仿真结果','10月19日局部域，未标定源'),
('F06','扩域压力与Qp场','independent_simulation/results/kwave_singlepoint_validation_2026-10-22/wide_field.png','原始仿真结果','wide65，搜索域及积分域须区分'),
('F07','评价材料盒分母诊断','docs/reports/2026-10-23_project_review/figures/06_qp_denominator.png','已有数据重绘图','仅改变积分盒，非薄层传播或材料结果'),
('F08','边界诊断测点时序','independent_simulation/results/kwave_offaxis_diagnostic_2026-10-22/offaxis_traces.png','原始仿真结果','稀疏测点p(t)与Qp，不是全域Qp'),
('F09','边界诊断浅层场','independent_simulation/results/kwave_offaxis_diagnostic_2026-10-22/offaxis_shallow.png','原始仿真结果','两个有限边界改变，非完整收敛'),
('F10','65微米活动阵元对照','independent_simulation/results/kwave_aperture_control_2026-10-23/aperture_comparison.png','原始仿真结果','全64为synthetic等源端代理预算候选'),
('F11','宽域两配置两网格浅层场','independent_simulation/results/kwave_widegrid_2026-10-24/widegrid_shallow.png','原始仿真结果','32元浅层幅值尚未稳定'),
('F12','宽域轴上峰压剖线','independent_simulation/results/kwave_widegrid_2026-10-24/widegrid_axial.png','原始仿真结果','显示焦前偏移，非材料选择性'),
('F13','矩形源空间谱审计','independent_simulation/results/kwave_widegrid_2026-10-24/source_sampling.png','解析诊断曲线','未执行带限源传播，非实物指向性'),
]
manifest=[]
for fid,title,source,kind,limit in images:
    src=ROOT/source; dest=FIG/(fid+'_'+src.name)
    shutil.copy2(src,dest)
    manifest.append(dict(id=fid,title=title,source=source,copy=str(dest.relative_to(HERE)).replace('\\','/'),kind=kind,limit=limit,sha256=hashlib.sha256(src.read_bytes()).hexdigest(),size_px=Image.open(src).size))
M={r['id']:r for r in manifest}
sources=[
('S01','docs/project_implementation_report.md'),('S02','docs/upgrade_2026-09-24.md'),
('S03','docs/verasonics/linear64_oddeven_2026-10-12.md'),('S04','results/verasonics_linear64_oddeven/validation.json'),
('S05','independent_simulation/docs/model_and_validation.md'),('S06','independent_simulation/docs/kwave_oddeven_results_2026-10-19.md'),
('S07','independent_simulation/docs/singlepoint_validation_2026-10-22.md'),('S08','independent_simulation/docs/singlepoint_interpretation_2026-10-22.md'),
('S09','independent_simulation/docs/offaxis_diagnostic_2026-10-22.md'),('S10','independent_simulation/docs/aperture_control_2026-10-23.md'),
('S11','independent_simulation/docs/widegrid_2026-10-24.md'),('S12','independent_simulation/results/kwave_widegrid_2026-10-24/validation.json'),
('S13','independent_simulation/docs/findings_2026-10-24.md'),('S14','independent_simulation/docs/ice_bench_poc_plan_2026-10-21.md'),
('S15','docs/verasonics/simulation_verification_2026-10-09.md'),('S16','docs/verasonics/sonic_eyes_hardware_2026-10-12.md'),
('S17','docs/reports/2026-10-24_ppt_brief/ICE新课题汇报_PPT制作说明书.md'),
]
extras=[
'results/p0_probe_compare/comparison.csv','results/p0_probe_compare/voxel_check.csv',
'results/verasonics_linear64_oddeven/mode_summary.csv',
'independent_simulation/results/point_target_report.json',
'independent_simulation/results/kwave_oddeven/grid_comparison.json',
'independent_simulation/results/kwave_singlepoint_validation_2026-10-22/sensitivity_summary.csv',
'independent_simulation/results/kwave_singlepoint_validation_2026-10-22/interpretation_diagnostics.json',
'independent_simulation/results/kwave_offaxis_diagnostic_2026-10-22/trace_summary.csv',
'independent_simulation/results/kwave_aperture_control_2026-10-23/comparison.csv',
'independent_simulation/results/kwave_widegrid_2026-10-24/trace_comparison.csv',
'independent_simulation/results/kwave_widegrid_2026-10-24/source_sampling.json',
'independent_simulation/results/kwave_widegrid_2026-10-24/source_sampling.csv',
'independent_simulation/results/kwave_widegrid_2026-10-24/test_results.csv',
]
file_manifest=[]
for source in dict.fromkeys([p for _,p in sources]+extras):
    src=ROOT/source; dest=DATA/source; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dest)
    file_manifest.append({'source':source,'copy':str(dest.relative_to(HERE)).replace('\\','/'),'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})

pdfmetrics.registerFont(TTFont('Yahei','C:/Windows/Fonts/msyh.ttc'))
pdfmetrics.registerFont(TTFont('YaheiBold','C:/Windows/Fonts/msyhbd.ttc'))
pdfmetrics.registerFontFamily('Yahei',normal='Yahei',bold='YaheiBold',italic='Yahei',boldItalic='YaheiBold')
INK=colors.HexColor('#192F43'); MUTED=colors.HexColor('#526779'); BLUE=colors.HexColor('#143F5D')
styles={
'title':ParagraphStyle('title',fontName='YaheiBold',fontSize=23,leading=34,spaceAfter=12,wordWrap='CJK'),
'h':ParagraphStyle('h',fontName='YaheiBold',fontSize=17,leading=25,spaceAfter=12,wordWrap='CJK'),
'p':ParagraphStyle('p',fontName='Yahei',fontSize=10.5,leading=17,spaceAfter=9,wordWrap='CJK',textColor=INK),
'cap':ParagraphStyle('cap',fontName='Yahei',fontSize=8.7,leading=13.2,spaceBefore=4,spaceAfter=9,wordWrap='CJK',textColor=MUTED),
'cell':ParagraphStyle('cell',fontName='Yahei',fontSize=9,leading=14,wordWrap='CJK',textColor=INK),
'head':ParagraphStyle('head',fontName='YaheiBold',fontSize=9,leading=14,wordWrap='CJK',textColor=colors.white),
}
flow=[]; md=[]; page_meta=[]
def para(t,style='p'):
    flow.append(Paragraph(html.escape(t).replace('\n','<br/>'),styles[style])); md.append(t+'\n')
def page(title):
    if flow: flow.append(PageBreak()); md.append('\n---\n')
    page_meta.append(title); flow.append(Paragraph(html.escape(title),styles['title' if len(page_meta)==1 else 'h'])); md.append('# '+title+'\n')
def table(headers,rows,widths=None):
    data=[[Paragraph(html.escape(str(x)),styles['head' if i==0 else 'cell']) for x in row] for i,row in enumerate([headers]+rows)]
    t=Table(data,colWidths=widths or [499/len(headers)]*len(headers),repeatRows=1,hAlign='LEFT')
    t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),BLUE),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#EFF4F7')]),('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.35,colors.HexColor('#D8E1E7')),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
    flow.extend([t,Spacer(1,10)])
    md.extend(['|'+'|'.join(headers)+'|','|'+'|'.join(['---']*len(headers))+'|']+['|'+'|'.join(str(x) for x in r)+'|' for r in rows]+[''])
def fig(fid,maxh=320):
    r=M[fid]; w,h=r['size_px']; scale=min(499/w,maxh/h)
    cap=f"{fid}  {r['title']}。{r['kind']}；{r['limit']}。"
    im=RLImage(str(HERE/r['copy']),width=w*scale,height=h*scale); im.hAlign='CENTER'
    flow.append(KeepTogether([im,Paragraph(html.escape(cap),styles['cap'])]));md.append(f"![{cap}]({r['copy']})\n")

page(TITLE)
para('截至2026年10月24日  |  仓库阶段工作回顾与证据归档','cap')
para('我们已建立从参数化声学筛选、Verasonics离线序列，到独立三维k-Wave传播与结果审计的工具链。关键进展是把“目标附近出现声压集中”逐步转化为可检查配置、数值稳定性和目标外暴露的研究问题。')
para('当前仍处于离线声学验证阶段。偶数32元浅层幅值尚未稳定，名义20 mm目标存在约1.54 mm焦前偏移；真实电声标定、SonoInk材料反应、单点或短线固化及完整双功能实测均未完成。')
table(['阶段','关键工作','目前证据'],[
['9月23-24日','Rayleigh基线与P0-A升级','声场、扫描、阈值统计和驱动unknown检查'],
['10月8-12日','厂商资料核对与三模式离线序列','当前64线阵奇偶分配；保存对象回读与测试'],
['10月9-19日','独立RF/DAS基准与k-Wave桥接','单次发射三维极值体、测点时序及两网格结果'],
['10月21-22日','缩小体外目标并检查域与Qp','单点到短线路线；发现原ROI外更强浅层峰'],
['10月23日','边界诊断与32/64元受控对照','有限边界改变不能解释原峰；配置影响显著'],
['10月24日','宽域细网格与源空间谱审计','全64改善趋势保留；32元近源/浅层网格敏感'],
],[82,180,237])
para('本份材料包含13幅证据图，按工作主题组织。F01、F04-F06、F08-F13为已有计算结果或解析诊断；F02为配置图，F03为示意图，F07为已有数据重绘。均逐文件复制并记录SHA-256，来源和适用范围见图片索引。','cap')
para('汇总依据现存源码说明、CSV/JSON和原图；本次仅核对、复制、排版与校验，未重跑MATLAB/k-Wave、VSX或硬件。历史测试计数按日期和模块列示，不求和；工作区中的未提交文件同样作为有明确来源的保存记录。','cap')

page('01 建立参数化声学筛选与比较基线')
para('最早的关键工作，是将孔径分配、聚焦、未聚焦和逐点扫描纳入统一计算框架。有限矩形面源Rayleigh模型输出声压、目标覆盖及目标外超阈值代理，P0-A进一步增加共面双阵列、连续分区、显式停留时间、焦前/焦后统计和有来源的驱动限值检查。[S01-S02]')
fig('F01',355)
table(['已形成能力','实际意义与限制'],[
['共享/分区/双阵列与逐点扫描','可比较几何与资源约束；扫描shot分别计算，不能直接相加不同时刻复声压'],
['公共参考、阈值及网格敏感性','35%阈值下两架构目标外比例差约0.00025，小于该例粗细网格变化约0.00074，不能据此排序'],
['显式unknown与截断记录','轴向宽度因ROI截断为NaN；声学越阈值不代表固化率，驱动检查也不是硬件认证'],
],[157,342])
para('历史配置说明：96+96双阵列和96元12×8矩阵均保留为synthetic分支。10月12日依据实物相关信息恢复64线阵基础后，这些旧图不能作为当前探头的性能证据。','cap')

page('02 建立64线阵奇偶分配与离线交替序列')
para('当前默认按物理+x顺序划分：奇数32元成像TX/RX、偶数32元候选照射TX，支持交换角色；保留完整64项掩码、延时与ConnectorES映射。已生成imaging_only、exposure_only和interleaved三模式MAT/JSON/CSV。[S03-S04]')
fig('F02',105); fig('F03',225)
table(['项目','已验证内容或当前来源'],[
['序列组织','事件索引、用途互斥、有限停止、无接收照射、保存后回读；43/43相关测试，19份静态检查0消息'],
['几何与角色','0.13 mm pitch、0.11 mm宽度为existing_code_unverified；奇数成像为assumed角色约定'],
['候选照射输入','6 MHz、20周期、PRI 1000 μs、5 V均为assumed离线示例；不是上机处方'],
['适用边界','未运行VSX、硬件或成像恢复验证；本机配置/许可及探头长脉冲能力仍需核实'],
],[100,399])
para('手册依据：D00163 Rev. K §4.3.2第24-25页与TX.Delay附录A171页，说明TW/TX、掩码和延时语义；本报告未据此执行任何发射操作。','cap')

page('03 接通独立成像基准与三维传播求解')
para('独立模块首先建立理想平面波RF与相干DAS内部基准，再读取保存SetUp中的几何、掩码和延时驱动k-Wave。这样可以分别核查重建逻辑与声场传播，避免把离线序列正确等同于真实聚焦有效。[S05-S06]')
fig('F04',168)
para('解析基准synthetic目标(0.830,20.030) mm，峰值(0.825,20.025) mm，内部误差0.007071 mm。正反演共享简化模型，因此只能说明内部一致性。','cap')
fig('F05',260)
para('10月19日52 μm局部域中，名义目标20 mm，主焦区峰深18.460 mm，焦前偏移1.540 mm；x/y/z压力半幅宽约0.717/2.894/13.477 mm。轴向焦区较长，不能用一张亮斑图证明局部固化。65/52 μm公共局部ROI场L2差约0.749%，不构成全域收敛。')
para('求解范围：MATLAB R2024b Update 2、k-Wave 1.4.1 kspaceFirstOrder3D、gpuArray-single、CFL0.2；assumed c=1540 m/s、ρ=1000 kg/m³均匀无损流体和未标定压力源。三维图为max_t|p|极值体，不是同一时刻快照；只求解选定单次发射。','cap')

page('04 从局部焦区扩展到目标外暴露与Qp')
para('10月22日完成基线、加厚PML、横向扩域、轴向延长及细网格五工况。公共ROI压力场变化均小于0.8%，但扩域找到更强浅层离轴峰，综合前向域稳定性未通过。局部稳定无法代替更大范围的暴露检查。[S07-S08]')
fig('F06',245)
para('wide65在(6.370,0,2.015) mm出现约1.501624 Pa峰，高于同工况主焦区峰约6.76%。绝对压力均来自assumed源；该浅层峰贴着z≥2 mm搜索边界，不能当作完整离轴焦区，也不是主焦区的定位误差。')
fig('F07',185)
para('Qp=dt×Σp²，单位Pa²·s，是声压平方时间积分代理。1 mm立方synthetic目标在8×4×18 mm评价盒中的Qp空间积分比例约2.160%；仅将评价盒厚度改为1 mm，该比例变为37.098%。这源于分母改变，没有重算薄层材料传播、吸收或反应，不能解释为固化效率提高。')
para('峰压最高点与Qp最高点可以不同；上述材料盒不含浅层热点。Qp及其空间积分都不能直接称为吸收热量、固化剂量或临床安全指标。','cap')

page('05 用有限边界对照和时序排查离轴结构')
para('10月22-23日保留原wide65源与分辨率，分别将PML从16增至20格、将x域从15.6扩至16.64 mm，并保存12个固定测点的p(t)。两项有限改变均未明显移动原浅层峰，不支持这两个边界设置是其主要成因。[S09]')
fig('F08',285); fig('F09',150)
table(['对照','完整公共域峰压场L2差','原z≥2 mm峰位变化'],[
['PML16→20格','0.0772%','0.000 mm'],['x域15.6→16.64 mm','0.0217%','0.000 mm'],
],[170,175,154])
para('两项对照只提供有限边界诊断，尚未唯一认定栅瓣或证明完整收敛。Qp主值采用保存时序的双精度积分；RMS交叉检查改用有GPU单精度误差依据的proposed 0.1%实现容差，保留失败记录并在后处理前保存原始检查点。没有新增全域Qp体。','cap')

page('06 对照偶数32元与全64元照射配置')
para('10月23日新增synthetic全64元候选，重算聚焦延时，在相同域、65 μm网格与波形下匹配源端代理预算B。全64信号统一缩放约0.7071，比较活动配置对原离轴结构及主焦区的影响。[S10]')
fig('F10',345)
table(['65 μm结果','偶数32元','全64元等B'],[
['固定正离轴点/主焦测点Qp比','76.6925%','0.0373%'],
['0<z<2 mm区域最大压力','2.221455 Pa','0.900052 Pa'],
['2≤z<5 mm区域最大压力','1.501624 Pa','1.108339 Pa'],
['主焦区峰深','18.395 mm','18.395 mm'],
],[245,127,127])
para('B=阵元面积×dt×Σs²，单位Pa²·s·m²，不是实际声能或声功率。结果说明原测点改善与活动配置相关；数量、间距、填充率、孔径和中心同时改变，不能唯一归因pitch。浅层暴露未全部消失，轴向偏移未解决，也未更新全域材料积分比例。')
para('全64仅为离线对照；保存SetUp及硬件奇偶角色保持原状。图中“等预算”均指上述源端代理，非真实设备输出匹配。','cap')

page('07 在同一宽域细化网格并保留失败结论')
para('10月24日分别完成偶数32元及全64元的52 μm传播。与各自65 μm结果保持15.6×10.4×31.2 mm物理域、1.04 mm PML、20 mm目标、至少40 μs时窗和相同B；每组实际求解约1738 s。[S11-S13]')
fig('F11',342)
table(['65→52 μm原始幅值场L2差','偶数32元','全64元等B'],[
['全部公共物理域','7.761%','0.993%'],
['0<z<2 mm近源层','11.681%','2.463%'],
['2≤z<5 mm浅层','6.893%','1.157%'],
['z≥5 mm深层','0.572%','0.474%'],
],[265,117,117])
para('32元近源与浅层未通过proposed 5%内部场差判据；260 μm共同精确格点检查仍得到约10.89%/6.94%，排除“仅由插值造成”的解释。32元浅层原生峰压1.5016→1.6732 Pa，约+11.43%，峰位接近不代表幅值稳定。')
para('全64各分区通过场差项，但近源/浅层argmax可在近似等高瓣间切换，不能写成所有位置检查通过；两档网格仍未建立完整收敛。','cap')

page('08 核实改善趋势同时暴露源表示误差')
fig('F12',177)
para('同一52 μm网格上，固定正离轴点/主焦测点Qp比为32元93.899%、全64元0.0623%，原测点抑制趋势保留；两配置目标点/主焦测点比均约0.9164，主焦峰深均18.460 mm。因此一个离轴点改善，并未解决焦前偏移或轴向选择性。[S11-S13]')
fig('F13',265)
para('0.11 mm矩形单元在65/52 μm网格上仅占约1.69/2.12格。面积重叠源可守恒面积，但大角度空间谱仍随网格变化。代表偶数单元x=-0.065 mm在6 MHz、75°时，离散源谱相对连续矩形积分的幅值偏差约-18.39%/-7.38%。')
para('这一解析诊断为浅层敏感性提供线索，尚未隔离全部误差因果贡献，也不是实物指向性。下一增量拟验证带限物理矩形源的几何、非局域支撑、尺度与网格敏感性；截至本报告，带限源替换及其传播尚未实现。跨网格Qp最近体素略有变化，不能把它单独当作相同物理点收敛证据。','cap')

page('09 软件验证与硬件证据分别记账')
para('软件测试证明对应实现与产物的一致性，数值敏感性说明计算结果在已检查范围内的稳定性。两者均不能替代真实设备、材料或完整双功能流程验证。以下数字均来自历史保存记录，本次没有重跑这些测试。')
table(['证据包','保存检查记录','解释边界'],[
['9月24日P0-A','MATLAB 60/60；39份静态检查0消息','synthetic筛选模块'],
['10月12日奇偶序列','相关MATLAB 43/43；19份静态检查0消息','不含全仓库新回归或VSX'],
['10月19日奇偶k-Wave','MATLAB 20/20；7份静态检查0消息','局部两网格，不是全域收敛'],
['10月22日单点增量','MATLAB 26/26；Python 10/10','软件通过，扩域敏感性未通过'],
['10月23日活动配置增量','MATLAB 32/32；Python 17/17','对应增量快照，非项目累计'],
['10月24日宽域细网格','MATLAB 36/36；Python 25/25；173份历史文件哈希保持','完整收敛仍为not_established'],
],[118,235,146])
para('四份指定原始PDF本次均已读取封面版本及相关章节。下表仅用于说明硬件解释依据，不证明实验室已安装可选配置，也不构成操作授权。')
table(['手册与版本','核对章节与页码','相关边界'],[
['Product Specification\nD00108 Rev. L','§1.4，印刷8-9页\nPDF9-10页','Extended Transmit/HIFU为选项；系统保护不等于探头温升或声输出合格'],
['Initial Setup Instructions\nD00109 Rev. D','§4.5，第9-10页','自检及日志构成就绪证据；本次未执行'],
['System User Manual\nD00107 Rev. K','§4.4.1-4.4.2，第30页','Profiles1-4用于短burst/低duty；Profile5扩展发射为可选能力'],
['Sequence Programming Manual\nD00163 Rev. K','§4.3.2，第24-25页；\nTX.Delay A171（PDF310）','掩码控制活动单元；延时按Trans.frequency周期解释'],
],[155,165,179])
para('历史10月9日许可诊断未授予本机模拟功能，不能推断当前许可状态；本次未激活或探测设备。探头完整型号后缀、额定burst/duty、电声传递、头端温度及恢复通路继续unknown。[S15-S16]','cap')

page('10 当前成果边界与下一步工作')
table(['状态','截至目前可以报告的内容'],[
['已实现','参数化Rayleigh筛选；三模式离线序列；独立RF/DAS内部基准；单次发射k-Wave；域/PML/网格与活动配置诊断；Qp及源谱审计'],
['已有数值证据','局部声压集中、焦前偏移、长轴向焦区、浅层目标外结构；全64等B对原测点的改善趋势；32元浅层网格敏感'],
['尚未完成','带限源传播、焦深补偿、真实俯仰透镜；全64全域新Qp与材料积分；声热/反应模型；实物单点/短线及双功能实测'],
['不支持的结论','成功固化、真实声压/热剂量、临床安全、当前配置最优或完整数值收敛'],
],[100,399])
para('已建立的研究路线是：先使固定单点声场可信，再核实材料局部响应，随后推进连续短线，最后评价成像定位、照射和图像恢复的完整交替流程。现阶段不把血流、封堵或临床应用作为完成项。[S14]')
table(['顺序','下一工作与可交付证据'],[
['1 源表示与数值可信度','保持当前基线；验证带限源方向、支撑截断、面积与信号尺度，再做同网格源对照及两网格传播。不得预设热点必然下降'],
['2 焦区与活动配置','固定20 mm目标，建立设计延时焦深→实际峰值映射，同时检查焦宽及目标外场；核实俯仰孔径/透镜'],
['3 真实输入与标定','明确本支探头规格、系统模块/许可、SonoInk具体配方、容器和样品厚度、吸收与反应判据，建立电气请求到p(t)的测量联系'],
['4 单点到短线再到双功能','分别保存声场、温度和材料证据；单点成立后考察线长/连续性/线外反应和重复性，最后验证接收恢复及图像恢复'],
],[123,376])
para('此外，10月23-24日已形成阶段汇报材料和新课题汇报路线。它们用于沟通研究设想与计划，不作为新增科学结果或实验完成证据。[S17]','cap')

page('11 图片证据索引')
para('本包保留原图文件，不裁剪、不改标尺、不生成新的结果图。每幅图的类型、原始路径和SHA-256见evidence_manifest.json；随附evidence_index.csv便于筛选和复用。原图可以用于汇报，但必须保留相应模型边界。')
table(['图号','图片内容','性质与复用限制'],[[r['id'],r['title'],r['kind']+'；'+r['limit']] for r in manifest],[44,180,275])
para('真实实验图片说明：本次可追溯证据中未找到已完成材料固化的照片、水听器实测声场图、探头温升记录或双功能上机图像。历史身份说明引用了用户探头照片，但本包不以型号示意或网络产品图替代实物/实验原照。','cap')

page('12 来源索引与归档说明')
para('以下S编号对应仓库来源；证据包内按原目录保存于evidence/下，图片位于figures/下。可编辑正文为同名Markdown。由于原始MAT和检查点体积较大，本包只纳入关键文档、CSV/JSON与图片，原始体数据留在仓库。')
table(['编号','原始路径'],[[sid,path] for sid,path in sources],[40,459])
para('硬件四手册原始目录：F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10/。本包不复制完整厂商手册；版本与页码见第09节。')
para('归档检查记录位于qa/delivery_checks.json，包括来源存在性、复制文件哈希、PDF回读及逐页渲染目视检查。它只记录本次汇总工作，不替代历史仿真或硬件验证。','cap')

def hf(c,d):
    c.saveState();c.setFont('Yahei',8);c.setFillColor(MUTED)
    c.drawString(48,812,'ICE-Sonocuring  /  关键工作与图片证据')
    c.setStrokeColor(colors.HexColor('#DAE3E9'));c.line(48,802,547,802)
    c.drawString(48,28,'2026.10.24  |  离线证据汇总  |  非实物或材料验证')
    c.drawRightString(547,28,f'{d.page:02d}');c.restoreState()
doc=SimpleDocTemplate(str(PDF),pagesize=A4,leftMargin=48,rightMargin=48,topMargin=55,bottomMargin=47,title=TITLE,author='',subject='截至2026年10月24日的ICE仓库关键工作和证据归档')
doc.build(flow,onFirstPage=hf,onLaterPages=hf)
(HERE/(TITLE+'.md')).write_text('\n'.join(md),encoding='utf-8')
(HERE/'evidence_manifest.json').write_text(json.dumps({'date':'2026-10-24','scope':'saved repository evidence; no solver rerun','images':manifest,'files':file_manifest},ensure_ascii=False,indent=2),encoding='utf-8')
with (HERE/'evidence_index.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=['id','title','kind','source','copy','limit','sha256']);writer.writeheader();writer.writerows({k:v for k,v in r.items() if k!='size_px'} for r in manifest)
reader=PdfReader(PDF)
alltext='\n'.join(p.extract_text() for p in reader.pages)
(QA/'pdf_readback.txt').write_text(alltext,encoding='utf-8')
pdf=pdfium.PdfDocument(str(PDF))
for i in range(len(pdf)):
    pg=pdf[i];pg.render(scale=1.4).to_pil().save(QA/f'page-{i+1:02}.png')
thumbw=298; thumbh=422; cols=3; rows=(len(pdf)+cols-1)//cols
sheet=Image.new('RGB',(cols*(thumbw+16)+16,rows*(thumbh+30)+16),'#E7EDF2');draw=ImageDraw.Draw(sheet)
for i in range(len(pdf)):
    im=Image.open(QA/f'page-{i+1:02}.png');im.thumbnail((thumbw,thumbh));x=16+i%cols*(thumbw+16);y=16+i//cols*(thumbh+30);sheet.paste(im,(x,y));draw.text((x,y+thumbh+4),str(i+1),fill='black')
sheet.save(QA/'contact_sheet.png')
checks={'pdf':str(PDF),'pages':len(reader.pages),'planned_pages':len(page_meta),'image_count':len(manifest),'sources_count':len(file_manifest),'image_hashes_match':all(hashlib.sha256((ROOT/r['source']).read_bytes()).hexdigest()==hashlib.sha256((HERE/r['copy']).read_bytes()).hexdigest() for r in manifest),'source_files_match':all(hashlib.sha256((HERE/r['copy']).read_bytes()).hexdigest()==r['sha256'] for r in file_manifest),'all_source_paths_exist':all((ROOT/p).exists() for _,p in sources),'solver_rerun':False,'historical_tests_rerun':False,'visual_review':'pending','text_chars':len(alltext)}
(QA/'delivery_checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(checks,ensure_ascii=False))
