from pathlib import Path
import xml.etree.ElementTree as E
from PIL import Image,ImageDraw,ImageFont
import math,re,html
out=Path('output/diagrams'); W,H=1250,880
mx=E.Element('mxfile',host='app.diagrams.net',type='device',version='24.7.17')
diagram=E.SubElement(mx,'diagram',id='v10b-system',name='System Model')
model=E.SubElement(diagram,'mxGraphModel',dx='1250',dy='880',grid='0',gridSize='10',guides='1',tooltips='1',connect='1',arrows='1',fold='1',page='1',pageScale='1',pageWidth=str(W),pageHeight=str(H),math='0',shadow='0')
root=E.SubElement(model,'root');E.SubElement(root,'mxCell',id='0')
layers={}
for n in ['Ground','Radio links','Trajectory','Nodes','Labels','Service sequence']:
 lid=str(len(layers)+1);layers[n]=lid;E.SubElement(root,'mxCell',id=lid,value=n,parent='0')
ops=[];count=20; offsets={}; anchors={}
colors={'bs':'#24577C','rf':'#CE7629','dl':'#945298','path':'#2B827E','ink':'#26323C'}
def ident():
 global count
 count+=1;return 'c'+str(count)
def group(name,x,y,w,h):
 i=ident(); c=E.SubElement(root,'mxCell',id=i,value='',style='group',vertex='1',connectable='0',parent=layers['Nodes']);E.SubElement(c,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),attrib={'as':'geometry'});offsets[i]=(x,y);return i
def shape(kind,x,y,w,h,fill='none',stroke='none',text='',size=18,parent=None,dashed=False,bold=False):
 i=ident(); parent=parent or layers['Labels']; local=offsets.get(parent,(0,0)); gx,gy=x+local[0],y+local[1]
 style=f'shape={kind};whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};strokeWidth=1.6;fontFamily=Times New Roman;fontSize={size};fontColor={colors["ink"]};fontStyle={1 if bold else 0};align=center;verticalAlign=middle;spacing=2;'
 if dashed:style+='dashed=1;dashPattern=5 4;'
 c=E.SubElement(root,'mxCell',id=i,value=text,style=style,vertex='1',parent=parent)
 E.SubElement(c,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),attrib={'as':'geometry'})
 ops.append((parent,kind,gx,gy,w,h,fill,stroke,text,size,dashed,bold));return i
def line(points,color='#26323C',width=1.6,dashed=False,arrow=False,parent=None,source=None,target=None):
 i=ident(); parent=parent or layers['Labels']; off=offsets.get(parent,(0,0)); gp=[(x+off[0],y+off[1]) for x,y in points]
 attrs={'id':i,'value':'','style':f'edgeStyle=none;rounded=0;html=1;strokeColor={color};strokeWidth={width};endArrow={"classic" if arrow else "none"};endFill=1;startArrow=none;'+('dashed=1;dashPattern=6 4;' if dashed else ''),'edge':'1','parent':parent}
 if source:attrs['source']=source
 if target:attrs['target']=target
 c=E.SubElement(root,'mxCell',**attrs);g=E.SubElement(c,'mxGeometry',relative='1',attrib={'as':'geometry'})
 for tag,p in [('sourcePoint',points[0]),('targetPoint',points[-1])]:E.SubElement(g,'mxPoint',x=str(p[0]),y=str(p[1]),attrib={'as':tag})
 if len(points)>2:
  a=E.SubElement(g,'Array',attrib={'as':'points'})
  for x,y in points[1:-1]:E.SubElement(a,'mxPoint',x=str(x),y=str(y))
 ops.append((parent,'line',gp,color,width,dashed,arrow));return i
