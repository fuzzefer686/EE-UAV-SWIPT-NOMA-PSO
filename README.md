# EE-UAV-SWIPT-NOMA-PSO

Hướng nghiên cứu được chốt ngày 10/10/2026: tối ưu hiệu quả năng lượng
(Energy Efficiency, EE) cho mạng UAV hỗ trợ SWIPT-NOMA, trên nền mô hình
Flight to Efficiency và các thuật toán PSO đã phát triển đến V8.

Repo này độc lập với `uav-swipt-noma-trajectory-optimization` (GitHub `raw2`).
Đợt khởi tạo chỉ đóng băng nền tảng cũ; chưa triển khai hàm mục tiêu EE.

## Nội dung hiện có

- [`legacy_flight_to_efficiency_v8/`](legacy_flight_to_efficiency_v8/README.md):
  bài báo gốc, mã nền, V4–V8, các thuật toán cũ, log và kết quả V8.
- [`docs/RESEARCH_DIRECTION_EE.md`](docs/RESEARCH_DIRECTION_EE.md): quyết định
  chuyển hướng và phạm vi bước phát triển tiếp theo.
- [`GIT_GUIDE.md`](GIT_GUIDE.md): commit baseline, tạo repo GitHub và nhánh EE.

Trong bộ lưu trữ, `matlab_v8/` là pipeline V8 trước khi các hook đánh giá
mission của V10 được thêm vào. Các mốc lịch sử và nguồn từng file được giữ
riêng để đối chiếu. Không thêm toàn bộ thư mục legacy vào MATLAB path vì
các phiên bản có nhiều hàm trùng tên.

## Bước tiếp theo

Commit baseline trước. Sau đó tạo nhánh `feature/ee-optimization` và xây dựng
mã EE bên ngoài thư mục legacy. Dùng Joint PSO, Full PSO và Full IPSO làm
các thuật toán so sánh chính với cùng mô hình, seed và ngân sách đánh giá.
