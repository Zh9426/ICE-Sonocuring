"""Build review-only figures, slide layout references, HTML and evidence audit.

Reads saved outputs only; does not run simulation, vendor code, or hardware.
The companion PDF renderer typesets the report from the Markdown source.
"""
from pathlib import Path
import csv
import hashlib
import html
import json
import re
import shutil
import sys

import fitz
import markdown
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding='utf-8')
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FIG = HERE / 'figures'
SLIDES = HERE / 'slides'
QA = HERE / 'qa'
for p in (FIG, SLIDES, QA):
    p.mkdir(exist_ok=True)
BLUE = '#142B45'
TEAL = '#008C95'
AMBER = '#C27B22'
GREY = '#536477'
LIGHT = '#EFF3F7'
LINE = '#CED8E2'
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'
plt.rcParams.update({'font.family': 'Microsoft YaHei', 'axes.unicode_minus': False,
                     'text.color': BLUE, 'axes.labelcolor': BLUE,
                     'xtick.color': GREY, 'ytick.color': GREY,
                     'axes.spines.top': False, 'axes.spines.right': False})

def font(n, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, n)

def text(draw, xy, s, size=32, fill=BLUE, bold=False):
    draw.text(xy, s, font=font(size, bold), fill=fill, spacing=int(size*.32))

def wrap(s, width, size):
    out = []
    for para in s.split('\n'):
        line = ''
        for ch in para:
            if font(size).getlength(line+ch) > width and line:
                out.append(line)
                line = ch
            else:
                line += ch
        out.append(line)
    return '\n'.join(out)

def block(d, xy, s, width, size=30, fill=GREY, bold=False):
    text(d, xy, wrap(s, width, size), size, fill, bold)

def arrow(d, start, end, color=TEAL, width=4):
    d.line([start, end], fill=color, width=width)
    x, y = end
    d.polygon([(x,y),(x-13,y-8),(x-13,y+8)], fill=color)

def canvas(w, h):
    im=Image.new('RGB', (w,h), 'white')
    return im, ImageDraw.Draw(im)

def fig_title(d, title, sub):
    text(d, (55,28), title, 40, bold=True)
    text(d, (55,90), sub, 24, GREY)

def save_fig(im, name):
    im.save(FIG/name, dpi=(200,200))

# 1. Evidence-based chronology (schematic).
im,d=canvas(1800,620)
fig_title(d, '项目演进：由架构筛选走向体外验证', '日期来自保存记录；节点表示工作重点，不表示材料验证完成')
nodes=[('09.22—24','声学基线 / P0-A','参数化几何、Rayleigh\n目标与目标外暴露'),
       ('09.26','研究问题与合同','资源匹配、数值门槛\n形成可复核命题'),
       ('10.08—12','序列与当前方案','三模式离线编排\n64元奇偶分区'),
       ('10.12—19','独立三维传播','当前TX的k-Wave\n两网格与焦区评价'),
       ('10.21—22','单点与边界诊断','大域 / PML / Qp\n准备体外单点证据')]
d.line([(145,245),(1650,245)],fill=LINE,width=6)
for i,(date,title,body) in enumerate(nodes):
    x=65+i*345
    color=AMBER if i==4 else TEAL
    d.ellipse((x+90,227,x+126,263),fill=color)
    text(d,(x,165),date,29,color,True)
    text(d,(x,300),title,31,bold=True)
    text(d,(x,365),body,26,GREY)
text(d,(55,540),'近期验收对象：固定单点与连续短线；完整双功能与材料作用另行验证。',29,BLUE,True)
save_fig(im,'01_evolution.png')

