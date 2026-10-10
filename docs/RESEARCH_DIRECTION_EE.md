# Quyết định chuyển hướng sang tối ưu EE

Ngày chốt: 10/10/2026.

## Mục tiêu

Hướng phát triển chính là tối ưu Energy Efficiency (EE), đơn vị bit/J,
trên nền UAV-SWIPT-NOMA của Flight to Efficiency và các thuật toán đến V8.
Việc phát triển thêm DTS/cache/finite-data theo hướng V9/V10 trước đây
không còn là mục tiêu chính của repo mới này.

Bài báo gốc tối ưu min-rate qua vị trí/quỹ đạo UAV với PSO, có SWIPT để
cấp năng lượng cho truyền downlink. V8 mở rộng các biến tối ưu và fitness
dựa trên rate. Hai nền tảng này được đóng băng trong thư mục legacy để
đối chiếu khi xây dựng mục tiêu EE.

## Nền tảng giữ lại

- Mô hình hình học BS–UAV–GU, suy hao khoảng cách và fading Rician.
- Uplink/downlink NOMA, SIC, phân bổ công suất và thu năng lượng SWIPT.
- Điểm đầu/cuối UAV, giới hạn vùng bay và chuyển động theo bước.
- Các phương án phân bổ công suất và baseline đường thẳng của bài gốc.
- PSO, Joint PSO, Full PSO, Full IPSO; các biến thể GA/FA/DE và CCPSO
  được lưu để tham khảo, không mặc định là thuật toán của bài báo gốc.

## Những nội dung cần xác định khi triển khai EE

EE phải dùng lượng dữ liệu và năng lượng trên cùng một khoảng thời gian:

```text
EE = tổng số bit được phục vụ / năng lượng tiêu thụ trong khoảng đánh giá
```

Đây là định nghĩa định hướng, chưa phải công thức evaluator đã chốt.
Trước khi viết evaluator cần xác định rõ EE của UAV hay của toàn mạng,
cách tính rate qua các pha truyền, năng lượng truyền, hiệu suất khuếch đại,
công suất mạch và phạm vi tính năng lượng bay. Năng lượng thu từ BS phải
được hạch toán theo phạm vi đã chọn, tránh tính trùng năng lượng.

Rate tối thiểu, fairness và EH tiếp tục được báo cáo để diễn giải nghiệm.
Cách dùng chúng làm ràng buộc hay thành phần phụ cần được nêu rõ trong mô
hình EE. Không lấy fitness V8 chia trực tiếp cho EH để gọi là EE.

## Trình tự phát triển

1. Commit bộ baseline được lưu nguyên vẹn.
2. Tạo nhánh `feature/ee-optimization`.
3. Chốt công thức EE, tham số năng lượng và đơn vị đo.
4. Tạo evaluator EE và scenario dùng chung bên ngoài thư mục legacy.
5. So sánh Joint PSO, Full PSO và Full IPSO với cùng seed, ràng buộc và
   ngân sách đánh giá; báo EE, rate, fairness, năng lượng và tính khả thi.

Các bước 3–5 chưa được triển khai trong đợt khởi tạo repo này.
