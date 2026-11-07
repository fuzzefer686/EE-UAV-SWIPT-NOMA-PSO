# Đọc kết quả V10C chạy tối 03/11/2026

Phân tích ngày 04/11/2026. Đọc file MAT gốc và đánh giá lại 54 candidate bằng evaluator hiện tại. Không chạy lại thuật toán tối ưu và không thay đổi kết quả gốc.

## 1. Kiểm tra bộ chạy

- Đủ C0–C5 × 3 seed × 3 thuật toán = 54 lượt; 37 lượt tìm được nghiệm khả thi.
- Seed: 2026, 608060, 3486784401; L=3 Mbit/user, q=5 kbit/user/slot, Emax=17 kJ.
- Mỗi lượt: 120 particle, 1000 vòng, 120120 lần đánh giá gồm cả khởi tạo.
- Đã xác nhận 54 khóa preset/seed/method không trùng; 1001 mốc history mỗi lượt; best fitness không giảm; Joint PSO giữ nguyên BS; cờ khả thi và EE khớp khi tính lại từ candidate.
- Log ghi hoàn tất khoảng 23:34 ngày 03/11 theo giờ địa phương.

## 2. EE và tính khả thi

EE trung bình trên các nghiệm **khả thi**, đơn vị bit/J. Ngoặc là số seed thành công trên 3; “—” là chưa tìm được nghiệm khả thi. Nhóm chỉ có một nghiệm không có đủ dữ liệu để đánh giá độ phân tán.

| Cấu hình | Joint PSO, BS cố định | Full PSO | Full IPSO |
|---|---:|---:|---:|
| C0 | 3,698 (1/3) | 7,662 (3/3) | 9,513 (3/3) |
| C1 | 4,280 (1/3) | 9,817 (3/3) | 10,451 (3/3) |
| C2 | 3,772 (1/3) | 11,113 (3/3) | 10,268 (3/3) |
| C3 | 3,317 (1/3) | 11,241 (3/3) | 10,371 (3/3) |
| C4 | 4,209 (1/3) | 12,005 (3/3) | 12,614 (3/3) |
| C5 | — (0/3) | — (0/3) | 2,479 (2/3) |

Joint PSO chỉ thành công tại seed 608060 cho C0–C4. Các giá trị trung bình Joint vì vậy thực chất là từng nghiệm của seed đó; không so trực tiếp với trung bình đủ ba seed của Full để định lượng lợi ích tối ưu BS. Các thất bại Joint đều vi phạm q; phần lớn còn vi phạm L, trong khi đều dưới 17 kJ. Đây là kết quả của bộ tìm kiếm hiện tại, không phải chứng minh BS cố định bất khả thi.

## 3. C4 và ý nghĩa của các biến thời gian

- Full PSO: C4 hơn C0 56.69%; hơn C1 22.29% theo tỷ lệ của EE trung bình.
- Full IPSO: C4 hơn C0 32.60%; hơn C1 20.70% theo tỷ lệ của EE trung bình.

C4 có trung bình cao nhất trong C0–C4 cho cả hai phương pháp Full. C0→C4 đồng thời đổi quy tắc tiến Y và tài nguyên thời gian; C1→C4 giữ cùng miền hình học và bật hai loại biến thời gian. Đây là so sánh nghiệm của các lượt tìm kiếm hữu hạn; không tách hoàn toàn tác động mô hình khỏi sai số tối ưu.

- Toàn bộ 12 nghiệm Full thuộc C2/C4 đều dùng tổng hover xấp xỉ 20 s. Gain không đến từ tăng tổng thời gian vượt ngân sách mà từ phân bổ lại theo slot cùng các biến khác.
- C4 có h nhỏ nhất 0.1 s trong cả sáu nghiệm Full; h lớn nhất khoảng 2.779–2.987 s. Các slot không còn cùng hover 1 s.
- Tổng UL/tổng hover trung bình theo ba seed của C4: Full PSO 38.00%, Full IPSO 35.38%; phần còn lại dành DL. Đây là tỷ lệ tổng thời gian, không phải mọi slot có cùng tỷ lệ.
- Sáu nghiệm C4 Full dùng khoảng 5.805–6.058 kJ, dưới xa 17 kJ. Cận tổng hover 20 s đang được dùng hết; cận năng lượng chưa bị chạm trong các nghiệm này.
- C4 Full IPSO không có cặp waypoint phục vụ trùng nhau chính xác ở cả ba seed; C4 Full PSO chỉ có stay ở seed 3486784401 (ba chuyển tiếp trùng). Kết quả chưa hỗ trợ tuyên bố gain C4 chủ yếu do stay.

## 4. Độ ổn định của thuật toán