# 2. Method lines and incomplete physical links.
im,d=canvas(1800,640)
fig_title(d,'三条工作线与证据连接','实线：已实现的选定TX数据连接；虚线：尚未贯通或验证的连接')
for i,(title,body) in enumerate([
    ('Rayleigh 快速筛选','几何 / 分区 / 单点与扫描\n阈值覆盖、目标外暴露\n均匀性与宽度'),
    ('Verasonics 离线序列','Trans / TW / TX / Event\n成像、候选照射、交替\n保存MAT与事件/阵元表'),
    ('k-Wave 独立复核','保存序列 → 选定单次发射\n三维声场、域/PML/网格\nRMS与Qp代理')]):
    x=55+i*585
    d.rectangle((x,170,x+520,450),fill=LIGHT)
    text(d,(x+24,190),f'0{i+1}',30,TEAL,True)
    text(d,(x+24,245),title,32,bold=True)
    text(d,(x+24,315),body,27,GREY)
for x in range(578,635,15): d.line([(x,305),(x+7,305)],fill=GREY,width=3)
arrow(d,(1160,305),(1205,305))
text(d,(600,465),'尚未自动贯通',24,GREY)
text(d,(1170,465),'选定TX',24,TEAL)
d.line([(55,535),(1740,535)],fill=LINE,width=2)
text(d,(55,565),'待补的物理连接：电声标定 → 材料吸收 / 热 → 材料转化 → 双功能实测',31,AMBER,True)
save_fig(im,'02_evidence_chain.png')

# 3. Physical linear odd/even partition and non-proportional event sketch.
im,d=canvas(1800,650)
fig_title(d,'当前方案：64元奇偶分配，有限时间交替','物理+x顺序示意；不按尺寸或时间比例；颜色表示用途约定')
for i in range(64):
    x=65+i*26
    d.rectangle((x,195,x+18,295),fill=TEAL if i%2==0 else AMBER)
    if i in (0,1,2,3,62,63): text(d,(x-2,310),str(i+1),20,GREY)
arrow(d,(1500,355),(1735,355),BLUE,3)
text(d,(1505,370),'物理 +x',24)
text(d,(65,365),'奇数32元：成像TX/RX',31,TEAL,True)
text(d,(600,365),'偶数32元：候选照射TX',31,AMBER,True)
events=[('成像',TEAL),('切换等待',GREY),('候选照射',AMBER),('接收恢复',GREY),('成像',TEAL)]
for i,(s,c) in enumerate(events):
    x=65+i*343
    d.rectangle((x,465,x+285,545),fill=LIGHT)
    text(d,(x+45,483),s,31,c,True)
    if i<4: arrow(d,(x+295,505),(x+332,505),GREY,3)
text(d,(65,585),'源码pitch 0.13 mm；每组活动间距0.26 mm。几何未标定；离线编排不代表实物流程通过。',27,GREY)
save_fig(im,'03_partition_sequence.png')

# 4. Quantitative summary: use CSVs directly.
RES=ROOT/'independent_simulation/results/kwave_singlepoint_validation_2026-10-22'
with (RES/'focus_summary.csv').open(encoding='utf-8-sig') as f: focus=list(csv.DictReader(f))
with (RES/'sensitivity_summary.csv').open(encoding='utf-8-sig') as f: sensitivity=list(csv.DictReader(f))
fine=next(x for x in focus if x['tag']=='fine52')
fig,axs=plt.subplots(1,2,figsize=(13,4.6),gridspec_kw={'width_ratios':[1,1.2]})
axs[0].barh(['x','y','z'],[float(fine[f'global_peak_width_{a}_mm']) for a in 'xyz'],color=[TEAL,TEAL,AMBER],height=.55)
axs[0].invert_yaxis()
for i,a in enumerate('xyz'):
    v=float(fine[f'global_peak_width_{a}_mm'])
    axs[0].text(v+.18,i,f'{v:.3f}',va='center',fontsize=13)
