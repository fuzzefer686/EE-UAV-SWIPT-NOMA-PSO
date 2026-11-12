"""Create the Vietnamese A4 results report from previously audited V10 data."""
from pathlib import Path
import csv
import hashlib
import json
import statistics as st
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Table, TableStyle, Image, Spacer, PageBreak,
    KeepTogether, HRFlowable,
)
from PIL import Image as PILImage

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SOURCE = HERE/'data'
OUT = ROOT/'output/pdf/V10A_V10B_Bao_cao_ket_qua_20261105.pdf'
OUT.parent.mkdir(exist_ok=True)
raw = json.loads((SOURCE/'extracted_results.json').read_text())
unique = {}
for r in raw:
    unique.setdefault(tuple(r[k] for k in ['variant','seed','L','slot','hover','algorithm']), r)
rows = list(unique.values())
assert len(raw)==216 and len(rows)==168
SEEDS = [2026,608060,3486784401]
ALGOS = ['Joint PSO','Full PSO','Full IPSO']

def pick(v=None,a=None,L=None,q=None,h=None,seed=None):
    params=dict(variant=v,algorithm=a,L=L,slot=q,hover=h,seed=seed)
    return [r for r in rows if all(z is None or r[k]==z for k,z in params.items())]

fontdir=Path('/System/Library/Fonts/Supplemental')
for name, file in [('Body','Arial.ttf'),('Body-Bold','Arial Bold.ttf'),
                   ('Body-Italic','Arial Italic.ttf'),('Body-BoldItalic','Arial Bold Italic.ttf')]:
    pdfmetrics.registerFont(TTFont(name,str(fontdir/file)))
pdfmetrics.registerFontFamily('Body',normal='Body',bold='Body-Bold',italic='Body-Italic',boldItalic='Body-BoldItalic')
NAVY=colors.HexColor('#183C52')
TEAL=colors.HexColor('#087B79')
ORANGE=colors.HexColor('#AE5A19')
INK=colors.HexColor('#263740')
MUTED=colors.HexColor('#596D77')
PALE=colors.HexColor('#EDF3F6')
WIDTH=A4[0]-102
styles={
 'title':ParagraphStyle('Title',fontName='Body-Bold',fontSize=23,leading=28,textColor=NAVY,spaceAfter=12),
 'h1':ParagraphStyle('Heading1',fontName='Body-Bold',fontSize=17,leading=22,textColor=NAVY,spaceAfter=11),
 'h2':ParagraphStyle('Heading2',fontName='Body-Bold',fontSize=11.4,leading=16,textColor=TEAL,spaceBefore=9,spaceAfter=5),
 'body':ParagraphStyle('Body',fontName='Body',fontSize=10.1,leading=14.7,textColor=INK,spaceAfter=7,alignment=TA_LEFT),
 'small':ParagraphStyle('Small',fontName='Body',fontSize=9,leading=12.7,textColor=INK,spaceAfter=6),
 'caption':ParagraphStyle('Caption',fontName='Body',fontSize=8.3,leading=11.5,textColor=MUTED,spaceBefore=5,spaceAfter=9),
 'table':ParagraphStyle('Table',fontName='Body',fontSize=9,leading=12,textColor=INK),
 'thead':ParagraphStyle('THead',fontName='Body-Bold',fontSize=8.8,leading=11.8,textColor=colors.white),
 'tiny':ParagraphStyle('Tiny',fontName='Body',fontSize=8.2,leading=10.5,textColor=INK),
 'eq':ParagraphStyle('Equation',fontName='Body',fontSize=11,leading=18,textColor=NAVY,alignment=TA_CENTER,spaceBefore=5,spaceAfter=9),
}
story=[]
def p(text,style='body'):
    # Arial contains Vietnamese and the standard operators, but not the full
    # Unicode subscript/superscript range. Use PDF-native text positioning.
    for old,new in [('x₁','x<sub>1</sub>'),('x₂','x<sub>2</sub>'),('x₃','x<sub>3</sub>'),
                    ('y₁','y<sub>1</sub>'),('y₂','y<sub>2</sub>'),('y₃','y<sub>3</sub>'),
                    ('10⁻³','10<super>-3</super>'),('10⁻⁸','10<super>-8</super>')]:
        text=text.replace(old,new)
    text=text.replace('–','-').replace('—','-').replace('‑','-')
    return Paragraph(text,styles[style])
