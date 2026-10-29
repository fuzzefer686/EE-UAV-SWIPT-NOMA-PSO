# Figure folders — seed 2026

Đối chiếu ngày 2026-10-22 bằng PNG và dữ liệu số trong FIG. Figure 11 là
bit từng user theo vòng; Figure 13 là alpha trung bình, không phải dữ liệu bit.
Với thư mục thiếu Figure 11, tổng bit được tính từ Figure 4:
`0.5 * sum(rate(1:20))`, bỏ waypoint đến cuối cùng.

| Tên cũ | Tên mới | L (Mbit/user) |
|---|---|---:|
| `run_L1e6` | [seed2026_L1Mbit](seed2026_L1Mbit/) | 1 |
| `run_L1p5e6` | [seed2026_L1p5Mbit](seed2026_L1p5Mbit/) | 1.5 |
| `run_L2e6` | [seed2026_L2Mbit](seed2026_L2Mbit/) | 2 |
| `run_L3e6` | [seed2026_L3Mbit](seed2026_L3Mbit/) | 3 |
| `run_L4e6` | [seed2026_L3Mbit](seed2026_L3Mbit/) | 3 |
| `run_20261022_135226_179` | [seed2026_L4Mbit](seed2026_L4Mbit/) | 4 |
| `run_20261022_140052_180` | [seed2026_L4p2Mbit](seed2026_L4p2Mbit/) | 4.2 |

Hai bộ L=3 đã gộp vào `seed2026_L3Mbit`, có đủ các Figure 1, 2, 4–16.
Các file Figure 6–7 từ bộ bổ sung được giữ với hậu tố `_diagnostics`
vì có nội dung nhị phân khác bản đã có; không ghi đè hay bỏ bản nào.

Mức L được suy ra từ các đường bit sát ngưỡng, không đọc trực tiếp từ sim.
Riêng L=1.5 được giữ theo tên cũ: mức bit thấp nhất sau polishing khoảng
1.511–1.513 Mbit, phù hợp với L=1.5 nhưng không đủ để xác định duy nhất L.
Seed 2026 theo thông tin người dùng, được đối chiếu tọa độ user trong các
Figure 1 có sẵn với log baseline seed 2026.

`folder_labels.json` giữ tên cũ/mới, bằng chứng số và SHA-256 của từng file.
Không thay đổi nội dung hình, không xóa file và không chạy lại tối ưu.
