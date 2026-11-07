# Báo cáo sơ bộ: mô hình năng lượng UAV và V10A–V10B

Bộ slide Beamer 15 trang theo theme HUST (16:9, màu xanh), tập trung vào
mô hình, ràng buộc và thiết kế V10; không trình bày kết quả sơ bộ.

## Cấu trúc 15 trang

1. Trang bìa
2. Mục tiêu và phạm vi
3. Mô hình bay của bài báo Drones
4. Công suất bay: ba thành phần, dạng \(P=P_1+P_2+P_3\)
5. Hệ số và các mốc công suất, năng lượng tính được
6. Mô hình V9: tọa độ X/Y/Z và slot 1 giây
7. Xung đột với mô hình bay của bài báo
8. Ràng buộc mô hình khi tích hợp
9. Vấn đề của V9 khi áp mô hình bay
10. Kiến trúc V10 so với V9 và mô hình mô phỏng
11. V10A và V10B: cấu trúc bay, hai bảng Y theo slot
12. Chất lượng dịch vụ: \(L\), \(q\), constraint và ba cờ QoS
13. Tác động của năng lượng bay: gạch đầu dòng và công thức
14. Tổng hợp V10A và V10B: năng lượng, EE, cấu trúc bay, QoS
15. Cấu hình chạy V10 hiện tại: quick, full và tham số cần tinh chỉnh

## Tệp

```text
V10_energy_report.tex      nguồn LaTeX
V10_energy_report.pdf      bản đã build (15 trang)
beamerthemeHUST.sty        theme HUST
images/                    ảnh nền HUST của theme
```

## Build

Không dùng `pdflatex` vì file dùng `fontspec` cho tiếng Việt. Dùng:

```bash
tectonic -X compile V10_energy_report.tex
```

hoặc chạy `xelatex` hai lần:

```bash
xelatex V10_energy_report.tex
xelatex V10_energy_report.tex
```

## Chỉnh sửa nhanh

- Tên người thực hiện: sửa `\author{...}`.
- Tiêu đề/subtitle: sửa `\title{...}`, `\subtitle{...}`.
- Nội dung: các khối `\begin{frame}{...}` theo thứ tự 15 trang.
- Màu nhấn: `hustprimary` (xanh HUST), `hred` (đỏ), `hgreen` (xanh lá).

## Nguồn nội dung

- Bài báo Drones 2026, 10, 238: mô hình lực đẩy và các hệ số.
- Tài liệu đối chiếu mô hình năng lượng với mã V8/V9 trong `docs/`.
- Hướng dẫn V10A/V10B và các ghi chú QoS trong `docs/`.

Các số công suất, năng lượng trên slide 5 được tính lại từ hệ số của bài báo;
không phải kết quả tối ưu PSO. Slide 15 dùng cấu hình mặc định và hai profile
quick/full của V10; chưa chạy lại MATLAB trong lượt này.
