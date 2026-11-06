"""Typeset report directly as PDF after native Word COM startup failed.

Uses repository Markdown text and original/replotted figures; no simulation runs.
"""
from pathlib import Path
import html
import json
import re
import sys

from bs4 import BeautifulSoup
import fitz
import markdown
from PIL import Image
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Image as RLImage,
    LongTable, TableStyle, KeepTogether, CondPageBreak,
)

sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent
QA=HERE/'qa'
pdfmetrics.registerFont(TTFont('Yahei','C:/Windows/Fonts/msyh.ttc'))
pdfmetrics.registerFont(TTFont('YaheiBold','C:/Windows/Fonts/msyhbd.ttc'))
pdfmetrics.registerFontFamily('Yahei',normal='Yahei',bold='YaheiBold',italic='Yahei',boldItalic='YaheiBold')
BLUE=colors.HexColor('#142B45')
GREY=colors.HexColor('#536477')
TEAL=colors.HexColor('#008C95')
styles={
    'body':ParagraphStyle('body',fontName='Yahei',fontSize=10.5,leading=17.4,
                          spaceAfter=7,wordWrap='CJK',textColor=colors.HexColor('#172535'),allowWidows=0,allowOrphans=0),
    'h1':ParagraphStyle('h1',fontName='YaheiBold',fontSize=23,leading=33,spaceAfter=18,textColor=colors.black,keepWithNext=True,wordWrap='CJK'),
    'h2':ParagraphStyle('h2',fontName='YaheiBold',fontSize=15,leading=22,spaceBefore=15,spaceAfter=8,textColor=colors.black,keepWithNext=True,wordWrap='CJK'),
    'h3':ParagraphStyle('h3',fontName='YaheiBold',fontSize=11.8,leading=19,spaceBefore=9,spaceAfter=6,textColor=colors.black,keepWithNext=True,wordWrap='CJK'),
    'cell':ParagraphStyle('cell',fontName='Yahei',fontSize=8.5,leading=13.4,wordWrap='CJK',textColor=BLUE),
    'headcell':ParagraphStyle('headcell',fontName='YaheiBold',fontSize=8.8,leading=13.8,wordWrap='CJK',textColor=colors.white),
    'caption':ParagraphStyle('caption',fontName='Yahei',fontSize=8.8,leading=13.5,spaceBefore=4,spaceAfter=10,wordWrap='CJK',textColor=GREY),
}

def rich(tag):
    if isinstance(tag,str): return html.escape(tag)
    out=''
    for node in tag.children:
        if isinstance(node,str): out+=html.escape(str(node))
        elif node.name in ('strong','b'): out+='<b>'+rich(node)+'</b>'
        elif node.name in ('em','i'): out+=rich(node)
        elif node.name=='code': out+=rich(node)
        elif node.name=='br': out+='<br/>'
        elif node.name=='a':
            href=node.get('href','')
            if not href.startswith(('http://','https://')):
                href=(HERE/href).resolve().as_uri()
            out+=f'<link href="{html.escape(href,quote=True)}" color="#176273">'+rich(node)+'</link>'
        else: out+=rich(node)
    return out

