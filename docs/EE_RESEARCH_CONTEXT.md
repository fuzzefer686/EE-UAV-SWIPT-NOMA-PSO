# Context nghiên cứu Energy Efficiency của UAV

Cập nhật: 14/10/2026. Tài liệu ghi nhớ cho các buổi nghiên cứu tiếp theo.
Phần đọc paper/đối chiếu V8 dưới đây ghi nhận baseline ngày 13/10;
mục 10 ghi các thay đổi được người dùng yêu cầu sau đó và được ưu tiên.

## 1. Mục tiêu và quyết định của người dùng

- Bài gốc là `docs/root_paper.pdf`. Đã đọc bài gốc và toàn bộ 5 bài
  `docs/1.pdf` đến `docs/5.pdf`, đối chiếu các công thức chính với mã MATLAB.
- Mục tiêu hiện hành: phát triển tối ưu Energy Efficiency (EE), đơn vị bit/J,
  trên nền UAV-SWIPT-NOMA và pipeline V8.
- Người dùng đã chọn **EE của UAV, bao gồm năng lượng bay và truyền thông**.
- **Chưa chọn loại UAV.** Người dùng muốn tìm hiểu các loại năng lượng tiêu
  thụ trước, rồi mới quyết định rotary-wing hay fixed-wing. Không coi lựa chọn
  rotary-wing là đã được chấp thuận và không hỏi lại ngay về loại UAV.
- EE toàn mạng có thể là chỉ số bổ sung; chưa được chọn làm mục tiêu chính.
- Loại mẫu số (tổng năng lượng UAV tiêu thụ hay năng lượng rút từ pin), cách
  tính rate relay, thời gian bay, tham số phần cứng và QoS vẫn chưa chốt.
- Phạm vi theo `RESEARCH_DIRECTION_EE.md`: V8 trở xuống. V9/V10 lịch sử, DTS/tau
  tối ưu, ICIT, cache, finite-data và ràng buộc nhiệm vụ từ các hướng đó không
  thuộc hướng hiện hành. Không đưa vào chỉ vì một bài tham khảo có sử dụng.
- Lượt đọc ngày 13/10 chỉ tạo ghi chú. Ngày 14/10 người dùng yêu cầu thử
  công thức EE RF với slot 1 s và thay đổi code tối thiểu; xem mục 10.

## 2. Năng lượng tiêu thụ của UAV: phân loại trước khi chọn công thức

### 2.1. Năng lượng bay / propulsion

Đây là năng lượng động cơ cần để duy trì trạng thái bay và tạo chuyển động.
Nó có thể phụ thuộc vào tốc độ, gia tốc, lên/xuống độ cao, tải trọng, lực cản
và điều kiện không khí. Bay treo vẫn tiêu thụ năng lượng với UAV cánh quay.
Các bài 1, 2 và 3 nhấn mạnh rằng trong các mô hình của họ, năng lượng bay
thường chiếm ưu thế so với năng lượng truyền thông.

Không thể áp dụng chung một công thức cho mọi loại UAV:

- Fixed-wing trong bài 1 dùng dạng `P_fly(v) = c1*v^3 + c2/v`, cho bay ngang
  và bỏ qua một số hiệu ứng động lực học. Công thức này đòi hỏi `v > 0`;
  không đại diện cho bay treo của UAV cánh quay.
- Rotary-wing trong bài 2 có công suất profile, induced và parasite; tại
  tốc độ bằng 0 công suất hữu hạn. Công thức cơ bản được suy ra cho bay ngang
  ở độ cao cố định và bỏ qua năng lượng bổ sung do gia tốc.
- V8 thay đổi cả x và z. Không thay tốc độ ngang bằng tốc độ 3D trong công
  thức bài 2 rồi gọi đó là mô hình bay 3D đã được xác nhận. Nếu giữ biến z,
  phải tìm mô hình lên/xuống phù hợp hoặc công bố rõ phép xấp xỉ và kiểm tra
  độ nhạy. Quyết định này để sau khi hiểu cơ chế năng lượng.

### 2.2. Năng lượng phát tín hiệu

`P_tx` trong công thức SINR là công suất RF phát ra anten, đơn vị W.
Nguồn điện cấp cho bộ khuếch đại thường phải lớn hơn công suất RF đầu ra:

```text
E_PA = integral(P_tx(t) / eta_PA) dt
```

`eta_PA` là hiệu suất khuếch đại công suất, khác hiệu suất thu năng lượng
`eta_EH`. Nếu dùng công thức này, `P_tx/eta_PA` đã bao gồm cả năng lượng RF
đầu ra và tổn hao khuếch đại; không cộng thêm `P_tx` lần thứ hai.

V8 chỉ có công suất RF `pt`; chưa có `eta_PA`. Đẳng thức sử dụng toàn bộ EH
để tạo RF phát hiện tại là giả định lý tưởng, không đồng nghĩa EH cấp đủ
điện cho cả bộ khuếch đại và các mạch thực tế.

### 2.3. Năng lượng thu và xử lý truyền thông

Gồm mạch thu/phát, bộ đổi tần, DAC/ADC, lọc, xử lý băng gốc, giải mã/ mã hóa
và SIC ở UAV nếu UAV giải mã uplink NOMA. Có thể khởi đầu bằng công suất
mạch gộp theo chế độ Rx/Tx, nhưng cần định nghĩa rõ phần nào đã nằm trong đó.

SIC downlink của GU xảy ra ở thiết bị GU, nên năng lượng SIC đó không tự động
thuộc mẫu số EE của UAV. Không chuyển toàn bộ năng lượng xử lý của người
dùng vào UAV chỉ vì cùng dùng NOMA.

### 2.4. Điện tử điều khiển và phụ tải

Flight controller, định vị, cảm biến, máy tính điều khiển và các phụ tải
khác có thể được biểu diễn bằng `P_aux`. Chúng tiêu thụ điện ngay cả khi UAV
không phát RF. Nếu dữ liệu phần cứng đã gộp chúng vào công suất bay hoặc
công suất mạch thì không cộng lại. Payload và điện tử bổ sung phải được nêu
rõ nếu được đưa vào phạm vi nghiên cứu.

