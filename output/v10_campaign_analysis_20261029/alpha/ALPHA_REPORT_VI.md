# Phân tích alpha trong campaign 54 lượt V10A/V10B

Reference files read: `matlab-analyze-data/references/array-and-grid-data.md`, `data-transformation.md`; cùng các reference exploration, grouping, answering-data-questions đã đọc ở lượt phân tích trước.

**Kết luận trực tiếp:** alpha cuối có cả trường hợp chia đều và trường hợp lệch mạnh. Ở Full IPSO, 23/42 tổ hợp tham số khác nhau chia đều toàn bộ 20 slot; 19 tổ hợp còn lại sẽ vi phạm QoS nếu ép toàn bộ alpha về 0,2 trên chính quỹ đạo/BS đã lưu. Các nghiệm chia đều chính xác xuất hiện sau polishing. Điều này phù hợp với hàm mục tiêu sum-EE và ràng buộc của code, nhưng không chứng minh mọi alpha lệch là tối ưu toàn cục.

## 1. Đúng đại lượng cần đọc

Mỗi nghiệm có **20 slot phục vụ × 5 user**. Ma trận `alphaTrace(1:20,:)` là alpha theo **User ID gốc**; `alphaOrdTrace` là theo thứ tự kênh yếu→mạnh, thứ tự này thay đổi theo slot. `rawAlpha` là các trọng số trước khi evaluator chuẩn hóa/sắp xếp lại, không nên gán trực tiếp cột raw cho User ID. Waypoint 21 là điểm đến, không có phục vụ; bỏ hàng 21 khi thống kê alpha truyền dữ liệu.

Theo từng slot n: `P_u(n) = alpha_u(n) × P_RF(n)`, `sum(alpha_u(n))=1`. `alphaMean` trong CSV là trung bình cả 100 phần tử, nên luôn bằng `20/(20×5)=0,2`, dù từng hàng rất lệch. Ngược lại, `mean(alphaTrace(1:20,:),1)` trả năm trung bình riêng theo user, có thể khác nhau. Ngay cả năm trung bình này cũng có thể che mất các slot lệch ngược chiều nhau.

Thước đo sử dụng ở đây: số slot có `max(abs(alpha−0,2)) <= 1e−8`; “gần đều” dùng ngưỡng 1e−3; alpha lớn nhất, độ lệch trung bình, tổng bit từng user và khả năng thỏa QoS khi ép chia đều. Chỉ gọi một nhiệm vụ “chia đều toàn bộ” nếu cả 20 slot đạt ngưỡng 1e−8.

## 2. Kết quả raw và sau polishing

Bảng dùng 21 tổ hợp tham số khác nhau mỗi biến thể, đã loại ba nhãn trùng bộ mặc định. Raw là kết quả optimizer trước polishing; final là kết quả lưu cuối.

| Biến thể | Thuật toán | Raw: cả 20 slot đều | Final: cả 20 slot đều | Số slot đều TB: raw → final | Độ lệch tuyệt đối TB: raw → final |
| --- | --- | --- | --- | --- | --- |
| A | Full PSO | 0/21 | 10/21 | 0,19 → 12,71 | 0,03089 → 0,02518 |
| A | Full IPSO | 0/21 | 10/21 | 4,05 → 11,43 | 0,01643 → 0,01621 |
| B | Full PSO | 0/21 | 10/21 | 0,05 → 15,43 | 0,05638 → 0,01564 |
| B | Full IPSO | 0/21 | 13/21 | 0,00 → 15,33 | 0,02279 → 0,00766 |

Trước polishing, **không có nghiệm Full nào chia đều cả 20 slot theo ngưỡng 1e−8**. Tuy nhiên A/IPSO đã có 10/21 nghiệm mà toàn bộ alpha nằm trong ±0,001 quanh 0,2; sau polishing chính 10 nghiệm đó chia đều chính xác. B/IPSO không có nghiệm raw gần đều toàn bộ theo ngưỡng ±0,001, nhưng sau polishing có 13/21 nghiệm đều toàn bộ. Do đó cần phân biệt **đã gần đều do optimizer** với **được polishing đưa về đúng 0,2**.