axs[0].set_xlim(0,16)
axs[0].set_xlabel('连续声压半幅宽 / mm',fontsize=12)
axs[0].set_title('fine52：峰值深度18.46 mm；设定20 mm',fontsize=13,pad=17)
axs[0].tick_params(labelsize=12)
labels=['PML加厚','横向域扩大','轴向域延长','网格细化']
vals=[float(x['pressure_l2'])*100 for x in sensitivity]
axs[1].barh(labels,vals,color=[TEAL,AMBER,TEAL,TEAL],height=.55)
axs[1].invert_yaxis()
for i,v in enumerate(vals): axs[1].text(v+.02,i,f'{v:.4f}%',va='center',fontsize=12)
axs[1].set_xlim(0,1.0)
axs[1].set_xlabel('公共ROI峰压场相对L2差 / %',fontsize=12)
axs[1].set_title('相对10月22日baseline65',fontsize=13,pad=17)
axs[1].tick_params(labelsize=12)
fig.text(.53,.02,'横向域扩大：局部ROI接近，但全域峰值稳定性未通过。',fontsize=11,color=AMBER)
fig.suptitle('假设源与均匀无损介质下的局部焦区和敏感性',fontsize=16,color=BLUE)
fig.tight_layout(rect=[0,.065,1,.93])
fig.savefig(FIG/'04_results_summary.png',dpi=200,facecolor='white')
plt.close(fig)
shutil.copy2(RES/'wide_field.png',FIG/'05_wide_field.png')

# 6. Read-only postprocessing result, no recomputation of acoustic fields.
interp=json.loads((RES/'interpretation_diagnostics.json').read_text(encoding='utf-8'))
diag=interp['fine52_material_box_diagnostics']
fig,ax=plt.subplots(figsize=(10.6,3.9))
x=['1 mm','2 mm','4 mm','18 mm']
y=[v['target_qp_fraction']*100 for v in diag]
ax.bar(x,y,color=[AMBER,TEAL,TEAL,TEAL],width=.52)
for i,v in enumerate(y): ax.text(i,v+.8,f'{v:.3f}%',ha='center',fontsize=13)
ax.set_ylim(0,45)
ax.set_ylabel('固定1 mm立方目标内Qp积分比例 / %',fontsize=12)
ax.set_xlabel('假设材料积分盒的轴向厚度（横向8×4 mm）',fontsize=12)
ax.set_title('同一fine52声场：仅改变积分分母，目标内积分未变',fontsize=15,pad=17)
fig.text(.12,.015,'未重新模拟薄层材料；比例不是沉积能量占比或固化率。来源：10月22日解释补充。',fontsize=10,color=GREY)
fig.tight_layout(rect=[0,.045,1,1])
fig.savefig(FIG/'06_qp_denominator.png',dpi=200,facecolor='white')
plt.close(fig)

# 7. Evidence-gated next steps, no fixed unconfirmed dates.
im,d=canvas(1800,600)
fig_title(d,'下一阶段：按证据门槛推进','前两项可继续离线诊断及准备资料；材料、短线和双功能依赖各自前序证据')
steps=[('边界 / 孔径','宽域、PML、32/64元\n真实透镜与几何'),('参数 / 标定','系统与探头约束\n样品几何、p(t)'),('固定单点','明确SonoInk配方\n对照与材料判据'),('连续短线','机械 / 电子分开验证\n连续性、宽厚、线外'),('双功能流程','成像定位、照射\n接收与图像恢复')]
for i,(a,b) in enumerate(steps):
    x=55+i*350
    text(d,(x,180),f'{i+1:02}',42,TEAL if i==0 else GREY,True)
    d.line([(x,250),(x+290,250)],fill=TEAL if i==0 else LINE,width=5)
    text(d,(x,280),a,33,bold=True)
    text(d,(x,350),b,26,GREY)
    if i<4: arrow(d,(x+295,250),(x+335,250),GREY,3)
text(d,(55,490),'每一步分别报告成功、失败和不确定性；单次照射不替代材料、成线或完整双功能证据。',29,AMBER,True)
save_fig(im,'07_next_steps.png')

# Five 16:9 slide composition references. Text is deliberately concise.
W,H=1920,1080
def base_slide(n,title,tag):
    im,d=canvas(W,H)
    text(d,(80,40),'ICE-SONOCURING  /  阶段进展',24,TEAL,True)
    text(d,(80,105),title,47,bold=True)
    text(d,(80,180),tag,27,GREY)
    d.line([(80,955),(1840,955)],fill=LINE,width=2)
    text(d,(80,1007),'2026.10.23  |  模型与离线证据；实物/材料待验证',21,GREY)
    text(d,(1775,1005),f'{n:02} / 05',22,GREY)
    return im,d