### 2.5. SWIPT: nguồn cấp năng lượng, không phải khoản tiêu thụ

`E_H` là năng lượng điện thu được từ RF đầu vào. EH có thể giảm điện cần
lấy từ pin, nhưng không xóa tải năng lượng của động cơ hay mạch điện.

Phải phân biệt ba lượng:

```text
E_UAV_load = E_fly + E_PA + E_Rx/Tx_circuit + E_aux
E_H_used   = phần EH thực sự dùng được cho tải đã cho phép
E_battery  = điện lấy từ pin để đáp ứng phần tải còn lại
```

`E_battery = E_UAV_load - E_H_used` chỉ đúng cho khoảng đánh giá có cân bằng
năng lượng, không thay đổi mức tích trữ cuối kỳ và đã tính các tổn hao cần
thiết. Tổng EH vượt tổng tải không tự chứng minh khả thi: năng lượng phải
có trước khi sử dụng, và đường cấp năng lượng phải hỗ trợ loại tải đó.

Trong bài gốc, EH cấp cho downlink; pin cho hoạt động UAV được giả định đủ.
Không tự diễn giải rằng EH đang cấp động cơ bay. Nếu hạch toán pin trong
mô hình này, chỉ trừ EH dùng cho phần tải truyền thông được cấp bằng EH.

Hai chỉ số đều có thể hữu ích, nhưng không được dùng lẫn tên:

```text
EE_UAV_gross   = số bit phục vụ / E_UAV_load
EE_UAV_battery = số bit phục vụ / E_battery
```

Người dùng đã chọn phạm vi UAV, nhưng chưa chọn giữa hai cách hạch toán này.
EE theo pin cần thêm kiểm tra mẫu số và cân bằng năng lượng; không thay mẫu
số không hợp lệ bằng eps rồi coi giá trị rất lớn là cải thiện EE.

Nếu báo thêm EE theo năng lượng cấp từ bên ngoài của toàn mạng, cần cộng
nguồn điện BS và điện rút từ pin UAV theo một ranh giới hệ thống nhất quán.
RF thu tại UAV là luồng năng lượng nội bộ; tránh tính nó như một nguồn mới
hoặc tính trùng phần năng lượng chuyển từ BS sang UAV.

## 3. Bài gốc: điều gì được tối ưu và điều gì chưa được mô hình hóa

**Flight to Efficiency: Trajectory Optimization in SWIPT-Enabled UAV-Assisted
NOMA for Future Wireless Networks** — Baduge, Perera, Jayakody, VTC2024-Fall,
2024, 7 trang. DOI: `10.1109/VTC2024-Fall63153.2024.10758018`.

- Một UAV relay, 3 BS, 3 GU. BS→UAV được bài gọi là uplink; UAV→GU là
  downlink. Đó là quy ước của bài, dù BS đóng vai trò nguồn dữ liệu.
- Suy hao `beta0*d^(-zeta)` và fading Rician phụ thuộc góc nâng.
- NOMA và SIC; phân bổ hệ số công suất theo channel gain hoặc fractional.
- Mục II.C, trang 3: `E_H = eta*phi*P_received*T_UL`,
  `P_received = sum_m(P_BS*abs(h_BS,m)^2)`.
- Bài giả định thời gian UL = DL, nên `P_tx = E_H/T_DL = eta*phi*P_received`.
- Mục II.G, trang 4, (6a)/(7a): tối đa min-rate downlink bằng vị trí UAV.
  EH ảnh hưởng rate thông qua công suất phát; không có mẫu số năng lượng
  hoặc mục tiêu bit/J riêng trong bài toán tối ưu này.
- Trang 5 giả định UAV có đủ pin cho quỹ đạo và hoạt động; không có công
  thức năng lượng bay, PA, mạch hay ledger pin đầy đủ.
- Trang 3–4 viết rate bằng `log2(1+SINR)` nhưng gọi đơn vị bps. Để có bps
  phải dùng bandwidth; code dùng `B = 1 MHz`. Với hai pha nối tiếp, còn phải
  phân biệt rate trong pha và số bit / thời gian toàn chu kỳ.
- Table I: vùng 2000×2000 m, beta0 −50 dB, eta = phi = 0.7, độ cao đầu/cuối
  200 m, độ cao 100–300 m. V8 là scenario khác, không phải tái hiện nguyên
  Table I của bài gốc.
- Bản `docs/root_paper.pdf` trùng SHA-256 với
  `reference/flight_to_efficiency.pdf`.

Ghi chú đối chiếu: Algorithm 2 in ở trang 4 có bước thứ hai
`coef_j = 1 - coef_j/sum(coef)`, trong khi mô tả yêu cầu tổng hệ số bằng 1
và code `findPowCoeff` dùng `coef_j/sum(coef)`. Không chép máy móc công thức
in này; khi trích trong mô hình mới cần ghi rõ công thức đã chuẩn hóa.

Mã tham khảo Raw0 cũng khác bài và V8: hàm SWIPT Raw0 dùng `sum(abs(h_BS))`
cho EH, còn V8 dùng `sum(abs(h_BS).^2)` phù hợp cách tính power gain. Một số
thiết lập hình học và fading Raw0 cũng khác. Giữ mã tham khảo nguyên trạng
để truy vết, không dùng các bất nhất đó làm tiêu chuẩn vật lý cho EE mới.

## 4. Năm bài tham khảo và vai trò của từng bài

### [1] NOMA, phân bổ công suất và EE với UAV cánh cố định

`1.pdf`: **Energy-efficient UAV communication: A NOMA scheme with resource
allocation and trajectory optimization** — Huilong Jin, Yucong Zhou,
Xiaozi Jin, Shuang Zhang, PLOS ONE 19(4), 2024, 23 trang.
DOI: `10.1371/journal.pone.0301819`.

