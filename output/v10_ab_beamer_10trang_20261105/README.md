# V10A/V10B: bản Beamer rút gọn đúng 10 trang

PDF `main.pdf` gồm 10 trang, không có phụ lục. Nguồn chỉnh sửa là `main.tex`
và ba bảng trong `tables/`. Theme HUST và hình vector đi kèm.

Nội dung: tổng quan; khác biệt A/B và thuật toán; phần kế thừa Drones;
EE theo L; EE theo q và tóm tắt hover; quỹ đạo IPSO A/B ở seed 2026;
quỹ đạo IPSO A/B ở seed 3486784401; tọa độ BS đủ ba seed;
khả năng cố định BS; kết luận và nguồn.

Tải ZIP lên Overleaf, chọn `main.tex` và compiler **XeLaTeX**.
Hoặc chạy XeLaTeX hai lần / `tectonic -X compile main.tex`.

`data/` giữ nguyên dữ liệu đã đối chiếu của báo cáo đầy đủ:

- `extracted_results.json`: 216 kết quả và hình học trích từ MAT.
- `ee_summary.csv`: EE khả thi theo L/q/hover, có n và median/min/max.
- `bs_default_L3_q5_h1.csv`: BS đủ ba seed và bốn phương pháp ở bộ chính.
- `bs_all_L3.csv`: toàn bộ tọa độ BS cho các cấu hình L=3 khác nhau.
- `waypoints_all_L3.csv`: tọa độ UAV cho các cấu hình L=3 khác nhau.
- `audit.csv`, `source_checksums.json`, `provenance.json`: kiểm chứng và nguồn.
- `validation.json`: kiểm tra bản PDF 10 trang hiện tại.

Hai hình chỉ chọn IPSO để thể hiện A/B rõ và giữ slide gọn. EE trong bảng
vẫn có JointPSO, Full PSO và IPSO. Baseline được nhắc ở trang 2.
BS trong bảng trang 8 gồm cả Full PSO/IPSO của A/B ở đủ ba seed.
PSO trong bảng BS là Full PSO. Z của BS1/2/3 là 20/30/25 m.

Tái dựng hai hình từ dữ liệu đính kèm bằng `python3 plot_trajectories.py`
(cần matplotlib). Không chạy lại MATLAB hoặc tối ưu.

Kết quả nguồn thuộc campaign `campaign_20261029_125559`, cùng bản đầy đủ.
Trung bình EE chỉ lấy seed khả thi. Các cấu hình lặp đã loại trùng khi tổng hợp.
Số liệu không chứng minh tối ưu toàn cục hoặc mất EE khi cố định BS.