def conclusion(d,s): text(d,(80,895),s,31,BLUE,True)
def paste_fit(im,path,box):
    src=Image.open(path).convert('RGB')
    x,y,w,h=box
    src.thumbnail((w,h),Image.Resampling.LANCZOS)
    im.paste(src,(int(x+(w-src.width)/2),int(y+(h-src.height)/2)))

im,d=base_slide(1,'从架构设想，走向体外单点验证','目标与演进  /  9月建立底座，10月推进当前探头的独立验证')
text(d,(80,300),'研究问题',29,TEAL,True)
block(d,(80,365),'同一ICE探头，\n能否兼顾成像定位\n与局部超声作用？',535,43,BLUE,True)
block(d,(80,615),'长期：成像与材料作用协同\n近期：固定单点 → 连续短线',535,29)
events=[('9月','建工具','几何 / 声场\n架构与指标'),('10月上旬','接序列','离线三模式\n独立传播入口'),('10月中旬','定方案','64元奇偶分区\n当前TX验证'),('10月下旬','补证据','扩大域 / Qp\n体外单点计划')]
d.line([(750,440),(1745,440)],fill=LINE,width=5)
for i,(a,b,c) in enumerate(events):
    x=690+i*285
    text(d,(x,330),a,29,AMBER if i==3 else TEAL,True)
    d.ellipse((x+30,422,x+66,458),fill=AMBER if i==3 else TEAL)
    text(d,(x,495),b,37,bold=True)
    text(d,(x,570),c,27,GREY)
conclusion(d,'已具备可追溯的仿真与离线序列工具；材料固化仍待验证。')
text(d,(80,968),'来源：9月基线 / P0-A、10月12日奇偶升级、10月21—22日体外方案与验证报告',20,GREY)
im.save(SLIDES/'slide_01.png')

im,d=base_slide(2,'已建立可追溯的声学与序列验证工具','三条工作线  /  已有独立模块与选定TX连接，物理闭环尚待补齐')
cols=[('01','Rayleigh 快速筛选','几何、孔径与顺序扫描\n覆盖 / 目标外暴露 / 均匀性'),('02','Verasonics 离线序列','成像 / 候选照射 / 交替\nMAT、事件表与参数来源'),('03','k-Wave 独立复核','选定单次发射三维传播\n域 / PML / 网格 / Qp代理')]
for i,(n,a,b) in enumerate(cols):
    x=80+i*610
    text(d,(x,285),n,54,TEAL,True)
    d.line([(x,370),(x+515,370)],fill=LINE,width=3)
    text(d,(x,420),a,34,bold=True)
    text(d,(x,510),b,28,GREY)
for x in range(611,674,15): d.line([(x,470),(x+6,470)],fill=GREY,width=3)
arrow(d,(1230,470),(1280,470))
text(d,(580,640),'尚未自动贯通',23,GREY)
text(d,(1195,640),'保存MAT → 选定TX',23,TEAL)
d.line([(80,725),(1840,725)],fill=LINE,width=2)
text(d,(80,765),'待补：电声标定 → 吸收 / 热 → 材料转化 → 双功能实测',35,AMBER,True)
conclusion(d,'配置与单位、软件检查、数值结果及解释范围分别留证。')
text(d,(80,968),'来源：simulation/+ice、verasonics/dual_mode、independent_simulation及各阶段验证记录',20,GREY)
im.save(SLIDES/'slide_02.png')

im,d=base_slide(3,'当前方案：64元奇偶分配，成像与候选照射交替','当前拓扑是线阵；历史12×8矩阵分支仅作synthetic案例')
for i in range(64):
    x=85+i*17
    d.rectangle((x,345,x+11,455),fill=TEAL if i%2==0 else AMBER)
    if i in (0,1,2,3,62,63): text(d,(x-1,470),str(i+1),14,GREY)