- Một UAV làm ABS, downlink NOMA, độ cao cố định trong mô hình cơ bản.
- Trang 7–8, (8)–(11): số bit tích phân theo thời gian chia năng lượng bay;
  dùng fixed-wing `c1*v^3+c2/v`, bỏ qua năng lượng truyền thông trong mẫu số.
- Ba cách clustering: greedy, suboptimal, hybrid. Đây không phải ba thuật
  toán Joint/Full PSO/Full IPSO trong repo.
- Trang 12–15: Dinkelbach, SCA theo công suất và CVX; tọa độ UAV còn được
  xử lý qua tìm kiếm. Dùng làm tham khảo về mục tiêu phân thức và chia khối.
- Không có SWIPT hay relay BS→UAV→GU như bài gốc. Không lấy công thức bay
  của nó cho UAV cánh quay, hoặc kế thừa việc bỏ năng lượng truyền thông
  khi mục tiêu đã chọn bao gồm cả truyền thông.
- Các nhận xét số về độ cao và cải thiện so với OMA phụ thuộc scenario;
  không coi đó là quy luật hay mức cải thiện dự kiến cho V8.

### [2] Nguồn nền tảng để hiểu năng lượng bay của UAV cánh quay

`2.pdf`: **Energy Minimization for Wireless Communication with Rotary-Wing
UAV** — Yong Zeng, Jie Xu, Rui Zhang. File là preprint
`arXiv:1804.02238v1`, 06/04/2018, 31 trang; bản journal được bài [5] dẫn là
IEEE TWC 18(4), 2019, 2329–2345, DOI `10.1109/TWC.2019.2902559`.
Số trang/công thức dưới đây theo file preprint trong repo.

- Một UAV, nhiều ground node, TDMA, không NOMA/SWIPT.
- Trang 6, (6):

```text
P_fly(v) = P0*(1 + 3*v^2/Utip^2)
         + Pi*(sqrt(1 + v^4/(4*v0^4)) - v^2/(2*v0^2))^(1/2)
         + 0.5*d0*rho*s*A*v^3
```

- Ba thành phần: profile của cánh, induced tạo lực nâng và parasite do lực
  cản. Trang 7: `P_hover = P0 + Pi`; công suất bay không đơn điệu theo tốc độ.
- Phân biệt tốc độ tiết kiệm công suất `argmin P(v)` và tiết kiệm năng lượng
  mỗi mét `argmin P(v)/v`, trang 7–8. Không đồng nhất tối thiểu thời gian bay
  với tối thiểu năng lượng hoặc tối đa EE.
- (9)/(10), trang 8: tích phân năng lượng bay + mạch truyền thông.
- Mục tiêu là **min năng lượng với yêu cầu dữ liệu đã cho**, không max bit/J
  trực tiếp. Chỉ tương đương tối đa EE khi số bit phục vụ được giữ cố định.
- Fly-hover-communicate, TSP, path discretization và SCA. Có thể học cách
  ánh xạ đoạn bay với thời gian; không tự thêm nhiệm vụ hữu hạn dữ liệu vào
  hướng V8 đang nghiên cứu.
- Appendix A, trang 26–29 cung cấp ý nghĩa và giá trị tham số, cùng giới
  hạn bay ngang / xấp xỉ lực nâng. Tham số phải khớp loại UAV và phần cứng.

### [3] Rate relay và EE của UAV có QoS

`3.pdf`: **NOMA-based energy efficiency optimization for UAV-assisted relay
communication networks** — Min Li et al., Computer Networks 275 (2026)
111946, 11 trang. DOI: `10.1016/j.comnet.2025.111946`.

- Một BS, một UAV cánh quay relay DF real-time, nhiều GU. BS→UAV dùng FDMA;
  downlink NOMA phục vụ hai user/slot. Không có EH.
- Trang 4, (9)/(10): rate end-to-end lấy min của hai chặng theo user.
- (16)–(20): tổng rate / tổng công suất UAV trên các slot đều thời gian;
  đây tương đương tổng bit / tổng năng lượng vì thời lượng slot triệt tiêu.
- Mẫu số chú trọng UAV, gồm propulsion và công suất truyền thông; không
  đưa năng lượng BS vào vì trọng tâm là pin/lifetime của UAV.
- Trang 5, mục 5.2 nói rõ không tính công suất RF phát trong mẫu số của
  bước phân bổ công suất, và dùng toàn bộ Pmax. Đây là giả định đặc thù;
  không suy ra tối ưu power allocation nói chung chỉ cần max-rate.
- BCD: scheduling, power và trajectory; integer programming + SCA + CVX,
  Dinkelbach cho khối trajectory. Tham khảo cho benchmark về sau, không
  buộc thay PSO hiện tại ngay.
- Khác V8: một BS, hai user/slot, độ cao cố định, quỹ đạo vòng khép kín và
  QoS theo tổng dịch vụ. Không sao chép mô hình này thay toàn bộ bài gốc.

### [4] NOMA–SWIPT, power splitting và dạng mục tiêu EE

`4.pdf`: **Energy-Efficient THz NOMA for SWIPT-aided Miniature UAV Networks**
— Jalal Jalali et al., 5 trang. Đã xác minh ngày 14/10/2026:
IEEE Communications Letters, 2024, DOI `10.1109/LCOMM.2024.3372471`.
Nguồn metadata: https://imec-publications.be/entities/publication/27bdd17f-76f6-41d4-826a-522e2aaf87c8.

- Nguồn, miniature UAV relay và destination, có cả direct link và MRC;
  kênh THz có hấp thụ phân tử, UAV ở độ cao cố định.
- Trang 2: tách RF cho EH và ID, nên tỷ lệ PS tác động cả công suất thu
  năng lượng lẫn khả năng giải mã thông tin.
- Trang 3, (18): tối ưu **tổng các tỷ số EE theo slot**. Không tương đương
  tỷ số tổng bit / tổng J của toàn chuyến bay; không dùng Dinkelbach một
  tỷ số trực tiếp cho mục tiêu sum-of-ratios.
- Hai giai đoạn: PS/trajectory với SCA và biến đổi phân thức; NOMA power
  với quadratic transform và ALM.
