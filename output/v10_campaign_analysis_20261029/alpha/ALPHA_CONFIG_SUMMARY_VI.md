# Tổng hợp cấu hình alpha đều/không đều — campaign 54 lượt

Nguồn: kết quả cuối sau polishing của campaign_20261029_125559. Chia đều toàn nhiệm vụ khi mọi alpha của 20 serving-slot nằm trong 1e−8 quanh 0,2. Không đều nghĩa là có ít nhất một slot lệch; không đồng nghĩa mọi slot đều lệch. Bảng gộp ba nhãn L=3M, slot=5k, hover=1s vì trùng bộ tham số.

Thứ tự seed trong mỗi ô: **S1=2026 / S2=608060 / S3=3486784401**. **Đ** = chia đều toàn bộ; **K** = còn lệch ít nhất một slot. Đơn vị L=Mbit/user, q=kbit/user/serving-slot, h=giây/điểm phục vụ.

| Biến thể | L | q | h | Full PSO: S1/S2/S3 | Full IPSO: S1/S2/S3 |
| --- | --- | --- | --- | --- | --- |
| A | 1 | 5 | 1 | Đ / Đ / Đ | Đ / Đ / Đ |
| A | 2 | 5 | 1 | K / Đ / K | K / Đ / K |
| A | 3 | 5 | 1 | K / Đ / K | K / Đ / K |
| A | 3 | 0 | 1 | K / K / K | K / K / K |
| A | 3 | 10 | 1 | K / K / K | K / K / K |
| A | 3 | 5 | 2 | K / Đ / Đ | K / Đ / Đ |
| A | 3 | 5 | 3 | Đ / Đ / Đ | Đ / Đ / Đ |
| B | 1 | 5 | 1 | Đ / Đ / Đ | K / Đ / Đ |
| B | 2 | 5 | 1 | K / Đ / K | K / Đ / Đ |
| B | 3 | 5 | 1 | K / K / K | K / K / K |
| B | 3 | 0 | 1 | K / Đ / K | K / Đ / Đ |
| B | 3 | 10 | 1 | K / K / K | K / K / Đ |
| B | 3 | 5 | 2 | Đ / Đ / K | Đ / Đ / Đ |
| B | 3 | 5 | 3 | Đ / Đ / Đ | Đ / Đ / Đ |

Lượt A/Full PSO/S1/L=3/q=10/h=1 không đạt toàn bộ QoS; các lượt Full khác đều khả thi. Baseline và Joint PSO không có lượt nào chia đều toàn bộ 20 slot, nhưng nhiều nghiệm của chúng chưa đạt QoS. Kết quả raw trước polishing của hai Full cũng không có lượt nào đều toàn bộ theo sai số 1e−8.

## Danh sách seed theo từng bộ tham số

| Biến thể | L/q/h | Thuật toán | Seed chia đều | Seed không đều |
| --- | --- | --- | --- | --- |
| A | 1/5/1 | Full PSO | 2026, 608060, 3486784401 | — |
| A | 1/5/1 | Full IPSO | 2026, 608060, 3486784401 | — |
| A | 2/5/1 | Full PSO | 608060 | 2026, 3486784401 |
| A | 2/5/1 | Full IPSO | 608060 | 2026, 3486784401 |
| A | 3/5/1 | Full PSO | 608060 | 2026, 3486784401 |
| A | 3/5/1 | Full IPSO | 608060 | 2026, 3486784401 |
| A | 3/0/1 | Full PSO | — | 2026, 608060, 3486784401 |
| A | 3/0/1 | Full IPSO | — | 2026, 608060, 3486784401 |
| A | 3/10/1 | Full PSO | — | 2026, 608060, 3486784401 |
| A | 3/10/1 | Full IPSO | — | 2026, 608060, 3486784401 |
| A | 3/5/2 | Full PSO | 608060, 3486784401 | 2026 |
| A | 3/5/2 | Full IPSO | 608060, 3486784401 | 2026 |
| A | 3/5/3 | Full PSO | 2026, 608060, 3486784401 | — |
| A | 3/5/3 | Full IPSO | 2026, 608060, 3486784401 | — |
| B | 1/5/1 | Full PSO | 2026, 608060, 3486784401 | — |
| B | 1/5/1 | Full IPSO | 608060, 3486784401 | 2026 |
| B | 2/5/1 | Full PSO | 608060 | 2026, 3486784401 |
| B | 2/5/1 | Full IPSO | 608060, 3486784401 | 2026 |
| B | 3/5/1 | Full PSO | — | 2026, 608060, 3486784401 |
| B | 3/5/1 | Full IPSO | — | 2026, 608060, 3486784401 |
| B | 3/0/1 | Full PSO | 608060 | 2026, 3486784401 |
| B | 3/0/1 | Full IPSO | 608060, 3486784401 | 2026 |
| B | 3/10/1 | Full PSO | — | 2026, 608060, 3486784401 |
| B | 3/10/1 | Full IPSO | 3486784401 | 2026, 608060 |
| B | 3/5/2 | Full PSO | 2026, 608060 | 3486784401 |
| B | 3/5/2 | Full IPSO | 2026, 608060, 3486784401 | — |
| B | 3/5/3 | Full PSO | 2026, 608060, 3486784401 | — |
| B | 3/5/3 | Full IPSO | 2026, 608060, 3486784401 | — |

## Các lượt còn lệch: số slot chia đều trên 20