text(d,(80,275),'用途按物理 +x 顺序划分',29,bold=True)
text(d,(80,535),'奇数32元：成像TX/RX',29,TEAL,True)
text(d,(80,590),'偶数32元：候选照射TX',29,AMBER,True)
facts=[('0.13 mm','源码pitch，尚未标定'),('0.26 mm','每组活动间距'),('43 / 43','离线相关测试；非实物通过')]
for i,(a,b) in enumerate(facts):
    y=280+i*155
    text(d,(1280,y),a,43,BLUE,True)
    text(d,(1280,y+65),b,26,GREY)
for i,(a,c) in enumerate([('成像',TEAL),('切换等待',GREY),('候选照射',AMBER),('接收恢复',GREY),('成像',TEAL)]):
    x=80+i*360
    d.rectangle((x,735,x+310,812),fill=LIGHT)
    text(d,(x+40,751),a,30,c,True)
    if i<4: arrow(d,(x+317,774),(x+348,774),GREY,3)
text(d,(80,840),'示意，非尺寸/时间比例；等待策略需实际验证。保留完整64项映射，用途可交换。',24,GREY)
conclusion(d,'已完成分区与事件编排；声场、成像质量和材料作用分别验收。')
text(d,(80,968),'来源：10月12日奇偶升级；D00163 Rev.K §4.3.2 p24—25 / A171；相关四手册见报告第七节',20,GREY)
im.save(SLIDES/'slide_03.png')

im,d=base_slide(4,'目标附近有声压集中，空间选择性仍需解决','assumed 1 Pa源 / 均匀无损介质 / 无俯仰透镜；未作实际材料预测')
text(d,(80,265),'目标附近 / fine52',29,TEAL,True)
text(d,(80,322),'20.00 → 18.46 mm',49,BLUE,True)
text(d,(80,395),'设定深度 → 峰值深度；偏差1.540 mm',27,GREY)
labels=['x','y','z']
widths=[float(fine[f'global_peak_width_{a}_mm']) for a in labels]
for i,(a,v) in enumerate(zip(labels,widths)):
    y=490+i*83
    text(d,(80,y),a,31,BLUE,True)
    d.rectangle((130,y+5,130+int(v/14*670),y+37),fill=TEAL if i<2 else AMBER)
    text(d,(840,y),f'{v:.3f}',29,BLUE,True)
text(d,(80,760),'连续声压半幅宽 / mm（约−6.02 dB）',26,GREY)
d.line([(1000,270),(1000,800)],fill=LINE,width=2)
text(d,(1070,265),'扩大横向域 / wide65',29,AMBER,True)
# schematic positions in x-z; coordinates from CSV, not a field heatmap
plot=(1110,365,1680,645)
x0,z0,x1,z1=plot
d.line([(x0,z0),(x0,z1),(x1,z1)],fill=GREY,width=2)
def loc(x,z): return (int(x0+(x+8)/16*(x1-x0)),int(z0+z/32*(z1-z0)))
for tick in [-8,0,8]:
    px0,pz0=loc(tick,32)
    d.line([(px0,pz0),(px0,pz0+6)],fill=GREY,width=2)
    text(d,(px0-16,pz0+10),str(tick),18,GREY)
for tick in [0,10,20,30]:
    px0,pz0=loc(-8,tick)
    d.line([(px0-6,pz0),(px0,pz0)],fill=GREY,width=2)
    text(d,(px0-39,pz0-12),str(tick),18,GREY)