source=HERE/'项目工作梳理报告.md'
soup=BeautifulSoup(markdown.markdown(source.read_text(encoding='utf-8'),extensions=['tables']),'html.parser')
flow=[]
contentwidth=522
tables=0
images=0
nodes=[node for node in soup.children if not isinstance(node,str)]
for idx,node in enumerate(nodes):
    if node.name in ('h1','h2','h3'):
        if idx+1<len(nodes) and nodes[idx+1].find('img'):
            upcoming=nodes[idx+1].find('img')
            iw,ih=Image.open(HERE/upcoming['src']).size
            flow.append(CondPageBreak(min(310,contentwidth*ih/iw)+80))
        flow.append(Paragraph(rich(node),styles[node.name]))
    elif node.name=='p':
        pic=node.find('img')
        if pic:
            p=HERE/pic['src']
            w,h=Image.open(p).size
            width=contentwidth
            height=width*h/w
            if height>310:
                height=310; width=height*w/h
            image=RLImage(str(p),width=width,height=height)
            image.hAlign='CENTER'
            flow.append(KeepTogether([Spacer(1,6),image,Paragraph(html.escape(pic.get('alt','')),styles['caption'])]))
            images+=1
        else: flow.append(Paragraph(rich(node),styles['body']))
    elif node.name=='table':
        rows=node.find_all('tr')
        count=len(rows[0].find_all(['td','th']))
        is_index=False
        if count==3:
            # Date/record tables: concise first column, two explanatory columns.
            first=rows[0].find_all(['td','th'])[0].get_text()
            is_index='编号' in first
            widths=[55,280,187] if is_index else [103,210,209]
        elif count==4: widths=[157,110,115,140]
        else: widths=[contentwidth/count]*count
        cells=[]
        for i,row in enumerate(rows):
            cells.append([Paragraph(rich(c),styles['headcell' if i==0 else 'cell']) for c in row.find_all(['td','th'])])
        table=LongTable(cells,colWidths=widths,repeatRows=1,hAlign='LEFT')
        table.setStyle(TableStyle([
            ('BACKGROUND',(0,0),(-1,0),BLUE),
            ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#F1F5F8')]),
            ('GRID',(0,0),(-1,-1),.45,colors.HexColor('#D9D9D9')),
            ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
            ('TOPPADDING',(0,0),(-1,-1),4 if is_index else 6),('BOTTOMPADDING',(0,0),(-1,-1),4 if is_index else 6),
            ('VALIGN',(0,0),(-1,-1),'MIDDLE'),
            ('NOSPLIT',(0,-2),(-1,-1)),
        ]))
        flow.extend([Spacer(1,5),table,Spacer(1,12)])
        tables+=1
    elif node.name in ('ul','ol'):
        for li in node.find_all('li',recursive=False):
            flow.append(Paragraph('• '+rich(li),styles['body']))
    elif node.name=='blockquote': flow.append(Paragraph(rich(node),styles['body']))

def header(canvas,doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor('#D9E0E7'))
    canvas.line(45,754,567,754)
    canvas.setFillColor(GREY)
    canvas.setFont('Yahei',8)
    canvas.drawString(45,764,'ICE-Sonocuring / 项目工作与研究思路梳理')
    canvas.restoreState()

temp=QA/'report_unpaged.pdf'
doc=SimpleDocTemplate(str(temp),pagesize=(612,792),rightMargin=45,leftMargin=45,
                      topMargin=51,bottomMargin=46,title='ICE-Sonocuring 项目工作与研究思路梳理报告',
                      author='',subject='2026年9月—10月项目进展；基于保存记录的阶段梳理')
doc.build(flow,onFirstPage=header,onLaterPages=header)
pdf=fitz.open(temp)
page_summary=[]
for i,page in enumerate(pdf):
    page.insert_text((45,772),f'2026.10.23  |  Evidence-based project review',fontsize=8,color=(.33,.39,.46))
    page.insert_text((505,772),f'{i+1:02} / {len(pdf):02}',fontsize=8,color=(.33,.39,.46))
    page.get_pixmap(matrix=fitz.Matrix(1.5,1.5),alpha=False).save(QA/f'page-{i+1}.png')
    txt=page.get_text()
    page_summary.append({'page':i+1,'text_characters':len(txt),'text_beginning':txt[:100]})
pdf.save(HERE/'项目工作梳理报告.pdf',deflate=True)
all_text='\n'.join(p.get_text() for p in pdf)
(QA/'pdf_readback.txt').write_text(all_text,encoding='utf-8')
pdf.close()
cols=3
thumbw,thumbh=306,396
rows=(len(page_summary)+cols-1)//cols
sheet=Image.new('RGB',(cols*(thumbw+16)+16,rows*(thumbh+28)+16),'#E8EDF2')
from PIL import ImageDraw
sd=ImageDraw.Draw(sheet)
for i in range(len(page_summary)):
    pic=Image.open(QA/f'page-{i+1}.png')
    pic.thumbnail((thumbw,thumbh))
    x=16+(i%cols)*(thumbw+16); y=16+(i//cols)*(thumbh+28)
    sheet.paste(pic,(x,y))
    sd.text((x+4,y+thumbh+3),str(i+1),fill='black')
sheet.save(QA/'report_contact_sheet.png')
stats={'pages':len(page_summary),'tables':tables,'images':images,'page_summary':page_summary,
       'native_word_status':'COM activation failed 0x80080005; report typeset directly as PDF',
       'docx_delivered':False,'report_markdown_editable':True}
(QA/'pdf_stats.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in stats.items() if k!='page_summary'},ensure_ascii=False))