def add(text,style='body'):
    story.append(p(text,style))
def h(text):add(text,'h2')
def page(title):
    if story:story.append(PageBreak())
    add(title,'h1')
def caption(text):add(text,'caption')
def fmt(n,d=1):
    return f'{n:,.{d}f}'.replace(',',' ').replace('.',',')
def cell(x,small=False):
    return p(str(x),'tiny' if small else 'table')
def table(headers,body,widths,small=False,pad=5,split=(),notes=None):
    data=[[p(str(x),'thead') for x in headers]]
    data += [[cell(x,small) for x in rr] for rr in body]
    t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
    cmds=[('BACKGROUND',(0,0),(-1,0),NAVY),('VALIGN',(0,0),(-1,-1),'TOP'),
          ('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),
          ('TOPPADDING',(0,0),(-1,-1),pad),('BOTTOMPADDING',(0,0),(-1,-1),pad),
          ('LINEBELOW',(0,0),(-1,0),.6,NAVY),('LINEBELOW',(0,-1),(-1,-1),.6,NAVY)]
    for i in range(1,len(data)):
        if i%2==0:cmds.append(('BACKGROUND',(0,i),(-1,i),colors.HexColor('#F5F8FA')))
    for i in split:cmds.append(('LINEABOVE',(0,i),(-1,i),.6,colors.HexColor('#9AAEBB')))
    t.setStyle(TableStyle(cmds));story.append(t)
    if notes:caption(notes)
def fig(stem,width=WIDTH):
    path=HERE/'figures'/f'{stem}.png'
    with PILImage.open(path) as im:w,hh=im.size
    story.append(Image(str(path),width=width,height=width*hh/w,hAlign='CENTER'))
def sweep_table(sweep):
    data=[]
    vals=[1e6,2e6,3e6] if sweep=='L' else [0,5000,10000]
    for v in 'AB':
        for val in vals:
            rr=pick(v,L=val if sweep=='L' else 3e6,q=5000 if sweep=='L' else val,h=1)
            line=['V10'+v,str(int(val/(1e6 if sweep=='L' else 1000)))]
            for a in ALGOS:
                good=[r['ee'] for r in rr if r['algorithm']==a and r['feasible']]
                line.append((fmt(st.mean(good)) if good else '—')+f' ({len(good)}/3)')
            data.append(line)
    table(['Bản','L (Mbit/user)' if sweep=='L' else 'q (kbit/user/slot)','JointPSO','Full PSO','IPSO'],data,
          [43,106,114,114,WIDTH-377],pad=5,split=[4])

# Page 1: a report opening, rather than a standalone decorative cover.
add('BÁO CÁO KẾT QUẢ<br/>V10A VÀ V10B','title')
add('Hiệu suất năng lượng, quỹ đạo UAV và vị trí trạm gốc BS','h2')
add('Dữ liệu campaign ngày 29/10/2026 · Tổng hợp ngày 05/11/2026','small')
story.append(Spacer(1,7))
add('Báo cáo tổng hợp các lần chạy đã lưu, đối chiếu V10A với V10B và đánh giá JointPSO, Full PSO, IPSO. Trọng tâm là EE theo yêu cầu dữ liệu L và q, hình học quỹ đạo tại L = 3 Mbit/user, cùng khả năng giảm số biến bằng cách cố định một phần tọa độ BS.')
h('Kết quả đáng chú ý')
for text in [
 '<b>V10B khai thác tốt hơn không gian phục vụ theo Y.</b> Với IPSO, B có EE cao hơn A ở cả 21 cặp cấu hình khác nhau; trung bình gain ghép cặp là <b>55,79%</b>. Đây là kết quả trong campaign đã chạy, chưa phải chứng minh tối ưu toàn cục.',
 '<b>IPSO có tỷ lệ tìm nghiệm khả thi cao nhất.</b> Sau loại trùng, IPSO đạt tất cả ràng buộc ở 42/42 tổ hợp A/B; Full PSO đạt 41/42, JointPSO đạt 24/42. Baseline chỉ đạt 2/42 nên chỉ được nhắc như mốc tham chiếu.',
 '<b>Vị trí BS có xu hướng chạm biên miền tìm kiếm.</b> Ở bộ L = 3 Mbit, q = 5 kbit/user/slot, hover 1 s, cả 12 nghiệm Full PSO/IPSO đặt BS3 tại (250; 50; 25) m. Khi mở rộng sang mọi q và hover ở L = 3, vị trí này chỉ xuất hiện ở 49/59 nghiệm khả thi.',
 '<b>EE cao hơn đi kèm dữ liệu tập trung hơn.</b> Jain trung bình của IPSO giảm từ 0,749 ở A xuống 0,569 ở B. Cần xem EE cùng fairness và lượng dữ liệu từng user khi chọn cấu hình.'
]:add(text)
h('Phạm vi và nguyên tắc đọc số liệu')
add('Nguồn chính gồm 54 run với ba scenario seed: 2026, 608060 và 3486784401. Mỗi run có bốn phương pháp, tổng cộng 216 kết quả. Các nhãn L = 3, q = 5, hover = 1 ở ba sweep trùng tham số và kết quả; sau loại trùng còn <b>42 run cấu hình khác nhau, tương ứng 168 kết quả phương pháp</b>. [2,4]')
add('Trung bình EE chỉ lấy nghiệm khả thi và ghi kèm số seed đóng góp. Full PSO/IPSO dùng kết quả sau polishing alpha. Báo cáo không chạy lại MATLAB, không đổi solver và chưa kiểm chứng mức mất EE khi cố định BS.','small')

# Page 2
page('1. Mô hình, phần kế thừa Drones và khác biệt A/B')
h('1.1. Những phần lấy từ bài Drones')
table(['Thành phần','Kế thừa / điều chỉnh trong V10'],[
 ['Động cơ','Dùng Eq. (10)–(11) và Table 2 của [1]: bốn rotor; công suất profile, induced và parasite. Lực đẩy được lấy theo độ lớn của cân bằng lực.'],
 ['Bay và phục vụ','Bay ngang ở độ cao cố định, cùng tốc độ hành trình. V10 dùng Z = 30 m, v = 15,521 m/s và phục vụ khi hover.'],
 ['Năng lượng','Kế thừa E_bay = P_f(v)D/v và budget 17 kJ; V10 bổ sung riêng năng lượng động cơ hover P_f(0)∑h_n. Biểu thức in trong bài không tách hạng này.'],
 ['Mục tiêu / giao thức','Bài báo tối đa sum-throughput cho BackCom, dùng KKT/GSS và TSP/GA. V10 giữ SWIPT–NOMA và PSO/IPSO của dự án, tối đa tỷ số bit/J.']
],[91,WIDTH-91],small=True,pad=5)
caption('Bảng 1. Phần kế thừa chung cho V10A/V10B. Bài báo dùng hover 0,1 s và Z = 50 m trong mô phỏng; V10 khảo sát hover 1/2/3 s. [1,3]')
add('EE = D<sub>tổng</sub> / (E<sub>bay</sub> + E<sub>hover</sub> + E<sub>RF</sub>)','eq')
add('Mỗi user phải đạt ∑<sub>n</sub>D<sub>u,n</sub> ≥ L và D<sub>u,n</sub> ≥ q ở từng slot phục vụ. Có 20 lần phục vụ và 20 đoạn bay: EH/UL trong h/2, RF/DL trong h/2, rồi bay trong d/v. EH cấp RF lý tưởng; không cấp động cơ. Cruise tính được 108,9408 W, hover 172,3876 W. Cruise lệch khoảng 0,0266% so với mức 108,9118 W bài công bố. [1,3]','small')
h('1.2. Biến tối ưu và thuật toán')
table(['Nội dung','V10A','V10B'],[
 ['Quỹ đạo','Tối ưu X; Y giảm đều 15 m/đoạn','Tối ưu X/Y; Y giảm ít nhất 1 m/đoạn'],
 ['Chung','Z = 30 m; 21 waypoint; 75 ≤ X ≤ 225 m','Đầu (150;300;30), cuối (150;0;30) m'],
 ['Số biến Joint / Full','124 / 130','143 / 149']
],[91,197,WIDTH-288],small=True,pad=4)
add('<b>JointPSO:</b> quỹ đạo + alpha, BS cố định. <b>Full PSO:</b> thêm X/Y của ba BS, sau đó polishing alpha. <b>IPSO:</b> cùng biến với Full PSO, có trọng số quán tính giảm, mutation và elite, rồi polishing. Baseline bay thẳng với alpha theo kênh. Cùng 120 particles và 1.000 vòng nhưng số lần đánh giá khác nhau do mutation/polishing. [3]','small')

# Page 3
page('2. EE theo mức yêu cầu dữ liệu L và q')
add('L là tổng bit yêu cầu cho mỗi user trong nhiệm vụ; q là bit yêu cầu cho mỗi user tại từng slot phục vụ, không phải bit/s. Các sweep thay từng tham số, không phải toàn bộ tích L × q × hover. [2]')
h('2.1. Thay đổi L, giữ q = 5 kbit/user/slot và hover 1 s')
sweep_table('L')
caption('Bảng 2. EE trung bình (bit/J); số trong ngoặc là số nghiệm khả thi/3 seed. Dấu “—” nghĩa là không có seed khả thi. [2,4]')
add('JointPSO A giảm từ 3/3 xuống 1/3 rồi 0/3 nghiệm khả thi khi tăng L từ 1 lên 3 Mbit. Full PSO và IPSO đạt đủ ba seed ở cả ba mức L. IPSO A giảm EE từ 6.082,9 xuống 5.649,7 bit/J. IPSO B tăng từ 8.343,6 lên 9.390,4 bit/J trong các nghiệm tìm được. Tăng này phản ánh đường tìm kiếm hữu hạn; siết riêng L không thể làm tối ưu toàn cục tăng.','small')
h('2.2. Thay đổi q, giữ L = 3 Mbit/user và hover 1 s')
sweep_table('q')
caption('Bảng 3. Cùng cách tính như Bảng 2. q = 0 chỉ tắt ràng buộc user-slot; tổng dữ liệu L vẫn phải đạt. [2,4]')
add('Khi q tăng từ 5 lên 10 kbit, EE trung bình IPSO giảm <b>9,78% ở A</b> và <b>14,02% ở B</b>; IPSO vẫn đạt 3/3 seed. Full PSO A tại q = 10 có một nghiệm chưa đạt user-slot QoS: seed 2026, EE tính được 1.564,35 bit/J, thiếu dữ liệu ở 2/100 user-slot. Nghiệm này không được đưa vào trung bình EE khả thi.','small')
add('Trung bình của các phương pháp có thể dựa trên tập seed khác nhau. Vì vậy cần xem n/3 và số liệu từng seed ở Phụ lục trước khi dùng các trung bình này để xếp hạng.','small')

# Page 4
page('3. Hover, lợi ích của V10B và đánh đổi fairness')
h('3.1. Tăng hover làm tăng EE tìm được, đồng thời kéo dài nhiệm vụ')
fig('ee_hover')
caption('Hình 1. EE theo hover, giữ L = 3 Mbit/user và q = 5 kbit/user/slot. Đường nối trung bình trên seed khả thi, chấm nhỏ là từng seed; nhãn n/3 ghi số nghiệm đóng góp. [2,4]')
add('IPSO A đạt 5.649,7 → 7.787,0 → 9.196,5 bit/J khi hover tăng 1 → 2 → 3 s; B đạt 9.390,4 → 12.021,8 → 13.632,3 bit/J. Tổng thời gian hover tăng từ 20 lên 60 s. Với IPSO B, thời gian nhiệm vụ trung bình tăng từ 46,93 lên 85,58 s và năng lượng từ 6,38 lên 13,13 kJ. Vì lượng bit truyền tăng, chi phí bay được phân bổ cho nhiều bit hơn. [2,4]')
add('Mức cao nhất toàn campaign là <b>16.901,9 bit/J</b>, V10B Full PSO, seed 2026, hover 3 s. Đây là EE của toàn bộ dữ liệu truyền, kể cả phần vượt L; không đủ để kết luận hover 3 s là lựa chọn tốt nhất nếu chỉ cần phục vụ đúng L hoặc có deadline.','small')
h('3.2. So A/B trên cùng 21 cấu hình IPSO khả thi')
comparison=[]
for label,key,div,d in [('EE (bit/J)','ee',1,2),('Tổng dữ liệu (Mbit)','bits',1e6,2),('Năng lượng tổng (J)','energyJ',1,2),('Chiều dài quỹ đạo (m)','distance',1,2),('Jain fairness','jain',1,3)]:
    comparison.append([label]+[fmt(st.mean(r[key] for r in pick(v,'Full IPSO'))/div,d) for v in 'AB'])
table(['Chỉ số trung bình','V10A + IPSO','V10B + IPSO'],comparison,[237,128,WIDTH-365],pad=4)
caption('Bảng 4. Ghép đúng seed và bộ (L,q,h), loại cấu hình lặp; n = 21 cặp. Gain EE trung bình từng cặp là 55,79%; tỷ lệ của hai trung bình EE là 54,30%. [2,4]')
add('B tăng tổng bit và giảm quãng đường/năng lượng, đồng thời Jain thấp hơn. Jain gần 1 nghĩa là tổng bit giữa các user đều hơn. Mục tiêu tổng bit/J có thể tập trung phục vụ user có kênh thuận lợi, trong khi các user khác chỉ cần qua ngưỡng QoS. IPSO có lợi thế chung nhưng không thắng Full PSO ở mọi cấu hình.','small')

# Page 5
page('4. Quỹ đạo UAV tại L = 3 Mbit/user')
add('Các hình chọn IPSO để so A/B trong cùng phương pháp. Giữ q = 5 kbit/user/slot, hover 1 s; cả sáu nghiệm minh họa đều khả thi. Hình chiếu XY, UAV ở Z = 30 m. Dữ liệu quỹ đạo của mọi phương pháp được giữ trong tệp đính kèm của bộ phân tích.','small')
fig('trajectory_2026')
caption('Hình 2. Seed 2026. Điểm tròn: waypoint; sao đỏ: user U1–U5; tam giác: BS1–BS3; S/E: đầu/cuối. Ô xanh nhạt là miền BS, nền xanh lá là hành lang X của UAV. [2,4]')
fig('trajectory_608060')
caption('Hình 3. Seed 608060, cùng chú giải Hình 2. BS1/2/3 có Z lần lượt 20/30/25 m. Tọa độ được vẽ nguyên từ MAT, không dịch điểm hoặc làm trơn quỹ đạo. [2,4]')
add('A giữ Y đều nên các lần phục vụ trải theo chiều dài hành lang. B tự chọn Y, cho phép gom nhiều điểm gần vùng kênh thuận lợi và tạo một số đoạn bay dài. Hai hình cho thấy hình học thay đổi cùng vị trí BS; chưa có thí nghiệm tách riêng đóng góp của từng thành phần.','small')

# Page 6
page('4. Quỹ đạo UAV (tiếp) và kết quả từng scenario')
fig('trajectory_3486784401')
caption('Hình 4. Seed 3486784401, IPSO, L = 3 Mbit, q = 5 kbit, hover 1 s. BS2 của B ở (0; 101,26; 30) m, khác xu hướng X gần 50 m của nhiều nghiệm khác. [2,4]')
h('4.1. Đối chiếu số liệu của các quỹ đạo minh họa')
body=[]
for seed in SEEDS:
    for v in 'AB':
        r=pick(v,'Full IPSO',L=3e6,q=5000,h=1,seed=seed)[0]
        body.append(['V10'+v,str(seed),fmt(r['ee']),fmt(r['bits']/1e6,2),fmt(r['energyJ']/1000,2),fmt(r['distance']),fmt(r['jain'],3)])
table(['Bản','Seed','EE (bit/J)','Dữ liệu (Mbit)','E (kJ)','D (m)','Jain'],body,[35,72,86,92,61,64,WIDTH-410],small=True,pad=5,split=[3,5])
caption('Bảng 5. IPSO ở cấu hình chính. D là chiều dài bay, E là tổng năng lượng cruise + hover + RF. Các giá trị làm tròn từ dữ liệu gốc. [2,4]')
add('Ở cả ba seed, B đạt EE cao hơn A và đường bay ngắn hơn. Seed 2026 thể hiện rõ đánh đổi: EE B đạt 11.250,4 bit/J, nhưng Jain chỉ khoảng 0,456. Đây là tính chất của nghiệm tối đa tổng bit/J, không đồng nghĩa mọi user đều nhận mức cải thiện tương tự.')
add('V10B vẫn bị ràng buộc Y đơn điệu với tiến tối thiểu 1 m/đoạn. Một số waypoint rất gần nhau theo Y, trong khi vài đoạn dài chi phối hình học. Hiện chưa tính năng lượng đổi hướng, gia tốc hoặc dừng; vì thế không suy diễn các đường này thành quỹ đạo điều khiển thực tế đã kiểm chứng.','small')

# Page 7
page('5. Tọa độ BS tại L = 3 Mbit/user')
add('Bảng 6 liệt kê đầy đủ ba seed ở q = 5 kbit/user/slot, hover 1 s cho cả Full PSO/IPSO của A và B. Thứ tự BS1/2/3 giữ nguyên định danh. Độ cao BS cố định; chỉ X/Y được tối ưu. Cả 12 nghiệm đều khả thi.')
body=[]
for v in 'AB':
    for seed in SEEDS:
        for a,label in [('Full PSO','PSO'),('Full IPSO','IPSO')]:
            r=pick(v,a,L=3e6,q=5000,h=1,seed=seed)[0]
            xyz=[f"({fmt(r['xBS'][j],2)}; {fmt(r['yBS'][j],2)}; {fmt(r['zBS'][j],0)})" for j in range(3)]
            body.append(['V10'+v,str(seed),label]+xyz)
table(['Bản','Seed','P.pháp','BS1 (x; y; z)','BS2 (x; y; z)','BS3 (x; y; z)'],body,[32,67,41,118,118,WIDTH-376],small=True,pad=5,split=[7])
caption('Bảng 6. Tọa độ theo mét, làm tròn 0,01 m. PSO trong bảng là Full PSO. Mỗi bộ ba dùng dấu chấm phẩy để tách tọa độ; dấu phẩy biểu diễn phần thập phân. [2,4]')
h('5.1. Miền tìm kiếm quyết định cách hiểu “vị trí tối ưu”')
table(['BS','Vị trí ban đầu (m)','Miền X (m)','Miền Y (m)'],[
 ['BS1','(300; 300; 20)','250–300','250–300'],
 ['BS2','(0; 150; 30)','0–50','100–200'],
 ['BS3','(300; 0; 25)','250–300','0–50'],
],[45,218,115,WIDTH-378],pad=4)
caption('Bảng 7. Dịch chuyển tối đa ±50 m quanh vị trí ban đầu, cắt tại vùng 300 × 300 m. JointPSO/baseline giữ các vị trí ban đầu này. [3,4]')
add('Ở cấu hình chính, cả 12 nghiệm có BS3 = (250; 50; 25) m và x₁ = 250 m. Tuy vậy y₁, tọa độ BS2 còn thay đổi theo seed/phương pháp. Nghiệm chạm biên gợi ý khảo sát miền BS rộng hơn; dữ liệu hiện tại chỉ xác nhận vị trí tốt trong miền tìm kiếm đang dùng.','small')

# Page 8
page('6. Đánh giá khả năng cố định một phần tọa độ BS')
fig('bs_distribution_L3')
caption('Hình 5. Toàn bộ 60 nghiệm Full PSO/IPSO tại L = 3 sau loại trùng: 2 bản × 3 seed × 5 bộ (q,hover) × 2 phương pháp. Có 59 nghiệm khả thi. Các điểm trùng tọa độ chồng lên nhau, không thêm nhiễu. [2,4]')
table(['Ứng viên','Bộ q = 5, h = 1','Mọi bộ L = 3','Chỉ nghiệm khả thi'],[
 ['x₁ = 250 m','12/12','59/60','58/59'],
 ['x₂ = 50 m','10/12','51/60','50/59'],
 ['x₃ = 250 m','12/12','60/60','59/59'],
 ['BS3 = (250; 50; 25) m','12/12','50/60','49/59'],
],[168,111,102,WIDTH-381],pad=5)
caption('Bảng 8. Tần suất tại tọa độ ứng viên, sai lệch không quá 10⁻³ m. Các cấu hình dùng chung scenario nên không phải mẫu độc lập. [4]')
h('6.1. Khuyến nghị kiểm chứng theo thứ tự')
add('<b>Bước 1:</b> thử cố định x₃ = 250 m, sau đó thử thêm x₁ = 250 m. Đây là hai tọa độ có mức lặp lại cao nhất. Nên giữ y₁, tọa độ BS2 và y₃ là biến khi xét nhiều q/hover.')
add('<b>Bước 2:</b> nếu chỉ cần bộ chính q = 5, hover 1 s, có thể thử cố định toàn bộ BS3 = (250; 50; 25) m. Việc vị trí này xuất hiện 12/12 lần là bằng chứng để chọn ứng viên, chưa thay cho thí nghiệm giảm biến.')
add('<b>Bước 3:</b> chạy lại các phương án cố định với cùng seed/ngân sách và so EE ghép cặp, tỷ lệ khả thi, thời gian/số lần đánh giá. Song song, thử nới miền BS để kiểm tra xu hướng chạm biên. Chỉ quyết định cố định sau khi có mức mất EE chấp nhận được.')
add('<b>Trạng thái:</b> báo cáo này chỉ phân tích nghiệm đã lưu; chưa thay đổi cấu hình BS và chưa đo mất EE khi cố định.','small')

# Page 9
appendix_start=len(story)
page('Phụ lục. EE tính được theo từng seed')
add('Đơn vị bit/J. Dấu * đánh dấu nghiệm chưa thỏa mọi ràng buộc; chỉ dùng chẩn đoán và không đưa vào trung bình EE khả thi. Full PSO/IPSO là sau polishing. [2,4]','small')
for sweep,label in [('L','A. Thay L, giữ q = 5 kbit và hover 1 s'),('q','B. Thay q, giữ L = 3 Mbit và hover 1 s')]:
    h(label)
    body=[]
    for v in 'AB':
        for seed in SEEDS:
            for val in ([1e6,2e6,3e6] if sweep=='L' else [0,5000,10000]):
                rr=pick(v,L=val if sweep=='L' else 3e6,q=5000 if sweep=='L' else val,h=1,seed=seed)
                line=['V10'+v,str(seed),str(int(val/(1e6 if sweep=='L' else 1000)))]
                for a in ALGOS:
                    r=next(r for r in rr if r['algorithm']==a)
                    line.append(fmt(r['ee'])+('' if r['feasible'] else '*'))
                body.append(line)
    table(['Bản','Seed','L (Mbit)' if sweep=='L' else 'q (kbit)','JointPSO','Full PSO','IPSO'],body,[35,85,69,101,101,WIDTH-391],small=True,pad=2,split=[10])
caption('Bảng A1–A2. Mỗi giá trị là kết quả một scenario seed; ba seed không phải ba lần khởi tạo thuật toán trên cùng scenario.')
appendix=story[appendix_start:]
del story[appendix_start:]

# Page 10
page('7. Giới hạn, kiểm chứng và nguồn dữ liệu')
h('7.1. Các giới hạn ảnh hưởng kết luận')
for text in [
 '<b>Tính ngẫu nhiên và ngân sách.</b> Chỉ có ba scenario seed và một algorithm seed 151459287. Cùng 120 particles/1.000 vòng nhưng IPSO có mutation, còn Full có polishing. Chưa có so sánh cùng runtime hoặc cùng số lần đánh giá; không khẳng định ưu thế với mọi lần khởi tạo.',
 '<b>Hội tụ.</b> Trong phân tích lịch sử trước đó, nhiều lượt B/IPSO còn cải thiện ở cuối 1.000 vòng. Các số trong báo cáo là nghiệm tìm được dưới ngân sách hiện tại, không phải giá trị tối ưu đã chứng minh.',
 '<b>Năng lượng và relay.</b> RF chiếm tối đa khoảng 2,43 × 10⁻⁸ tổng năng lượng trong campaign; cruise/hover chi phối mẫu số. EH cấp RF lý tưởng, UL được giả định đủ dữ liệu cho DL. Chưa tính đầy đủ PA, mạch, gia tốc, rẽ hoặc cân bằng lưu lượng relay hai chặng.',
 '<b>Giới hạn bay và mục tiêu.</b> Y đơn điệu; không có giới hạn chiều dài D_max như trong bài Drones. Mục tiêu tính toàn bộ bit nên có thể truyền vượt xa L. EE cần được xem cùng thời gian nhiệm vụ, fairness và dữ liệu hữu ích nếu chỉ cần đủ L.'
]:add(text,'small')
h('7.2. Cách kiểm chứng và tái sử dụng')
add('Các kết quả đã được đối chiếu lại với 54 MAT: EE, tổng bit/năng lượng, cấu hình L/q/hover, trạng thái khả thi và hình học. Kiểm tra D là tổng khoảng cách waypoint, E = E_bay + E_hover + E_RF và EE = Dữ liệu/E. Kiểm tra riêng biên quỹ đạo và đầu/cuối cho 168 kết quả khác nhau. Không chạy lại optimizer.','small')
add('Các bảng làm tròn số để đọc. Dữ liệu đầy đủ và độ chính xác gốc nằm tại <b>output/v10_ab_results_report_20261105/data/</b>: ee_summary.csv, bs_default_L3_q5_h1.csv, bs_all_L3.csv, waypoints_all_L3.csv, extracted_results.json, audit.csv và source_checksums.json. Tọa độ BS/UAV, cấu hình và cờ khả thi giữ nguyên theo dữ liệu đã lưu.','small')
h('7.3. Nguồn')
add('[1] T. Zhang, M. Gu, D. Mishra, J. Yuan, A. Seneviratne. <i>Trajectory and Power Control for Sustainable UAV-Assisted NOMA-Enabled Backscattering IoT.</i> Drones 2026, 10, 238. <link href="https://doi.org/10.3390/drones10040238" color="#087B79">doi:10.3390/drones10040238</link>. Dùng Eq. (10)–(12), Table 2, tr. 8–9; cấu hình mô phỏng tr. 17. Bản gốc: docs/drones-10-00238.pdf.','small')
add('[2] Campaign campaign_20261029_125559: campaign_summary.csv và 54 results.mat được manifest tham chiếu; 216 kết quả bốn phương pháp. Chỉ dùng run thuộc campaign này.','small')
add('[3] Mã V10: v10Config, buildV10Simulation, dronePropulsionPower, evaluateTrajectoryV10, addV10EnergyMetrics, ba optimizer V10, polishAlphaV10 và runV10. Đối chiếu thêm V10_AB_GUIDE và DRONES_ENERGY_CODE_REVIEW_2026-10-28.','small')
add('[4] Tệp phân tích đã kiểm chứng: output/v10_campaign_analysis_20261029 và dữ liệu trích xuất/audit dùng để dựng báo cáo; SHA-256 từng MAT được lưu trong source_checksums.json.','small')
story.extend(appendix)

def footer(canvas,doc):
    canvas.saveState()
    canvas.setFillColor(NAVY);canvas.setFont('Body-Bold',8)
    canvas.drawString(51,A4[1]-29,'V10A / V10B')
    canvas.setFont('Body',8);canvas.setFillColor(MUTED)
    canvas.drawRightString(A4[0]-51,A4[1]-29,'Báo cáo kết quả mô phỏng · 05/11/2026')
    canvas.setStrokeColor(colors.HexColor('#D5DFE5'));canvas.setLineWidth(.5)
    canvas.line(51,37,A4[0]-51,37)
    canvas.drawString(51,24,'Dữ liệu đã lưu, không chạy lại tối ưu')
    canvas.drawRightString(A4[0]-51,24,f'Trang {doc.page}')
    canvas.restoreState()

doc=SimpleDocTemplate(str(OUT),pagesize=A4,rightMargin=51,leftMargin=51,
                      topMargin=52,bottomMargin=51,title='Báo cáo kết quả V10A và V10B',
                      author='Tổng hợp từ dữ liệu mô phỏng của dự án',
                      subject='EE theo L/q, quỹ đạo UAV và tọa độ BS')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(OUT.resolve())
