# Báo cáo kết quả V10A và V10B

Báo cáo tiếng Việt, Beamer 16:9 theo theme HUST có sẵn trong dự án.
Ngày tổng hợp: 05/11/2026. PDF gồm 37 trang, trong đó 8 trang phụ lục.

## Xem và chỉnh sửa

- `main.pdf`: báo cáo đã biên dịch.
- `main.tex`: nội dung slide, công thức, nhận xét; chỉnh trực tiếp tệp này.
- `tables/*.tex`: các bảng EE và tọa độ, có thể sửa trực tiếp bằng LaTeX.
- `beamerthemeHUST.sty` và `images/`: theme và ảnh nền cần giữ cùng nguồn.
- `figures/*.pdf`: hình vector dùng trong slide, có bản PNG để xem nhanh.
- `prepare_report.py`: dựng lại hình/bảng từ `data/extracted_results.json`.

Tải toàn bộ ZIP lên Overleaf, chọn `main.tex` và compiler **XeLaTeX**.
Hoặc biên dịch trên máy:

```sh
xelatex main.tex
xelatex main.tex
```

Trên máy có Tectonic:

```sh
tectonic -X compile main.tex
```

Để dựng lại hình/bảng (sẽ ghi lại các tệp trong `tables/` và `figures/`):

```sh
python3 prepare_report.py
```

Lệnh này cần numpy và matplotlib. Không cần MATLAB, không chạy PSO.
Chỉ dùng `--extract` nếu đặt bộ báo cáo tại đường dẫn gốc trong dự án và
muốn trích lại 54 MAT; tùy chọn đó cần thêm h5py.

## Nội dung và vị trí

- Trang 2–9: kết quả chính, phạm vi, so sánh A/B, kế thừa Drones, mô hình và phương pháp.
- Trang 10–13: EE theo L và q, trung bình trên seed khả thi kèm số nghiệm.
- Trang 14–15: hover và đánh đổi EE/fairness.
- Trang 16–22: chú giải và sáu hình quỹ đạo, đủ A/B × ba seed.
- Trang 23–27: miền BS, tọa độ cấu hình chính, phân bố mở rộng và ứng viên cố định.
- Trang 28–29: giới hạn và nguồn.
- Trang 30–33: EE từng seed theo L và q, đánh dấu nghiệm chưa đạt QoS.
- Trang 34–37: toàn bộ tọa độ BS của các nghiệm Full ở L=3 Mbit.

## Dữ liệu đính kèm

- `data/ee_summary.csv`: mean, median, min/max EE khả thi cho từng sweep.
- `data/bs_default_L3_q5_h1.csv`: tọa độ x/y/z BS cho ba seed tại L=3 Mbit,
  q=5 kbit/user/slot, hover 1 s; có đủ bốn phương pháp.
- `data/bs_all_L3.csv`: mọi cấu hình khác nhau tại L=3 Mbit,
  120 kết quả phương pháp × 3 BS = 360 dòng.
- `data/waypoints_all_L3.csv`: 120 kết quả phương pháp × 21 waypoint,
  2.520 dòng tọa độ UAV, kèm seed, q, hover và trạng thái feasibility.
- `data/bs_boundary_summary.json`: số nghiệm tại tọa độ biên, tolerance 1e-3 m.
- `data/paired_A_B.csv`: so sánh A/B ghép đúng seed và bộ L/q/hover,
  chỉ các cặp cả hai khả thi.
- `data/extracted_results.json`: dữ liệu số và hình học trích từ MAT.
- `data/audit.csv`: 216 dòng kiểm tra MAT, cấu hình và các đẳng thức năng lượng/EE/quãng đường.
- `data/source_checksums.json`: SHA-256 của 54 MAT gốc.
- `data/provenance.json`: phạm vi, cách loại trùng và kiểm chứng bộ báo cáo.

Bảng và hình dùng dấu chấm thập phân; phần nhận xét tiếng Việt dùng dấu phẩy.
CSV giữ đầy đủ độ chính xác. Tọa độ trong bảng LaTeX làm tròn hai chữ số.

## Cách hiểu kết quả

Nguồn chính là campaign `campaign_20261029_125559`: 54 run / 216 kết quả.
Loại trùng bằng (variant, scenario seed, L, q, hover, algorithm) còn
42 run cấu hình khác nhau / 168 kết quả. Các nhãn L=3, q=5 và hover=1
của ba sweep trùng tham số và kết quả, không phải lặp độc lập.

Mỗi sweep chỉ thay một tham số. Không có full factorial L × q × hover.
EE Full PSO/IPSO là sau polishing. EE JointPSO là kết quả cuối PSO.
Trung bình chỉ lấy nghiệm khả thi và ghi n/3. Các EE vi phạm trong phụ lục
chỉ để chẩn đoán, không dùng tính gain hợp lệ.

Ba seed là seed scenario/user/fading; algorithm seed giữ nguyên 151459287.
Kết quả không chứng minh tối ưu toàn cục hay độ ổn định qua nhiều khởi tạo.
Không chạy lại MATLAB, không thay đổi solver hoặc vị trí BS trong lượt này.

Ứng viên cố định BS được suy ra từ tần suất tọa độ tìm được trong miền ±50 m.
Chưa đo mất EE khi cố định. Ở bộ chính, BS3=(250,50,25) m trong 12/12
nghiệm Full. Ở mọi bộ L=3, chỉ 50/60 nghiệm Full có cùng vị trí đó,
trong đó 49/59 nghiệm khả thi; vì vậy không kết luận có thể cố định
toàn bộ BS3 cho mọi q/hover/seed.

Nguồn Drones: Zhang et al., *Trajectory and Power Control for Sustainable
UAV-Assisted NOMA-Enabled Backscattering IoT*, Drones 2026, 10, 238,
https://doi.org/10.3390/drones10040238. V10 kế thừa mô hình propulsion và
bổ sung tải động cơ hover; không tái hiện toàn bộ hệ thống BackCom của bài.