- Dùng công suất bay hằng Pc và mẫu số `alpha1+alpha2-Pt+Pc`. Đây là cách
  hạch toán riêng cần kiểm tra ranh giới, nguồn cấp và đơn vị trước khi dùng.
- Công thức EH (11) trong bản in không thể hiện rõ nhân công suất nguồn
  `alpha1+alpha2` dù các alpha là power trong (5). Không nhập công thức
  này vào evaluator mới khi chưa kiểm tra normalization/giả định của tác giả.
- Giá trị chính cho chúng ta: hiểu coupling EH–ID, ràng buộc giải mã và sự
  khác biệt giữa các loại mục tiêu EE. Không tự thêm THz/direct link/MRC
  hay tối ưu tỷ lệ pha truyền vào V8.

### [5] Thu năng lượng phi tuyến và chi phí nguồn BS

`5.pdf`: **Energy efficiency maximization in UAV communication networks with
nonlinear energy harvesting** — Zhongyu Wang et al., Computer Networks 241
(2024) 110222, 9 trang. DOI: `10.1016/j.comnet.2024.110222`.

- BS MIMO/URA cấp WPT cho nhiều UAV hover; UAV gửi dữ liệu về BS bằng
  uplink NOMA. Topology khác bài gốc: không một UAV relay phục vụ nhiều GU.
- Trang 3, (4)–(6): EH dạng logistic có bão hòa, tham số phụ thuộc mạch.
- Trang 4, (11)/(12): throughput / năng lượng gồm công suất anten BS,
  tải UAV và năng lượng BS dùng cho WPT. Mẫu số không chỉ gồm RF của UAV.
- Dinkelbach và Lagrange dual decomposition để điều chỉnh power/time.
  Dù abstract nói sum-of-ratios, (12)/(13) định nghĩa tỷ số tổng; cần đọc
  công thức thực tế thay vì phân loại bài toán chỉ từ abstract.
- Bản in dùng ký hiệu năng lượng/công suất chưa đồng nhất: (2) có nhân thời
  gian nhưng gọi là received power; (4)/(6) có điểm cần kiểm tra hệ số bão
  hòa. Muốn dùng phải xác định RF input bằng W, DC output bằng W, rồi tích
  phân thời gian thành J và đối chiếu mô hình logistic gốc được dẫn.
- Không lấy tham số phần cứng hoặc mức gain EE của bài này áp thẳng cho V8.
  Phi tuyến EH là hướng kiểm tra độ nhạy sau khi mô hình EE tuyến tính và
  mức RF đầu vào đã rõ; hiện chưa chốt triển khai.

## 5. Bản đồ mã V8 đã xác nhận

Entry point: `scripts/maincodev8nUser.m`; `setup_project.m` chỉ thêm scripts
và src vào MATLAB path, không đưa mã tham khảo có tên hàm trùng vào path.
Nhánh tại thời điểm đọc: `feature/ee-optimization`.

| Luồng | Biến quyết định | Kích thước mặc định | Cấu hình ở entry point |
|---|---|---:|---|
| Đường thẳng | Không tối ưu; alpha channel-based | 38 biến vị trí đưa vào evaluator | Đối chứng |
| Joint PSO | x,z nội bộ + alpha từng waypoint | 38 + 105 = 143 | 120 particles × 1000 vòng |
| Full PSO | Joint + tọa độ x,y của 3 BS | 143 + 6 = 149 | 400 × 1000 + alpha polishing |
| Full IPSO | Cùng biến với Full PSO | 149 | 400 × 1000 + mutation + polishing |

- Vùng 300×300 m, 5 GU, 3 BS; `y = 300:-15:0`: 21 waypoint,
  19 waypoint nội bộ và 20 đoạn bay. Endpoint `(150,300,30)`→`(150,0,30)`.
- x∈[75,225] m, z∈[15,45] m, |dx|≤75 m, |dz|≤30 m mỗi bước.
- BS x,y được chọn một lần cho cả trajectory trong vùng ±50 m đã clip vào
  biên; zBS cố định. Đây là tối ưu vị trí triển khai, không phải BS di chuyển
  theo mỗi slot. Việc BS có thể triển khai lại là giả định cần ghi rõ.
- `beta0=-30 dB`, path exponent 2.5, Rician K 4–12 dB; gLoS=1 và một mẫu
  NLoS cố định cho mỗi link trong scenario. Không lấy lại fading ngẫu nhiên
  ở mỗi lần đánh giá particle, nên fitness có tính xác định khi sim cố định.
- `B=1 MHz`; noise PSD −174 dBm/Hz; mỗi BS 46 dBm ≈39.81 W;
  phi=eta_EH=0.9; `Tslot=1e-6 s` dùng cho bookkeeping EH hiện tại.
- `findAchievableRate_SWIPT_Joint`: normalize alpha, sort user theo |h|²
  tăng dần, user yếu chịu nhiễu từ user mạnh; user mạnh nhất không có nhiễu
  còn lại dưới giả định SIC lý tưởng. Evaluator còn repair alpha để user
  yếu nhận hệ số lớn hơn. Alpha là tỷ lệ, không phải công suất W độc lập.
- Tổng RF UAV `pt = eta_EH*phi*sum_m(P_BS*|h_BS,m|²)` được quyết định bởi
  kênh EH; alpha chỉ chia tổng này. V8 chưa tối ưu tổng RF độc lập.
- Joint/Full fitness hiện tại:

```text
m_t = min_u R[t,u]
F = min_t(m_t) + 0.05*mean_t(m_t)
    - 0.10*mean_t(m_t)*mean_t(1-Jain_t)
    - lambdaSmooth*roughNorm - penalty
```

- Mặc định fitness xét waypoint 2–20; min-rate toàn quỹ đạo trong output
  còn gồm endpoints. `lambdaSmooth=0`, `bigPenalty=1e12`.