def text(s,x,y,w=180,h=30,size=18,bold=False,parent=None):return shape('rectangle',x,y,w,h,text=s,size=size,bold=bold,parent=parent)
# Ground plane: native rhomboid, with separately editable axes.
shape('parallelogram',70,390,1050,290,'#EFF6F6','#729C9C',parent=layers['Ground'])
line([(150,390),(1170,390)],'#607E7E',arrow=True,parent=layers['Ground']);text('Y',1160,355,40)
line([(150,390),(40,710)],'#607E7E',arrow=True,parent=layers['Ground']);text('X',15,702,40)
line([(150,390),(150,105)],'#607E7E',arrow=True,parent=layers['Ground']);text('Z',125,75,40)
# Legend.
text('SWIPT-enabled UAV-assisted NOMA network',270,40,650,35,23,True)
for j,(col,dash,lab) in enumerate([(colors['rf'],True,'BS-to-UAV SWIPT reception'),(colors['dl'],False,'Downlink NOMA'),('#555555',True,'Straight reference trajectory'),(colors['path'],False,'Optimized horizontal trajectory')]):
 y=94+j*30;line([(930,y),(980,y)],col,2,dash,True);text(lab,990,y-14,245,29,15)
# Flight and projections. Constant-altitude schematic.
route=[(255,270),(400,210),(610,225),(765,245),(920,270)]
line([(255,270),(920,270)],'#555555',1.7,True,parent=layers['Trajectory'])
line(route,colors['path'],3,parent=layers['Trajectory'])
for x,y in [route[0],route[-1]]:line([(x,y),(x,y+210)],'#708388',1.3,True,parent=layers['Trajectory'])
for x,y in route:shape('ellipse',x-5,y-5,10,10,'#CF3984','none',parent=layers['Trajectory'])
text('Start q<sub>S</sub>',190,285,125);text('End q<sub>E</sub>',865,285,125)
line([(1140,200),(1140,410)],'#64717B',1.4,False,True);text('H',1147,280,60,30,21)
# BS icons: grouped native editable shapes.
for n,(x,y) in enumerate([(190,520),(1050,465),(900,630)],1):
 g=group('BS '+str(n),x-35,y-75,70,110)
 shape('rectangle',-22,62,114,36,'none','#A1B6C4',parent=g,dashed=True)
 line([(10,75),(35,15),(60,75)],colors['bs'],2.5,parent=g)
 line([(19,53),(52,53)],colors['bs'],1.7,parent=g);line([(15,65),(56,65)],colors['bs'],1.7,parent=g)
 line([(23,40),(47,40)],colors['bs'],1.7,parent=g)
 shape('ellipse',30,8,10,10,colors['bs'],'none',parent=g)
 shape('ellipse',19,0,32,32,'none','#C5A44D',parent=g)
 text('BS '+str(n),-10,85,90,25,18,True,parent=g)
 anchors['bs'+str(n)]=shape('ellipse',32,10,6,6,'none','none',parent=g)
 anchors['p'+str(n)]=(x,y-62)
# UAV icon.
g=group('UAV',565,178,90,65)
for a,b in [((15,15),(75,49)),((15,49),(75,15))]:line([a,b],colors['bs'],4,parent=g)
for x,y in [(15,15),(75,15),(15,49),(75,49)]:shape('ellipse',x-15,y-5,30,10,'#D9E9F0',colors['bs'],parent=g)
shape('ellipse',33,19,24,25,colors['bs'],colors['bs'],parent=g)
anchors['uav']=shape('ellipse',41,27,8,8,'none','none',parent=g)
text('UAV',540,130,140,30,22,True);text('q<sub>t</sub> = (x<sub>t</sub>, y<sub>t</sub>, H)',650,186,240,35,19)
# User icons.
users=[(400,500),(535,570),(650,515),(765,585),(335,625)]
for n,(x,y) in enumerate(users,1):
 g=group('UE '+str(n),x-18,y-22,50,65)
 shape('ellipse',10,0,16,16,colors['ink'],'none',parent=g)
 shape('rectangle',5,20,26,20,colors['ink'],'none',parent=g)
 shape('rectangle',-5,23,7,17,'#E1ECF5',colors['bs'],parent=g)
 text('UE '+str(n),-12,43,80,24,17,parent=g)
 anchors['ue'+str(n)]=shape('ellipse',14,3,6,6,'none','none',parent=g)