Nếu giữ toàn bộ 54 lượt, số nhiệm vụ chia đều cuối của A/PSO, A/IPSO, B/PSO, B/IPSO lần lượt là **12/27, 12/27, 10/27, 13/27**. Khác biệt với bảng do bộ mặc định A/seed608060 được lưu ba lần. Baseline và Joint không có nhiệm vụ nào đều toàn bộ; Joint không được gọi polishing trong pipeline này.

`polishAlphaV10` luôn thử ứng viên đầu tiên là `[0,2 0,2 0,2 0,2 0,2]` ở từng slot. Nó chỉ nhận khi fitness toàn nhiệm vụ tăng; không gán đều vô điều kiện. Nếu ứng viên làm thiếu bit/user hay user-slot, nghiệm khả thi đang có sẽ được giữ. Polishing cố định hình học/BS, chỉ đổi alpha.

![Polishing và tác dụng của QoS](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/polishing_and_qos.png)

## 3. Full IPSO ở từng nhóm tham số

Mỗi ô ghi số nhiệm vụ chia đều toàn bộ / 3 seeds; sau dấu chấm phẩy là số slot đều trung bình trên 20. Các nhãn `L=3M`, `slot=5k`, `hover=1s` được gộp thành một bộ mặc định.

| Cấu hình | V10A + IPSO | V10B + IPSO |
| --- | --- | --- |
| L=1M | 3/3; 20,00/20 slot | 2/3; 19,67/20 slot |
| L=2M | 1/3; 8,67/20 slot | 2/3; 19,67/20 slot |
| L=3M | 1/3; 8,00/20 slot | 0/3; 6,00/20 slot |
| slot=0k | 0/3; 3,33/20 slot | 2/3; 14,33/20 slot |
| slot=10k | 0/3; 6,67/20 slot | 1/3; 7,67/20 slot |
| hover=2s | 2/3; 13,33/20 slot | 3/3; 20,00/20 slot |
| hover=3s | 3/3; 20,00/20 slot | 3/3; 20,00/20 slot |

Ở hover3s, cả A/B chia đều toàn bộ ở cả ba seed. Khi thời gian phục vụ dài hơn, nhiều yêu cầu dữ liệu đã đủ với alpha đều. Ở bộ mặc định L=3M/5k/1s, A chỉ có seed608060 đều toàn bộ; B còn alpha khác đều ở cả ba seed. L tăng không làm độ lệch alpha tăng đơn điệu, vì quỹ đạo/BS tối ưu tìm được cũng thay đổi.

## 4. Bộ mặc định: alpha thực tế theo từng seed

| Biến thể | Seed | Slot chia đều | Alpha lớn nhất | Nếu ép toàn bộ về 0,2 |
| --- | --- | --- | --- | --- |
| A | 2026 | 1/20 | 0,832891 | L |
| A | 608060 | 20/20 | 0,200000 | Không vi phạm |
| A | 3486784401 | 3/20 | 0,467215 | L |
| B | 2026 | 1/20 | 0,495801 | L + user-slot |
| B | 608060 | 15/20 | 0,214287 | L |
| B | 3486784401 | 2/20 | 0,312991 | L |

![Alpha từng user/slot ở cấu hình mặc định](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/default_alpha_heatmaps.png)

### Ví dụ A/IPSO, seed2026, L=3M/5k/1s

| User | Alpha TB riêng user | Bit với alpha đã lưu (Mbit) | Bit nếu mọi slot alpha=0,2 (Mbit) |
| --- | --- | --- | --- |
| U1 | 0,164123 | 5,978267 | 6,294477 |
| U2 | 0,171501 | 14,530315 | 15,143014 |
| U3 | 0,164274 | 3,508535 | 3,871610 |
| U4 | 0,164085 | 19,122081 | 22,278293 |
| U5 | 0,336018 | 3,000000 | 1,212105 |

U5 là user đang sát ngưỡng: chỉ dư **0,379 bit** so với 3 Mbit. Nếu ép chia đều trên cùng kênh/quỹ đạo/BS, U5 chỉ còn **1,212105 Mbit**, thiếu **1,787895 Mbit**. Trong khi đó tổng bit toàn nhiệm vụ sẽ tăng **5,7658%**. Điều này thể hiện chính xác đánh đổi: phân bổ lệch hy sinh một phần tổng bit để bảo đảm user thiếu dữ liệu.

Slot 10 của nghiệm này có alpha theo User ID:

`[0,041777; 0,041778; 0,041777; 0,041777; 0,832891]` (viết dạng hàng gồm U1…U5).

Thứ tự kênh yếu→mạnh tại slot đó là **U5 → U2 → U3 → U1 → U4**. U5 nhận khoảng **83,29%** công suất, nhưng chỉ đạt **0,656 Mbit**; U4 nhận khoảng **4,18%**, vẫn đạt **1,523 Mbit**. Kênh và nhiễu/SIC quyết định số bit, nên không thể so bit chỉ từ tỷ lệ công suất.

### Ví dụ B/IPSO, seed2026, cùng cấu hình mặc định

Trung bình alpha của U5 là **0,273252**; tổng bit U5 **3,000001 Mbit**. Ép chia đều làm U5 còn **2,138904 Mbit**, thiếu **0,861096 Mbit**, đồng thời thiếu tổng **2.848,11 bit** trên các user-slot. Tổng bit vẫn có thể tăng **0,8800%**, nhưng nghiệm đó không đáp ứng QoS. Riêng slot20, alpha U5≈**0,495801** và U5 chỉ nhận **5.346,36 bit**, sát ngưỡng 5 kbit của slot.

### Ví dụ B/IPSO, seed608060: gần đều cũng có tác dụng

Nghiệm mặc định có 15/20 slot chia đều, alpha lớn nhất chỉ **0,214287**. Trung bình riêng các user đều nằm gần 0,2, nhưng nếu bỏ các điều chỉnh nhỏ và ép mọi slot về đúng 0,2, U1 thiếu khoảng **8.352,34 bit** so với L. Do đó mức lệch nhỏ không có nghĩa là vô tác dụng.

## 5. Vì sao code thường ưu tiên 0,2?

Evaluator sắp alpha giảm dần cho user có kênh tăng dần: user yếu nhận alpha lớn hơn hoặc bằng user mạnh. Tức theo thứ tự kênh: `alpha_1 >= alpha_2 >= ... >= alpha_5`. Đây là ràng buộc quan trọng để diễn giải nghiệm chia đều. Cộng với tổng bằng 1, các ràng buộc này **không tự ép** tất cả alpha phải bằng nhau: `[0,6; 0,1; 0,1; 0,1; 0,1]` vẫn hợp lệ về ordering/tổng.

Tuy nhiên, với công thức rate và ideal SIC hiện tại, **khi cố định quỹ đạo, BS, kênh và công suất RF**, chia đều là một nghiệm tối đa tổng rate trong miền alpha có ordering này nếu bỏ QoS từng user. Năng lượng RF, cruise và hover không phụ thuộc alpha khi giữ hình học cố định, nên điều đó cũng áp dụng cho EE. Nếu alpha đều đã đủ QoS, polishing thường chọn đều; nếu chưa đủ, cần giữ một số slot lệch để bù cho user.

Đây là kết luận cho công thức/ràng buộc hiện có; không khái quát thành mọi bài toán NOMA đều tối ưu ở alpha đều.

## 6. Kiểm tra phản thực trên toàn bộ kết quả

Tôi tính lại rate trong Python từ `h2UserTrace`, `pt`, nhiễu, bandwidth và thời gian downlink đã lưu. Rate tái dựng với alpha gốc khớp `bitsPerUserPerSlot` (rtol 2e−11, atol 1e−7 bit), rồi thay alpha bằng 0,2 để đối chiếu. Không chạy MATLAB, PSO hay thay hình học. Trong mọi trường hợp kiểm tra, tổng bit với alpha đều không thấp hơn tổng bit gốc trong sai số số học.

Với **Full IPSO sau polishing** trên 42 tổ hợp:

| Biến thể | Nghiệm đều toàn bộ | Nghiệm còn lệch | Trong các nghiệm lệch: ép đều vẫn đủ QoS |
| --- | --- | --- | --- |
| A | 10/21 | 11/21 | 0/11 |
| B | 13/21 | 8/21 | 0/8 |
| Tổng | 23/42 | 19/42 | 0/19 |

Như vậy, trên chính các hình học mà IPSO đã tìm được, **mọi trường hợp cuối còn lệch đều có lý do QoS khi so với ép đều toàn bộ**. Điều đó không chứng minh từng hệ số/slot lệch đều cần thiết, hay không tồn tại quỹ đạo khác cho phép chia đều tốt hơn.