- Straight evaluator không có fairness penalty; Joint luôn xét nội bộ;
  Full hỗ trợ `fitnessStepMode='all'`. Không đổi một flag rồi mặc định cả
  ba evaluator đã dùng chung miền đánh giá.
- IPSO: inertia giảm theo căn bậc hai từ w_max tới w_min, mutation tăng khi
  stagnation, bảo vệ elite và chỉ nhận trial tốt hơn pbest.
- Alpha polishing của Full: tối đa min-rate từng waypoint, tie-break giảm
  rate imbalance; không bắt buộc tăng fitness toàn cục. Nếu đổi mục tiêu
  sang sum-throughput EE, bước này phải dùng mục tiêu mới, kiểm tra QoS và
  chấp nhận theo EE; không tự giữ tiêu chuẩn min-rate hiện tại.
- Seed scenario mặc định 2026; Full PSO/IPSO reset seedAlgo=151459287 và
  seedPolish=152459287. Joint dùng stream đang tiếp tục sau tạo scenario.
- Cùng số vòng chưa phải cùng số đánh giá: Joint ít particles hơn và không
  polishing; IPSO có đánh giá mutation thêm. Polishing mặc định 1250 mẫu
  cho mỗi trong 19 waypoint và đánh giá lại toàn trajectory cho từng mẫu.

## 6. Khoảng trống phải xử lý trước khi gọi kết quả là EE

1. **Thời gian bay:** V8 có waypoint không gian nhưng không có thời lượng
   đoạn bay hay vận tốc vật lý. Nếu coi 15 m ứng với 1 µs thì riêng vận tốc
   theo y đã là 15 triệu m/s; đó không phải mô hình thời gian UAV phù hợp.
   Cần tách thời gian RF và thời gian di chuyển, mô tả các chu kỳ RF trong
   mỗi khoảng bay. 21 waypoint không mặc định là 21 khoảng thời gian.
2. **Rate hai pha:** rate B*log2 hiện là rate trong pha DL, không phải bit
   được phục vụ trong toàn thời gian UL+DL. Giữ tỷ lệ UL=DL của bài gốc là
   giả định cố định; làm rõ nó không đồng nghĩa thêm biến tau tối ưu.
3. **Relay:** evaluator active chỉ dùng BS→UAV cho EH, không tính rate
   giải mã UL, không hạn chế forwarding theo dữ liệu nhận được. Muốn báo
   EE end-to-end cần kiểm tra bottleneck hai chặng và ánh xạ 3 BS→5 GU.
   Không đặt min(UL,DL) từng user khi chưa có ánh xạ luồng dữ liệu.
4. **Energy ledger:** chưa có propulsion, PA efficiency, Rx/Tx circuits,
   phụ tải, giới hạn battery/energy causality hoặc mô hình điện cấp từ EH.
5. **Nguồn tham số chung:** các hàm rate hardcode B, noise, Pr, phi, eta
   thay vì đọc sim. Thay sim.Pr/phi/eta có thể đổi EH báo cáo nhưng không
   đổi rate tương ứng. Evaluator mới cần một nguồn tham số duy nhất.
6. **QoS/feasible:** `isFeasible = penalty==0` hiện phản ánh biên/chuyển
   động, không xác nhận rate tối thiểu, giải mã UL, SIC margin hay năng
   lượng. Cần định nghĩa feasible cho bài toán mới; alpha ordering không
   thay cho toàn bộ kiểm tra SIC khi mô hình nhiễu thay đổi.
7. **Số liệu cũ:** logs V8 và `V8_BASELINE_SEED2026.md` là kết quả rate đã
   lưu, không có EE. Một seed không đủ kết luận IPSO tốt hơn PSO; nội dung
   nhắc V9 trong note lịch sử không đổi phạm vi V8 hiện hành.

## 7. Khung toán để thảo luận tiếp (đề xuất, chưa triển khai)

Trên cùng các khoảng thời gian thật:

```text
D_served = sum_n sum_u R_served[n,u] * duration_served[n,u]
E_load   = sum_n E_fly[n] + E_PA[n] + E_circuit[n] + E_aux[n]
EE       = D_served / E_denominator
```

`E_denominator` là `E_load` hoặc điện từ pin sau EH, cần người dùng cùng
chốt. `R_served` là rate DL dưới giả định nguồn dữ liệu đầy đủ hoặc rate
end-to-end của một mô hình relay đã xác định, phải ghi nhãn rõ.

Nếu relay hai pha DF không có lưu dữ liệu qua các khoảng, dữ liệu của một
luồng không vượt `min(R_UL*duration_UL, R_DL*duration_DL)` và năng lượng bay
vẫn tích lũy trong cả hai pha. Đây là ví dụ minh họa cho cùng một luồng,
không phải ánh xạ BS-user đã được chốt cho repo.

EE toàn hành trình là tỷ số tổng:

```text
EE_mission = sum_n D[n] / sum_n E[n]
           = sum_n (E[n]/sum_j E[j]) * (D[n]/E[n])
```

Vì vậy nó là trung bình EE từng khoảng có trọng số năng lượng, không phải
trung bình số học `mean(D[n]/E[n])`. Không chia fitness V8 hay rate đơn lẻ
cho tổng EH rồi gọi đó là EE của UAV.

Đề xuất giữ tinh thần fairness bài gốc bằng QoS/rate tối thiểu có định nghĩa
rõ và báo Jain riêng. Max sum-bit/J có thể ưu tiên user kênh mạnh; max-min
rate/J hoặc weighted-bit/J là bài toán khác và phải ghi tên khác.

PSO có thể tối ưu trực tiếp phân thức sau khi evaluator và miền khả thi
được chốt; Dinkelbach là lựa chọn bổ sung, không bắt buộc. Với subproblem
nonconvex giải bằng PSO hoặc SCA, không thừa hưởng bảo đảm tối ưu toàn cục
của một bài toán phân thức được giải chính xác.

## 8. Trình tự làm việc đã phù hợp với yêu cầu mới nhất

1. Giải thích và xác định các tải năng lượng UAV; phân biệt gross load và
   điện từ pin sau EH. Đó là chủ đề tiếp theo, trước lựa chọn loại UAV.
