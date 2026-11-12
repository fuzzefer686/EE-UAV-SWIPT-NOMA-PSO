from pathlib import Path
import xml.etree.ElementTree as E
base=Path('tmp/drawio/create_model.py').read_text()
prefix=base.split('# Ground plane:')[0].replace('W,H=1250,880','W,H=1250,1080').replace("name='System Model'","name='Components'").replace("id='v10b-system'","id='v10b-components'")
exec(compile(prefix,'component_helpers','exec'))
text('SYSTEM MODEL: EDITABLE COMPONENTS',200,22,850,42,26,True)
text('Select an icon group, copy it, and arrange it in your own diagram.',200,69,850,30,18)

def heading(s,y):
 text(s,55,y,1140,30,20,True)
 line([(55,y+37),(1195,y+37)],'#D6DFE2',1)
def caption(s,x,y,w=210):text(s,x,y,w,28,17)

def uav(x,y,ink):
 g=group('UAV',x,y,150,100)
 for a,b in [((27,22),(123,78)),((27,78),(123,22))]:line([a,b],ink,5,parent=g)
 for xx,yy in [(27,22),(123,22),(27,78),(123,78)]:shape('ellipse',xx-24,yy-8,48,16,'#EEF5F8',ink,parent=g)
 shape('ellipse',57,30,36,40,ink,ink,parent=g)
 shape('ellipse',68,44,14,14,'#FFFFFF','none',parent=g)
 return g

def tower(x,y):
 g=group('BS tower',x,y,100,120)
 line([(12,114),(50,28),(88,114)],colors['bs'],3,parent=g)
 for yy,xx in [(58,36),(79,27),(100,18)]:line([(xx,yy),(100-xx,yy)],colors['bs'],2,parent=g)
 line([(27,79),(73,100)],colors['bs'],1.6,parent=g)
 line([(73,79),(27,100)],colors['bs'],1.6,parent=g)
 for r in [32,48]:shape('ellipse',50-r/2,25-r/2,r,r,'none','#BA9337',parent=g)
 shape('ellipse',45,20,10,10,colors['bs'],'none',parent=g)
 return g

def user(x,y):
 g=group('Ground user',x,y,80,110)
 shape('ellipse',28,4,24,24,colors['ink'],'none',parent=g)
 shape('rectangle',23,35,34,35,colors['ink'],'none',parent=g)
 line([(28,70),(24,101)],colors['ink'],6,parent=g);line([(52,70),(57,101)],colors['ink'],6,parent=g)
 line([(23,43),(9,62)],colors['ink'],5,parent=g)
 shape('rectangle',4,42,10,20,'#DDEAF4',colors['bs'],parent=g)
 return g
heading('1. NODE ICONS — grouped vector shapes',115)
uav(110,185,colors['bs']);caption('UAV / quadrotor',80,305)
uav(390,185,'#26323C');caption('UAV / monochrome',355,305)
tower(710,170);caption('Base station',655,305)
user(1010,175);caption('Ground user + handset',945,305,240)

heading('2. GEOMETRY AND MARKERS',355)
shape('parallelogram',75,420,235,130,'#ECF5F5','#729C9C',parent=layers['Ground']);caption('Ground plane',80,565,230)
# Coordinate axes grouped so they can be moved together.
g=group('XYZ coordinate axes',380,425,195,130)
line([(35,90),(185,90)],'#52616C',1.8,arrow=True,parent=g)
line([(35,90),(35,0)],'#52616C',1.8,arrow=True,parent=g)
line([(35,90),(0,125)],'#52616C',1.8,arrow=True,parent=g)
text('X',0,98,24,24,18,parent=g);text('Y',166,58,24,24,18,parent=g);text('Z',39,0,24,24,18,parent=g)
caption('X / Y / Z axes',365,565,235)
shape('rectangle',680,438,180,90,'none','#8BA2B1',dashed=True);caption('BS deployment region',650,565,240)
for x,fill in [(960,'#D43F8D'),(1045,'#E7A73F'),(1130,'#26323C')]:shape('ellipse',x,465,18,18,fill,'none')
caption('Waypoint / start / end',930,565,270)

heading('3. LINKS AND TRAJECTORY SAMPLES — independent editable lines',610)
rows=[(105,680,colors['rf'],True,True,'SWIPT reception'),(510,680,'#C8453C',False,True,'Information link'),(910,680,colors['dl'],False,True,'Downlink NOMA'),(105,785,'#24577C',True,True,'Power transfer'),(510,785,'#26323C',False,True,'Distance indicator'),(910,785,'#555555',True,False,'Reference trajectory')]
for x,y,col,dash,arr,label in rows:
 edge=line([(x,y),(x+210,y)],col,2.2,dash,arr)
 if label=='Distance indicator':
  cell=root.find(f"mxCell[@id='{edge}']");cell.set('style',cell.get('style')+'startArrow=classic;startFill=1;')
 caption(label,x-20,y+18,250)
line([(115,875),(175,840),(240,855),(310,835)],colors['path'],3)
caption('Optimized trajectory: move the bend points',65,900,340)

heading('4. COPYABLE TEXT LABELS',945)
for x,s in [(70,'UAV'),(185,'BS<sub>m</sub>'),(300,'UE<sub>n</sub>'),(415,'q<sub>t</sub>'),(530,'q<sub>S</sub>'),(645,'q<sub>E</sub>'),(760,'H'),(875,'h<sub>t,n</sub>'),(990,'k<sub>t,m</sub>'),(1100,'α<sub>t,n</sub>')]:text(s,x,1003,95,35,22)
# Portable draw.io XML; all objects are native editable elements.
E.indent(mx,space='  ')
path=out/'V10B_System_Model_Components.drawio'
E.ElementTree(mx).write(path,encoding='utf-8',xml_declaration=True)
r=E.parse(path); cells=r.findall('.//mxCell');ids=[c.get('id') for c in cells]
assert len(ids)==len(set(ids))
for c in cells:
 for k in ['parent','source','target']:
  if c.get(k):assert c.get(k) in ids
 assert 'image=' not in c.get('style','')
assert len(r.findall('.//diagram'))==1
renderer=base.split('# Preview from the same native primitive geometry.')[1].split('# Structural checks.')[0].replace("out/'V10B_System_Model_preview.png'","out/'V10B_System_Model_Components_preview.png'")
exec(compile(renderer,'preview','exec'))
print(path.resolve());print('Validated:',len(cells),'native editable cells; grouped icons; no embedded bitmap images.')
