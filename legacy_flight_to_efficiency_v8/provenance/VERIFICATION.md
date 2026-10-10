# Kiểm tra bộ lưu trữ

Ngày: 10/10/2026.

- PASS: 462 file được bảo toàn khớp SHA-256 và nội dung nguồn.
- PASS: các Git blob khớp commit gốc; file local khớp bản gốc ở UAV.
- PASS: năm snapshot lịch sử trước V9 đã xuất nguyên vẹn.
- PASS: đủ 20 log V8 và 20 log CCPSO Python.
- PASS: 105 checkpoint/hình có tên V8 được giữ từ thí nghiệm so sánh.
- PASS: 27 tên hàm dự án tham chiếu trong 47 file MATLAB active
  có file hoặc định nghĩa local tương ứng; không gọi hook mission V10.
- PASS: không có thư mục `.git` lồng trong legacy.
- PASS: trạng thái Git của raw2, Raw0, raw1 và Joint PSO Mod giữ nguyên.
- PASS: repo mới độc lập, nhánh main, chưa commit và chưa có remote.

Đây là kiểm tra bản sao và phụ thuộc tĩnh, không phải chạy mô phỏng MATLAB
hay xác nhận tái hiện kết quả số của bài báo. Mã lịch sử/không hoàn chỉnh
được giữ nguyên, không được tự sửa trong đợt lưu trữ này.

SHA256SUMS.txt kiểm tra mọi file trong legacy trừ chính file checksum.
Các file tạo mới như README và metadata cũng có checksum; SOURCES.json
chỉ liệt kê các file được lấy từ nguồn để phân biệt với tài liệu mới.