2. Sau đó chọn mô hình máy bay, thời gian bay và cách xử lý đổi độ cao.
3. Chốt served bits, relay/pha truyền, QoS và các tham số năng lượng.
4. Tạo evaluator EE riêng, giữ baseline rate V8 để đối chứng. Mọi thuật
   toán, đường thẳng và bước polishing phải gọi cùng mô hình EE.
5. Kiểm chứng: đơn vị, trường hợp 1 user/alpha đều, BS cố định, bảo toàn
   năng lượng, EH cấp đúng tải, PA losses, waypoint/segment endpoints.
6. So sánh nhiều seed với cùng scenario, ngân sách đánh giá (kể cả mutation
   và polishing), QoS và thời gian nhiệm vụ. Báo EE, dữ liệu phục vụ, năng
   lượng từng loại, EH, điện từ pin, min-rate, Jain và feasibility.
7. Sau khi baseline EE đáng tin cậy mới nghiên cứu cải tiến optimizer,
   Dinkelbach/BCD hoặc nonlinear EH. Sáu bài này chưa đủ để khẳng định một
   ý tưởng mới hoàn toàn hoặc một thuật toán luôn tốt hơn.

## 9. Quy tắc cập nhật ghi nhớ

- Đọc tài liệu này cùng `RESEARCH_DIRECTION_EE.md` trước các buổi nghiên cứu.
- Ghi rõ điều nào người dùng đã chọn, đề xuất nào chưa chốt và kết quả nào
  đã mô phỏng; không biến một đề xuất thành quyết định sau khi rút gọn context.
- Cập nhật khi mô hình năng lượng hoặc tiêu chuẩn EE được chốt. Không ghi
  gain EE vào lịch sử nếu chưa có evaluator, mẫu số và kiểm chứng rõ ràng.
- Các file nguồn nằm trong docs; số trang ở trên theo chính PDF đã đọc.

## 10. Quyết định triển khai tạm thời ngày 14/10/2026

- Người dùng yêu cầu **tối thiểu thay đổi code để dễ theo dõi**. Không
  refactor toàn bộ hệ thống hoặc đưa vào thuật toán/mô hình năng lượng mới.
- Thử EE theo năng lượng RF UAV phát: mỗi đoạn giữa hai điểm y cách nhau
  1 s, cố định UL=0.5 s và DL=0.5 s. Đây là bước tạm thời, không thay mục
  tiêu dài hạn EE của UAV có năng lượng bay và truyền thông.
- Mỗi user: `bitsPerUserPerSlot(n,u) = R_DL(n,u)*0.5`. NOMA phục vụ đồng
  thời các user nên không chia thêm 0.5 s cho số user.
- `bitsPerSlot(n) = sum_u(bitsPerUserPerSlot(n,u))`,
  `totalBits = sum_n(bitsPerSlot(n))`,
  `energyPerSlot(n) = pt(n)*0.5`, `totalEnergy = sum_n(energyPerSlot(n))`.
  Fitness là `totalBits/totalEnergy`, đơn vị bit/J. Không lấy min-rate hay
  score có fairness penalty làm tử số trong chế độ này.
- 21 waypoint là 20 đoạn/slot (20 s); thời điểm waypoint từ 0 đến 20 s.
  Tạm dùng kênh tại điểm đầu đoạn; endpoint cuối không có slot phục vụ thêm.
  Các trace rate/pt vẫn 21 hàng để giữ cấu trúc V8, nhưng tổng chỉ lấy 1–20.
- Đây là xấp xỉ kênh không đổi trong mỗi slot và **giả định UL cung cấp đủ
  dữ liệu**. Không tự đưa min-rate hai chặng vào khi ánh xạ 3 BS→5 GU chưa
  được chốt. Chưa thêm QoS, speed/acceleration constraints hay energy bay.
- EE mode đặt dxMax=dzMax=Inf, giữ vùng x/z và endpoints. Cơ chế repair của
  PSO không thay đổi. Không tuyên bố quỹ đạo này đáp ứng vận tốc UAV thực.
- Công suất `pt` không đổi khi UL/DL tăng đồng thời từ microsecond lên
  0.5 s: trong mô hình EH tuyến tính lý tưởng, `pt=EH/T_DL` và tỷ số
  `T_UL/T_DL=1`. Các hàm rate giữ nguyên; `EH` chẩn đoán được cập nhật theo
  0.5 s trong hàm tính metrics. Tham số RF hardcode trong model và sim vẫn
  cần đồng nhất nếu sau này thay Pr/phi/eta; lượt này không refactor chúng.
- Code tập trung ở `addRFSlotMetrics.m`. Ba evaluator gọi helper ở cuối;
  alpha polishing dùng EE toàn cục để nhận nghiệm; optimizer chỉ bỏ nhãn
  đơn vị bps cố định trong log. Main thêm chọn mode và báo bits/J theo user.
- Người dùng yêu cầu tên entry point mới **`scripts/maincodeV9_EE.m`**.
  Bản này cố định `objectiveMode='ee-rf'`. `maincodev8nUser.m` giữ nguyên
  để lấy lại fitness, Tslot=1e-6 và giới hạn bước của V8. Khi sim không có
  objectiveMode, evaluator giữ hành vi rate cũ. Mã gốc reference giữ nguyên.
  Tên V9_EE là tên bản mới phát triển trực tiếp từ V8, không kế thừa hướng
  V9 lịch sử với cache/tau tối ưu hoặc các mô hình ngoài phạm vi.
- **Không chạy MATLAB:** yêu cầu mới của người dùng trong lượt triển khai.
  Trước khi nhận yêu cầu, một lần khởi động batch đã thoát mã 1, không có
  logfile hoặc kết quả mô phỏng. Không chạy lại MATLAB; kiểm tra tĩnh và
  lưu test `tests/testRFSlotMetrics.m` cho người dùng chạy khi muốn.