| Biến thể | L/q/h | Thuật toán | Seed 2026 | Seed 608060 | Seed 3486784401 |
| --- | --- | --- | --- | --- | --- |
| A | 1/5/1 | Full PSO | 20/20 | 20/20 | 20/20 |
| A | 1/5/1 | Full IPSO | 20/20 | 20/20 | 20/20 |
| A | 2/5/1 | Full PSO | 1/20 | 20/20 | 9/20 |
| A | 2/5/1 | Full IPSO | 2/20 | 20/20 | 4/20 |
| A | 3/5/1 | Full PSO | 5/20 | 20/20 | 2/20 |
| A | 3/5/1 | Full IPSO | 1/20 | 20/20 | 3/20 |
| A | 3/0/1 | Full PSO | 2/20 | 14/20 | 8/20 |
| A | 3/0/1 | Full IPSO | 4/20 | 4/20 | 2/20 |
| A | 3/10/1 | Full PSO | 0/20 | 19/20 | 3/20 |
| A | 3/10/1 | Full IPSO | 1/20 | 19/20 | 0/20 |
| A | 3/5/2 | Full PSO | 4/20 | 20/20 | 20/20 |
| A | 3/5/2 | Full IPSO | 0/20 | 20/20 | 20/20 |
| A | 3/5/3 | Full PSO | 20/20 | 20/20 | 20/20 |
| A | 3/5/3 | Full IPSO | 20/20 | 20/20 | 20/20 |
| B | 1/5/1 | Full PSO | 20/20 | 20/20 | 20/20 |
| B | 1/5/1 | Full IPSO | 19/20 | 20/20 | 20/20 |
| B | 2/5/1 | Full PSO | 18/20 | 20/20 | 19/20 |
| B | 2/5/1 | Full IPSO | 19/20 | 20/20 | 20/20 |
| B | 3/5/1 | Full PSO | 2/20 | 19/20 | 17/20 |
| B | 3/5/1 | Full IPSO | 1/20 | 15/20 | 2/20 |
| B | 3/0/1 | Full PSO | 4/20 | 20/20 | 4/20 |
| B | 3/0/1 | Full IPSO | 3/20 | 20/20 | 20/20 |
| B | 3/10/1 | Full PSO | 2/20 | 17/20 | 3/20 |
| B | 3/10/1 | Full IPSO | 1/20 | 2/20 | 20/20 |
| B | 3/5/2 | Full PSO | 20/20 | 20/20 | 19/20 |
| B | 3/5/2 | Full IPSO | 20/20 | 20/20 | 20/20 |
| B | 3/5/3 | Full PSO | 20/20 | 20/20 | 20/20 |
| B | 3/5/3 | Full IPSO | 20/20 | 20/20 | 20/20 |

## Ràng buộc có đủ để ép alpha lệch không?

Alpha đều cho thấy các ngưỡng hiện tại cho phép phương án đều trên hình học tìm được, nên chúng không buộc nghiệm đó phải phân bổ lệch. Điều này chưa chứng minh các ràng buộc hoàn toàn không active, mức L/q không hợp lý hay thuật toán lỗi. Mục tiêu sum-EE và ordering alpha hiện tại ưu tiên đều nếu vẫn thỏa QoS; polishing thử trực tiếp ứng viên đều mỗi slot.

Trong 29 lượt IPSO còn lệch (19 tổ hợp khác nhau), ép toàn bộ về đều trên cùng kênh/quỹ đạo/BS làm: **20 lượt chỉ vi phạm L, 3 lượt chỉ vi phạm user-slot, 6 lượt vi phạm cả hai**. Sau loại trùng tương ứng **12, 3, 4**. Vậy L và q đã có tác dụng buộc lệch ở một phần rõ ràng của campaign, không thể nói cả hai đều chưa đủ tác động.

Ví dụ L đã tác động: A/IPSO/L3/q5/h1, seed2026 và 3486784401 đều còn lệch. Ví dụ q đã tác động độc lập: B/IPSO/L1/q5/h1, seed2026 chỉ còn một slot lệch; ép đều vẫn đủ L nhưng thiếu user-slot. A/IPSO/L3/q10/h1, seed608060 cũng chỉ vi phạm user-slot khi ép đều.

Ở hover3s, mọi seed của cả A/B và cả Full đều chia đều. Tăng thời gian phục vụ khiến lượng bit đạt với alpha đều có thể vượt các ngưỡng đang yêu cầu. Ngược lại, tăng q không bảo đảm alpha lệch ở mọi seed: B/IPSO/seed3486784401 ở L3/q10/h1 vẫn đều, trong khi ở q5 thì lệch; quỹ đạo/BS tìm được đã thay đổi giữa hai lượt.

Hai ngoại lệ Full PSO: A/seed608060/q0/h1 và B/seed608060/bộ mặc định vẫn lệch dù ép đều còn khả thi và tăng EE khoảng 0,279% và 0,124%. Vì thế một phần lệch còn có thể do tìm kiếm/polishing chưa tối ưu. Không chọn L/q chỉ để làm alpha trông khác 0,2; chọn theo yêu cầu dữ liệu rồi báo cáo tính khả thi và đánh đổi EE.

## Tệp đầy đủ

- [54 lượt, ma trận cả bốn phương pháp](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/run_alpha_matrix_54.csv)
- [216 kết quả cuối với phân loại alpha](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/final_alpha_classification_216.csv)
- [Các kết quả chia đều toàn bộ](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/uniform_final_results.csv)
- [Các kết quả còn alpha lệch](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/alpha/nonuniform_final_results.csv)