text(d,(1710,640),'x / mm',20,GREY)
text(d,(1065,325),'z / mm',20,GREY)
tx,tz=loc(0,20); px,pz=loc(6.37,2.015)
d.line([(tx-9,tz),(tx+9,tz)],fill=TEAL,width=3)
d.line([(tx,tz-9),(tx,tz+9)],fill=TEAL,width=3)
d.ellipse((px-8,pz-8,px+8,pz+8),fill=AMBER)
text(d,(1140,682),'目标20 mm',23,TEAL)
text(d,(1380,682),'离轴峰[6.37,0,2.015] mm',21,AMBER)
text(d,(1070,715),'峰压高6.76%；全域稳定性未通过',31,AMBER,True)
text(d,(1070,770),'位置示意，非声场图；成因待诊断',24,GREY)
text(d,(80,835),'Qp是dt·Σp²代理。1 mm立方目标占比2.160%（假设8×4×18 mm盒），不是固化率。',25,GREY)
conclusion(d,'局部ROI接近不能排除域外强峰；峰压热点与Qp热点须分别评价。')
text(d,(80,968),'来源：10月19日奇偶结果、10月22日focus/sensitivity CSV及解释补充；完整收敛未建立',20,GREY)
im.save(SLIDES/'slide_04.png')

im,d=base_slide(5,'下一步：先形成单点证据，再扩展为连续短线','按依赖和验收门槛推进；材料、台架及系统配置尚待补齐')
for i,(a,b) in enumerate(steps):
    x=80+i*360
    text(d,(x,285),f'0{i+1}',49,TEAL if i==0 else GREY,True)
    d.line([(x,365),(x+295,365)],fill=TEAL if i==0 else LINE,width=5)
    text(d,(x,410),a,32,bold=True)
    block(d,(x,480),b,300,24,GREY)
    if i<4: arrow(d,(x+306,365),(x+348,365),GREY,3)
d.line([(80,620),(1840,620)],fill=LINE,width=2)
text(d,(80,675),'探头与系统',29,TEAL,True)
block(d,(80,735),'完整型号、额定burst/duty\n本机模块、许可与声压标定',790,30)
text(d,(1030,675),'材料与台架',29,TEAL,True)
block(d,(1030,735),'SonoInk具体配方、厚度与容器\n水听器、位移与温度记录条件',790,30)
conclusion(d,'以可复核的单点结果，决定是否推进短线及双功能实际验证。')
text(d,(80,968),'来源：10月21日体外方案、10月22日验证/解读补充；机械与电子扫描分别验证',20,GREY)
im.save(SLIDES/'slide_05.png')

# Layout-reference PDF: exactly five pages, deliberately not labelled PPTX.
pdf=fitz.open()
for n in range(1,6):
    page=pdf.new_page(width=960,height=540)
    page.insert_image(page.rect,filename=str(SLIDES/f'slide_{n:02}.png'))