# Connected radio links. Nodes remain independent editable groups.
for n in range(1,4):line([anchors['p'+str(n)],(610,210)],colors['rf'],2,True,True,layers['Radio links'],anchors['bs'+str(n)],anchors['uav'])
for n,(x,y) in enumerate(users,1):line([(610,240),(x,y-15)],colors['dl'],1.7,False,True,layers['Radio links'],anchors['uav'],anchors['ue'+str(n)])
text('Service waypoints',380,300,180,30,16)
text('BS deployment regions: horizontal positions selected before the mission',270,690,760,28,16)
# One compact sequence, not separate panels.
for j,(label,col) in enumerate([('1  Hover: receive & harvest','#FAEFE3'),('2  Hover: downlink NOMA','#F3EAF4'),('3  Fly to the next waypoint','#E5F1EF')]):
 x=135+j*335;shape('rectangle',x,748,290,44,col,'#C2CDCF',html.escape(label),17,parent=layers['Service sequence'])
 if j<2:line([(x+296,770),(x+326,770)],'#677780',1.5,arrow=True,parent=layers['Service sequence'])
text('Harvested energy → RF transmission     |     Onboard battery → cruise and hover',180,815,900,28,17)
# Write portable, uncompressed draw.io XML.
E.indent(mx,space='  ');path=out/'V10B_System_Model.drawio';E.ElementTree(mx).write(path,encoding='utf-8',xml_declaration=True)
# Preview from the same native primitive geometry.
scale=2;im=Image.new('RGB',(W*scale,H*scale),'white');d=ImageDraw.Draw(im)
fontdir=Path('/System/Library/Fonts/Supplemental')
def font(sz,b=False):return ImageFont.truetype(str(fontdir/('Times New Roman Bold.ttf' if b else 'Times New Roman.ttf')),round(sz*scale))
def pts(p):return [(round(x*scale),round(y*scale)) for x,y in p]
layerorder={v:k for k,v in enumerate(layers.values())}
def order(op):return 3 if op[0] in offsets else layerorder[op[0]]
for op in sorted(ops,key=order):
 if op[1]=='line':
  _,_,p,col,wd,dash,arr=op;wp=pts(p)
  for a,b in zip(wp,wp[1:]):
   if dash:
    le=math.dist(a,b)
    for st in range(0,max(1,int(le)),18):
     f=st/max(le,1);e=min(st+10,le)/max(le,1);d.line([(a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f),(a[0]+(b[0]-a[0])*e,a[1]+(b[1]-a[1])*e)],fill=col,width=max(1,round(wd*scale)))
   else:d.line([a,b],fill=col,width=max(1,round(wd*scale)))
  if arr:
   a,b=wp[-2:];ang=math.atan2(b[1]-a[1],b[0]-a[0]);r=10*scale;d.polygon([b,(b[0]-r*math.cos(ang-.38),b[1]-r*math.sin(ang-.38)),(b[0]-r*math.cos(ang+.38),b[1]-r*math.sin(ang+.38))],fill=col)
 else:
  _,kind,x,y,w,h,fill,stroke,txt,sz,dash,bold=op;box=(x*scale,y*scale,(x+w)*scale,(y+h)*scale);f=None if fill=='none' else fill;st=None if stroke=='none' else stroke
  if kind=='ellipse':d.ellipse(box,fill=f,outline=st,width=3)
  elif kind=='parallelogram':d.polygon(pts([(x+w*.2,y),(x+w,y),(x+w*.8,y+h),(x,y+h)]),fill=f,outline=st,width=3)
  elif f is not None or st is not None:d.rectangle(box,fill=f,outline=st,width=2)
  if txt:
   tx=html.unescape(re.sub('<[^>]+>','',txt));d.text(((x+w/2)*scale,(y+h/2)*scale),tx,font=font(sz,bold),fill=colors['ink'],anchor='mm')
im.resize((W,H),Image.Resampling.LANCZOS).save(out/'V10B_System_Model_preview.png')
# Structural checks.
r=E.parse(path);cells=r.findall('.//mxCell');ids=[c.get('id') for c in cells];assert len(ids)==len(set(ids))
for c in cells:
 for key in ['parent','source','target']:
  if c.get(key):assert c.get(key) in ids
print(path.resolve());print('Validated:',len(cells),'native cells; 6 editable layers; 8 connected radio links.')