- Mẫu số zero không được thay bằng eps: EE undefined (NaN), fitness=-Inf.
  Particle vi phạm biên cũng có fitness=-Inf trong EE mode, tránh EE rất
  lớn vượt penalty cố định. `eeRF` báo riêng khỏi fitness cho nghiệm invalid.
- Bài tham khảo đã được người dùng đổi tên thành `1_EE_fixedWing.pdf`,
  `2_rotaryWing.pdf`, `3_relay_QoS.pdf`, `4_decode_EEopt.pdf`,
  `5_BSEnergy.pdf`. Nội dung đọc ngày 13/10 vẫn ứng với cùng số bài.
- Theo yêu cầu hiển thị rõ đơn vị, log PSO/IPSO, alpha polishing và kết quả
  cuối đều ghi fitness `bit/s` ở V8 và `bit/J` ở V9_EE. Dòng diagnostics
  còn ghi riêng rate/rawObj bằng bit/s và meanPt bằng W. Đây chỉ là sửa
  hiển thị, không đổi công thức hoặc thuật toán. MATLAB không được chạy.

## 11. Log V9 EE người dùng cung cấp và chẩn đoán gần hội tụ

Log seed 2026: Joint=8.526046044124e12, Full PSO sau polishing=
8.491757029058e12, Full IPSO sau polishing=8.472150221818e12 bit/J.
Các kết quả khác nhau, trong khoảng 0.6362%; không tuyên bố cùng nghiệm.
Mẫu số chỉ RF nên giá trị rất lớn; đây chưa là EE có năng lượng bay/mạch.

Đã suy ra từ công thức code: với g yếu→mạnh và alpha bị ép giảm dần,
alpha đều tối đa sum-rate khi quỹ đạo/BS cố định, nên cũng tối đa EE RF
theo alpha. Polishing hai luồng Full luôn thử alpha đều; tính chất này
làm phần tối ưu alpha có nghiệm chung đơn giản. Joint chưa có trace để
xác nhận alpha cuối bằng đều. P không triệt tiêu chính xác khỏi EE; chưa
có bằng chứng low-SNR từ log. Full thấp hơn nghiệm Joint cho thấy các
lần tìm kiếm Full chưa đạt ít nhất nghiệm Joint có sẵn trong miền Full.

Chi tiết phép suy ra và số liệu ở `EE_RF_DIAGNOSIS_SEED2026.md`.
`scripts/diagnoseV9_EE.m` chỉ đọc kết quả workspace để user tự kiểm tra
alpha, SNR và chênh quỹ đạo; agent không chạy MATLAB. Main V9 hiện có seed
mặc định 608060 do user thay; không sửa hoặc gán log seed2026 cho seed đó.

## 12. Kết quả diagnose do người dùng chạy — seed 608060

Người dùng cung cấp output diagnose trong workspace có mainSeed=608060;
đây là một scenario khác log seed2026, agent không chạy MATLAB.

| Luồng | EE RF (bit/J) | EE nếu alpha đều, giữ nguyên trajectory/BS (bit/J) | max sai lệch alpha so với 0.2 |
|---|---:|---:|---:|
| Joint PSO | 1.642991901833e13 | 1.671990047896e13 | 0.2975822 |
| Full PSO | 1.661973980102e13 | 1.661973980102e13 | 0 |
| Full IPSO | 1.697276290085e13 | 1.697276290085e13 | 0 |

Xác nhận từ trace: hai Full dùng alpha đều chính xác; Joint chưa tối ưu
alpha, còn gain 1.76495977% khi chỉ thay alpha đều. Không nói cả ba đã có
alpha gần 0.2 hoặc cùng EE/quỹ đạo. Max chênh x của các cặp lần lượt
32.111907, 44.057448 và 49.142753 m; max chênh z đều 30 m.

SNR thuần lớn nhất mỗi nghiệm khoảng 70–75, chỉ 11–12% mẫu dưới 0.1.
Không dùng xấp xỉ low-SNR cho toàn scenario. Phép chứng minh alpha đều
trong `EE_RF_DIAGNOSIS_SEED2026.md` là chính xác cho mọi P>0/noise>0:
sum-rate tăng theo từng tail power S_i; alpha giảm dần giới hạn mỗi S_i
ở (N-i+1)/N; alpha đều đạt đồng thời mọi giới hạn. Không dựa vào SNR thấp.
Kết luận chỉ áp dụng cho sum-rate/EE RF với alpha ordering hiện hành,
không phải min-rate V8 hoặc NOMA không có ràng buộc ordering này.

## 13. Lưu lịch sử và đồ thị EE theo yêu cầu người dùng

Người dùng yêu cầu các đồ thị để tìm hiểu EE của ba thuật toán gần nhau.
Ba optimizer thêm `totalBitsHistory` và `totalEnergyHistory` trong EE mode,
lấy từ cùng gbestRes với bestHistory ở vòng 0 và cuối mỗi vòng. IPSO ghi
sau mutation. Không gọi evaluator thêm, không đổi RNG/fitness/search logic.
Trong EE mode, polishing giữ nguyên lịch sử optimizer và copy hai mảng
mới; các metrics cuối vẫn là nghiệm sau polishing. Rate mode giữ hành vi
bestHistory cũ. Main V9 thay Figure 6 cũ bằng một call `plotV9EEDiagnostics`
tạo Figure 6–10: EE, bit, RF energy theo vòng; metrics/alpha theo slot;
quan hệ tổng bit–năng lượng cuối. Vòng tròn đánh dấu sau polishing riêng.

Kết quả cũ có thể vẽ EE và các metrics cuối/slot ngay; thiếu bit/energy
history nên Figure 7/8 dùng bar kết quả cuối, ghi rõ cần rerun để có đường
theo vòng. Agent không chạy MATLAB. Main giữ seed608060 và các cấu hình
người dùng hiện có. Ảnh PNG seed608060 trong results/ee_rf được tạo từ
các tổng trong diagnose người dùng gửi, không suy diễn các iteration.

## 14. Lịch sử từng user, công suất và hệ số NOMA