- Full IPSO có trung bình cao hơn Full PSO tại C0, C1 và C4; Full PSO cao hơn tại C2 và C3. Không có một phương pháp thắng mọi cấu hình.
- C4 Full PSO seed 3486784401 đạt 6361.96 bit/J, thấp hơn C1 cùng seed (8304.16 bit/J), dù C4 có miền tài nguyên rộng hơn. Do đó kết quả tìm kiếm chưa bảo đảm khai thác hết lợi ích của thêm biến.
- C4 Full PSO ngừng cải thiện best fitness ở vòng 361, 280 và 463 tương ứng ba seed. C4 Full IPSO vẫn cập nhật ở vòng 1000; gain trong 200 vòng cuối khoảng 0.87%, 0.90%, 1.14%. Những số liệu này gợi ý hiện tượng dừng cải thiện sớm của PSO, không phải bằng chứng đã đạt tối ưu toàn cục.
- Ba seed là ba kịch bản khác nhau, mỗi kịch bản dùng một seed thuật toán đã cấu hình. Trung bình này chưa đo riêng độ ngẫu nhiên của optimizer trên một kịch bản cố định.

## 5. C5: tồn tại nghiệm khả thi tốt hơn bộ chạy hiện tại tìm ra

- Joint PSO 0/3; Full PSO 0/3; Full IPSO 2/3. Hai nghiệm IPSO khả thi có EE 1994.54 và 2963.41 bit/J, năng lượng 10.654 và 10.297 kJ.
- Tất cả bảy nghiệm C5 không khả thi đều vi phạm q. Chỉ Full PSO seed 2026 vượt năng lượng (20.216 kJ); nhiều lượt còn nằm dưới 17 kJ nhưng thiếu dịch vụ tại một số slot.
- C5 Full IPSO seed 2026 đạt L và năng lượng 16.963 kJ, nhưng còn một user-slot chỉ đạt 371.63 bit thay vì 5000 bit. Tổng Mbit lớn không thay thế được ràng buộc q từng user-slot.
- Thử đối chiếu: giữ nguyên waypoint, BS, alpha, UL/DL của từng nghiệm C4 rồi tính lại bằng backend C5. Đã kiểm tra radio và tổng bits trùng nhau; chỉ mô hình năng lượng chuyển động thay đổi. **Cả sáu nghiệm Full C4 vẫn khả thi dưới C5.** Không thực hiện thêm bước tối ưu nào.

| Seed | Nguồn candidate C4 | Năng lượng theo C5 (kJ) | EE theo C5 (bit/J) |
|---:|---|---:|---:|
| 2026 | full_pso | 10.813 | 8,668.92 |
| 2026 | full_ipso | 10.390 | 8,736.29 |
| 608060 | full_pso | 9.983 | 7,896.82 |
| 608060 | full_ipso | 10.525 | 7,442.31 |
| 3486784401 | full_pso | 15.341 | 2,512.29 |
| 3486784401 | full_ipso | 9.352 | 5,531.67 |

Đối chiếu này cho thấy bộ tìm kiếm C5 đã bỏ sót nghiệm khả thi tốt hơn có sẵn trong dữ liệu. Không nên diễn giải 0/3 của Full PSO là C5 bất khả thi. Warm start từ C4 là bước thử tiếp có cơ sở; chưa thực hiện thêm campaign hoặc sửa optimizer trong lần đọc kết quả này.

C5 vẫn là backend quasi-steady thử nghiệm, không phải mô hình Dai đã công bố. Không dùng chênh lệch EE thô C5/C4 làm gain thuật toán vì hai mô hình năng lượng khác nhau.

## 6. Kết luận để phát triển

C4 là lựa chọn có cơ sở nhất trong bộ chạy hiện tại: trung bình EE tốt nhất ở cả hai phương pháp Full, tìm được nghiệm khả thi đủ ba kịch bản, và các biến hover/chia pha thật sự thay đổi. Tuy nhiên, thêm riêng hover (C2) hoặc chia pha (C3) chưa đem lại cải thiện nhất quán so với C1 dưới IPSO. Cần giữ phân biệt giữa lợi ích của miền tài nguyên rộng hơn và mức độ thành công của optimizer. C5 cần xử lý khả năng tìm kiếm và kiểm chứng năng lượng trước khi dùng cho kết luận nghiên cứu mạnh.

## Dữ liệu đối chiếu

- `details.csv`: 54 nghiệm, cờ ràng buộc, thiếu hụt, hover, UL/DL, năng lượng, thông tin hội tụ.
- `ee_by_preset_method.csv`: thống kê EE trên nghiệm khả thi; NaN không được tính là EE đạt yêu cầu.
- `feasibility_counts.csv`, `timing_energy.csv`: số lượt khả thi và tóm tắt thời gian/năng lượng.
- `C4_candidates_under_C5.csv`: kiểm tra cùng candidate dưới mô hình C5.
- `analysis.json`, `analysis_source.m`, `matlab_analysis.log`, `provenance.json`: số liệu có cấu trúc và bằng chứng tái lập.
