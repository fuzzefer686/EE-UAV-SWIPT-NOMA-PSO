# Quyết định chuyển hướng sang tối ưu EE

Ngày chốt hướng EE: 10/10/2026. Phạm vi được người dùng xác nhận lại ngày 13/10/2026.

## Mục tiêu

Hướng phát triển chính là tối ưu Energy Efficiency (EE), đơn vị bit/J,
trên nền UAV-SWIPT-NOMA của Flight to Efficiency và các thuật toán đến V8.
Chỉ xét mô hình và thuật toán V8 trở xuống. Các hướng V9 và V10 lịch sử nằm ngoài
phạm vi phát triển và so sánh: không dùng mô hình, code, công thức, kết quả
hoặc benchmark của hai phiên bản đó. Không tự thêm DTS/tau tối ưu, ICIT,
cache, finite-data hay ràng buộc nhiệm vụ từ hướng V9/V10. Dữ liệu lịch sử
được giữ để lưu trữ, không phải nền tảng của hướng EE hiện hành.

Bài báo gốc tối ưu min-rate qua vị trí/quỹ đạo UAV với PSO, có SWIPT để
cấp năng lượng cho truyền downlink. V8 mở rộng các biến tối ưu và fitness
dựa trên rate. Mã V8 nằm ở scripts/src; bài báo và mã gốc ở reference.
Tag baseline-v8-clean giữ mốc đối chiếu khi xây dựng mục tiêu EE.

## Nền tảng giữ lại

- Mô hình hình học BS–UAV–GU, suy hao khoảng cách và fading Rician.
- Uplink/downlink NOMA, SIC, phân bổ công suất và thu năng lượng SWIPT.
- Điểm đầu/cuối UAV, giới hạn vùng bay và chuyển động theo bước.
- Các phương án phân bổ công suất và baseline đường thẳng của bài gốc.
- Joint PSO, Full PSO, Full IPSO và alpha polishing. Pipeline main chỉ giữ
  ba thuật toán này cùng đường bay thẳng làm đối chứng.

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
4. Tạo evaluator EE và scenario dùng chung trong scripts/src trên nhánh EE.
5. So sánh Joint PSO, Full PSO và Full IPSO với cùng seed, ràng buộc và
   ngân sách đánh giá; báo EE, rate, fairness, năng lượng và tính khả thi.

Các bước 3–5 chưa được triển khai trong đợt khởi tạo repo này.

## Thử nghiệm EE RF tạm thời — 14/10/2026

Theo yêu cầu mới của người dùng, bản `scripts/maincodeV9_EE.m` phát triển
trực tiếp từ V8 có chế độ `objectiveMode = 'ee-rf'`: mỗi đoạn giữa hai waypoint mất 1 s, chia đều
0.5 s UL và 0.5 s DL; tạm bỏ giới hạn bước chuyển động bằng dxMax/dzMax=Inf.
Giữ biên vùng bay và endpoints. 21 waypoint tương ứng 20 slot.

Tạm lấy kênh tại điểm đầu mỗi đoạn, giả định UL cung cấp đủ dữ liệu, tính
bit từng user bằng rate DL nhân 0.5 s. Fitness dùng tổng bit chia tổng năng
lượng RF phát của UAV (`pt * 0.5 s`). Alpha polishing cũng chọn theo EE.
Entry point `maincodev8nUser.m` giữ nguyên để chạy baseline V8 đối chiếu.
Tên V9_EE mới là tên người dùng yêu cầu, không kế thừa mô hình V9 lịch sử.

Đây là bước thử nghiệm công thức EE và hạch toán slot; chưa phải EE đầy đủ
gồm năng lượng bay, mạch, PA losses hay điện từ pin. Mục tiêu dài hạn EE
của UAV gồm năng lượng bay và truyền thông vẫn giữ nguyên. Chưa thêm QoS
hay giới hạn dữ liệu forwarding hai chặng. Xem README và
`src/evaluators/addRFSlotMetrics.m` để theo dõi phần thay đổi nhỏ này.
Người dùng yêu cầu không chạy MATLAB trong lượt triển khai này. Chỉ kiểm
tra tĩnh; chưa có kết quả mô phỏng hay xác nhận test MATLAB đã chạy thành công.
