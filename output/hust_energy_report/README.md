# Báo cáo sơ bộ năng lượng UAV — HUST Beamer

Nguồn chính: `main.tex`. PDF: `main.pdf`. Template HUST xanh, 16:9 từ beamer.zip do người dùng cung cấp; giữ nguyên theme và ảnh nền.

## Mở trên Overleaf
Tải ZIP nguồn lên bằng **New Project → Upload Project**. Chọn `main.tex` làm Main document, compiler **XeLaTeX**. Không dùng pdfLaTeX vì tài liệu dùng fontspec/unicode-math cho tiếng Việt.

Biên dịch local: `tectonic main.tex`, hoặc chạy `xelatex main.tex` hai lần. Font Latin Modern thuộc TeX Live.

## Nội dung
Mô hình Drones Eq.(10)–(12), khác biệt với V9, V10A/V10B, ledger fly/hover/RF, QoS và kết quả sơ bộ V10A. Hai bảng số liệu thuộc hai cấu hình riêng: các run 28/10 chưa bật QoS user-slot; run 29/10 dùng 10 kbit/user/slot. Mặc định cấu hình hiện tại là 5 kbit/user/slot. Chưa có số liệu V10B trong nguồn đã kiểm tra.

Tên người trình bày để trống vì chưa được cung cấp; sửa `\author{}` và thêm `\insertauthor` trên trang bìa nếu muốn. Không kế thừa danh sách tác giả hoặc chủ đề DGPPO của mẫu.

Nguồn: docs/drones-10-00238.pdf; docs/root_paper.pdf; docs/DRONES_ENERGY_CODE_REVIEW_2026-10-28.md; docs/V10_AB_GUIDE.md; docs/V10_SLOT_QOS_AND_FIXES_2026-10-28.md; src/config/v10Config.m; src/models/dronePropulsionPower.m; src/evaluators/addV10EnergyMetrics.m; summary V10A tại results/v10/V10A.

Bản báo cáo tổng hợp tài liệu và kết quả đã lưu; quá trình soạn slide không chạy lại tối ưu MATLAB.

## Nguồn số liệu và nhịp trình bày

28 trang gồm bìa, 4 trang chuyển phần, tài liệu tham khảo và trang kết. Khoảng 21 trang nội dung cho 15–20 phút: bối cảnh 1 phút; năng lượng 5 phút; V9 5 phút; V10A/B 4 phút; số liệu và thảo luận 3 phút.

Bảng lịch sử: results/v10/V10A/seed2026_L1Mbit_20261028_223035_240/summary.txt; seed2026_L2Mbit_20261028_224640_021/summary.txt; seed2026_L3Mbit_20261028_225958_481/summary.txt.

Bảng QoS 10 kbit: results/v10/V10A/seed2026_L3Mbit_20261029_014602_883/summary.txt.

Phân tích V9: docs/EE_RF_DIAGNOSIS_SEED2026.md.