Theo yêu cầu tiếp theo, ba optimizer EE ghi thêm `totalBitsPerUserHistory`
(iteration × user), `transmitPowerHistory` (iteration × slot, W) và
`alphaUserHistory` (iteration × slot × user), từ chính gbestRes ở vòng 0
và cuối mỗi vòng; IPSO ghi sau mutation. Alpha lấy `alphaTrace`, theo ID
user vật lý, không dùng `alphaOrdTrace` theo hạng kênh. Bit là tổng nhận
trong toàn mission của nghiệm best-EE ở vòng đó, không cộng các vòng PSO.
Slot chỉ 1:numSteps-1. Không thêm RNG/evaluation, giữ seed/options hiện có.
Polishing copy các lịch sử và không ghi đè vòng cuối; điểm sau polishing
riêng trong đồ thị đường. `plotV9EEUserHistories` được gọi tự động từ
`plotV9EEDiagnostics`: Figure 11 bit từng user (Mbit); 12 công suất RF
trung bình/min/max và heatmap slot × vòng (nW); 13 alpha trung bình của
mỗi user; 14/15/16 heatmap alpha từng user cho Joint/Full PSO/Full IPSO.
Power heatmaps dùng chung color limits, alpha heatmaps dùng [0,1].
Có kiểm tra kích thước, tổng bit user bằng totalBitsHistory, tích tổng
power với thời gian DL bằng totalEnergyHistory, tổng alpha bằng 1.
Kết quả cũ thiếu fields thì warning yêu cầu rerun và không dựng lịch sử giả.
Agent không chạy MATLAB; chỉ kiểm tra mã tĩnh.

## 15. Tổng quãng đường UAV từ kết quả đã có

User yêu cầu cộng khoảng cách Euclid 3D của ba quỹ đạo, tạm chưa xét trọng
lực/năng lượng bay. `measureV9FlightDistance(trajJoint,trajFull,trajIPSO)`
tính sum(sqrt(dx^2+dy^2+dz^2)) qua mọi waypoint liên tiếp, bao gồm đoạn
đến waypoint cuối, in mét và trả table `flightDistanceSummary` cùng cell
`flightSegmentDistances` theo thứ tự Joint/Full PSO/Full IPSO. Main V9
gọi tự động ở phần kết quả cuối. Có thể gọi riêng từ workspace đã chạy,
không cần optimizer. Không sửa fitness hay chạy MATLAB. Giả định quỹ đạo
là đoạn thẳng nối waypoint; chưa quy đổi mét sang joule.

## 16. Phân tích cấu trúc toán học fitness từ mã nguồn (2026-10-15)

Đọc lại code hiện tại: default mainSeed đã được user đổi thành 3486784401;
không sửa seed. Các con số diagnose trước đây vẫn thuộc seed608060.
Không chạy MATLAB và không sửa thuật toán trong lần phân tích này.

- EE hợp lệ thực sự là F=sum_n U_n/sum_n P_n, U_n=sum_i R_ni;
  downlinkTime=0.5 triệt tiêu. addRFSlotMetrics ghi đè fitness V8; các
  thành phần min-rate, fairness, smoothness không vào tỷ số EE.
- Với q/BS cố định: P_n độc lập alpha; alpha sắp giảm dần theo thứ tự
  kênh yếu→mạnh có nghiệm tối ưu đều 1/N. Đẳng thức tail-power và đạo hàm
  trong mục trước cho chứng minh chính xác, không cần low/high-SNR.
  Polisher chủ động thử alpha đều đầu tiên ở mỗi slot; hai Full nhận
  cùng loại nghiệm alpha từ bước này, không chứng minh solver raw tự đạt.
- Hạt có 143 biến Joint, 149 biến Full: 38 tọa độ UAV, 105 trọng số alpha,
  thêm 6 tọa độ BS cho Full. Khi loại alpha bằng nghiệm giải tích, bài toán
  tối ưu giá trị còn 38/44 biến hình học. 5 trọng số waypoint 21 không vào
  EE vì chỉ có 20 slot. Chuẩn hóa/sắp xếp làm hoán vị trọng số cùng slot
  cho cùng alpha thực tế ở q/BS cố định; hạt khác nhau có thể cùng fitness.
- dxMax=dzMax=Inf và không có năng lượng bay/đệm dữ liệu/QoS liên slot:
  U_n,P_n chỉ phụ thuộc q_n, alpha_n và BS chung. Với BS cố định, alpha
  đều, miền waypoint là tích các miền riêng. Đặt lambda bất kỳ,
  H(lambda)=max_q sum_n(U_n-lambda P_n)=sum_n max_qn(U_n-lambda P_n).
  F* được đặc trưng bởi H(F*)=0 khi mẫu số dương. Đây là tính tách theo
  slot của bài toán phụ, không phải nói F độc lập hoàn toàn giữa slot hay
  tối ưu từng EE_n riêng sẽ tối ưu EE toàn chuyến. BS vẫn ghép các slot.
- Do đó thiếu mô hình bay đã loại các hạng liên quan q_(n+1)-q_n khỏi
  mục tiêu và miền ràng buộc chuyển động. Đây là hệ quả cấu trúc chứng minh
  được; không chứng minh nó buộc ba thuật toán có cùng fitness/đạt global.
- Hiệu hai nghiệm có đẳng thức F_B-F_A=(DeltaD-F_A*DeltaE)/E_B.
  Nó cho phép bit/energy bù nhau dù quỹ đạo hoặc bit từng user khác nhau.
  Với log608060: uniform Joint EE=1.671990047896e13, cao hơn Full polished
  0.602661%; IPSO cao hơn uniform Joint 1.512344%. Cần phân biệt khoảng
  cách tối ưu alpha và khoảng cách nghiệm hình học, không suy ra optimality.
- Kiểm tra độc lập 1000 bộ số tổng hợp của đẳng thức sum-rate/tail-power:
  sai số tối đa 1.78e-15 (rate/B), alpha đều không kém alpha sắp giảm dần.
  Đây là kiểm tra đại số, không phải mô phỏng hoặc kết quả MATLAB.