Full PSO có hai ngoại lệ đáng chú ý: **A/seed608060/slot0k** và **B/seed608060/bộ mặc định** vẫn để alpha lệch, mặc dù ép toàn bộ về 0,2 vẫn khả thi và tăng EE lần lượt **0,2791%** và **0,1236%**. Vì thế không thể gán mọi alpha lệch của mọi thuật toán cho sự cần thiết của QoS.

Kiểm tra riêng từng slot trên nghiệm cuối còn cho thấy một số cải thiện nhỏ vẫn có thể thực hiện: A/IPSO/seed608060/slot0k có hai slot có thể đưa về đều, gain tốt nhất khi đổi một slot **0,000907%**; A/IPSO/seed3486784401/bộ mặc định có sáu slot như vậy, gain tốt nhất **0,007788%**. Đây là phép thử từng slot độc lập trên nghiệm cuối, không cộng các gain như thể có thể đổi đồng thời tất cả.

Nguồn hiện tại của polishing quét các slot theo thứ tự 1→20 **một lần**. Các thay đổi ở slot sau có thể làm dư dữ liệu, mở khả năng cải thiện slot trước, nhưng hàm không quay lại quét tiếp. Cơ chế này có thể giải thích phần alpha lệch còn dư; phép kiểm tra đã xác nhận kết quả cuối chưa tối ưu ngay cả đối với một số phép đổi một slot về đều. Báo cáo chỉ ghi nhận, chưa sửa hàm.

## 7. Alpha đều và fairness dữ liệu là hai chuyện khác nhau

B/IPSO/seed2026/hover3s có tất cả alpha=0,2, nhưng bit từng user là **[18,4175; 6,5514; 16,2616; 160,5550; 6,9944] Mbit**, Jain≈**0,3293**. U4 nhận khoảng **76,9%** tổng bit dù chỉ nhận 20% công suất trong mỗi slot. Đây là hệ quả kênh và rate/SIC, đồng thời mục tiêu chỉ yêu cầu các user vượt ngưỡng tối thiểu. Chia đều công suất không bảo đảm công bằng dữ liệu.

## 8. Phụ lục: giải thích đại số cho xu hướng chia đều

Xét một slot, gọi gain đã sắp xếp là `g1 <= ... <= gN`, đặt `s_i = noise/(P*g_i)` nên `s1 >= ... >= sN`, và `S_i = sum_{j=i}^N alpha_j`. Bỏ hệ số bandwidth chung:

```text
R_i = log2[(s_i + S_i)/(s_i + S_(i+1))]
sum R_i = log2(s_1+1) - log2(s_N)
          + sum_(i=2..N) {log2(s_i+S_i) - log2(s_(i-1)+S_i)}
```

Mỗi hạng trong tổng sau không giảm khi `S_i` tăng, vì `s_i <= s_(i−1)`. Ràng buộc `alpha_1 >= ... >= alpha_N`, tổng bằng 1, cho `S_i <= (N−i+1)/N`. Chia đều `alpha_i=1/N` đạt đồng thời mọi cận trên này, nên tối đa tổng rate trong miền ordering. QoS theo User ID và theo slot có thể loại nghiệm này khỏi miền khả thi, như các số liệu phía trên chứng minh.

## 9. Dữ liệu và mã nguồn đối chiếu

- [Alpha chi tiết và bit từng serving-slot](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/alpha_and_bits_per_slot.csv)
- [Thống kê alpha sau loại trùng, cả raw/final](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/unique_alpha_summary.csv)
- [Alpha, bit gốc và bit phản thực chia đều](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/alpha_details.json)
- [Chuẩn hóa và sắp xếp alpha theo kênh](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/src/evaluators/evaluateTrajectoryV10.m)
- [Công thức SINR/rate và công suất RF](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/src/models/findAchievableRateV10.m)
- [Cơ chế polishing](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/src/optimizers/polishAlphaV10.m)

Ngưỡng chia đều trong báo cáo là 1e−8; không suy từ số chữ số hiển thị trên figure. Baseline dùng alpha theo kênh, Joint không polishing. Các kết luận về phản thực chỉ áp dụng trên các kênh/hình học đã lưu và mô hình hiện hành. Không chạy lại mô phỏng, không sửa solver.