pdf.set_metadata({'title':'ICE-Sonocuring 5页PPT视觉草案','subject':'Layout reference; not editable PPTX','author':''})
pdf.save(HERE/'PPT视觉草案_5页.pdf',deflate=True)
pdf.close()
thumbs=Image.new('RGB',(1440,3*430),'#E8EDF2')
for i in range(5):
    s=Image.open(SLIDES/f'slide_{i+1:02}.png')
    s.thumbnail((700,394),Image.Resampling.LANCZOS)
    thumbs.paste(s,(15+(i%2)*720,15+(i//2)*430))
thumbs.save(HERE/'PPT五页总览.png')

# Portable HTML sources. Keep local links absolute in Word import HTML.
css='''
body{font-family:"Microsoft YaHei",sans-serif;color:#172535;font-size:11pt;line-height:1.52;}
h1{font-size:24pt;color:#000;margin-top:12pt;margin-bottom:20pt;}
h2{font-size:16pt;color:#000;margin-top:20pt;margin-bottom:9pt;page-break-after:avoid;}
h3{font-size:12.5pt;color:#000;margin-top:14pt;margin-bottom:7pt;page-break-after:avoid;}
p{margin:0 0 8pt;} a{color:#176273;text-decoration:none;}
table{border-collapse:collapse;width:100%;font-size:9.5pt;margin:10pt 0 14pt;}
th{background:#142B45;color:white;font-weight:bold;text-align:left;}
th,td{border:1px solid #D9D9D9;padding:6pt;vertical-align:middle;}
tr{page-break-inside:avoid;} tr:nth-child(even){background:#F1F5F8;}
img{max-width:100%;height:auto;} blockquote{margin-left:0;font-weight:bold;}
'''
for stem in ('项目工作梳理报告','PPT详细大纲_5页'):
    md=(HERE/f'{stem}.md').read_text(encoding='utf-8')
    body=markdown.markdown(md,extensions=['tables','fenced_code'])
    def imgsize(m):
        src=m.group(1); path=(HERE/src).resolve()
        w,h=Image.open(path).size
        return f'src="{path.as_uri()}" width="624" height="{round(624*h/w)}"'
    body=re.sub(r'src="([^"]+)"',imgsize,body)
    def links(m):
        value=m.group(1)
        if value.startswith(('http:','https:','#','file:')): return m.group(0)
        return f'href="{(HERE/value).resolve().as_uri()}"'
    body=re.sub(r'href="([^"]+)"',links,body)
    content=f'<!DOCTYPE html><html><head><meta charset="utf-8"><title>{stem}</title><style>{css}</style></head><body>{body}</body></html>'
    (HERE/f'{stem}.html').write_text(content,encoding='utf-8')

# Audit facts and sources used by this report; no simulation or material claim.
sources=[ROOT/'CHANGELOG.md',ROOT/'README.md',ROOT/'docs/project_implementation_report.md',
         ROOT/'docs/upgrade_2026-09-24.md',ROOT/'docs/verasonics/linear64_oddeven_2026-10-12.md',
         ROOT/'verasonics/dual_mode/+icevs/default_config.m',
         ROOT/'independent_simulation/docs/kwave_oddeven_results_2026-10-19.md',
         ROOT/'independent_simulation/docs/ice_bench_poc_plan_2026-10-21.md',
         ROOT/'independent_simulation/docs/singlepoint_validation_2026-10-22.md',
         ROOT/'independent_simulation/docs/singlepoint_interpretation_2026-10-22.md',
         RES/'focus_summary.csv',RES/'sensitivity_summary.csv',RES/'exposure_summary.csv',
         RES/'interpretation_diagnostics.json',RES/'validation.json',
         ROOT/'independent_simulation/results/kwave_oddeven/grid_comparison.json']
audit={'compiled_on':'2026-10-23','source_cutoff':'2026-10-22',
       'operation':'Read saved sources and regenerate reporting figures only',
       'matlab_kwave_rerun':False,'vsx_or_hardware_run':False,'material_experiment':False,
       'report_uses_historical_test_records':True,'test_counts_are_not_additive':True,
       'slide_reference_pages':5,'editable_pptx_created':False,
       'source_hashes':{str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
       'fine52_peak_z_mm':float(fine['peak_z_mm']),
       'fine52_pressure_halfwidth_mm':widths,
       'wide65_global_peak_stability_passed':False,
       'source_pressure_calibration':'assumed 1 Pa source; physical calibration unknown',
       'manuals':[
           {'file':'Vantage NXT System Product Specification.pdf','version':'D00108 Rev. L','section':'1.4','printed_pages':'8-9','pdf_pages':'9-10'},
           {'file':'Vantage NXT System Initial Setup Instructions.pdf','version':'D00109 Rev. D','section':'4.5','printed_pages':'9-10','pdf_pages':'9-10'},
           {'file':'Vantage NXT System User Manual.pdf','version':'D00107 Rev. K','section':'4.4.1-4.4.2','printed_pages':'30','pdf_pages':'30'},
           {'file':'Vantage NXT Sequence Programming Manual.pdf','version':'D00163 Rev. K','section':'4.3.2; TX.Delay','printed_pages':'24-25; A171','pdf_pages':'24-25;310'}]}
for item in audit['manuals']:
    p=Path('F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10')/item['file']
    item['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
(HERE/'evidence_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'output':str(HERE),'figures':7,'slides':5,'source_files_hashed':len(sources)},ensure_ascii=False))
