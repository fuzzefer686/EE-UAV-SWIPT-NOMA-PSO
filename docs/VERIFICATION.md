# Kiểm tra baseline rút gọn

Ngày: 10/10/2026.

- 41 file được giữ từ nguồn đều khớp SHA-256; không sửa công thức V8.
- Pipeline gồm Joint PSO, Full PSO, Full IPSO và alpha polishing.
- Không có mã hoặc entry point CCPSO trong scripts/src.
- 12 file MATLAB active được kiểm tra tên hàm dự án tham chiếu;
  đủ 10 tên hàm cần thiết trong pipeline.
- Giữ nguyên 20 log V8; bỏ checkpoint, bản sao và log thử nghiệm phụ.
- setup_project chỉ thêm scripts/src, không đưa mã gốc tham khảo vào path.
- Bản lưu đầy đủ vẫn ở tag baseline-flight-to-efficiency-v8.

Kiểm tra này xác nhận tính toàn vẹn và phụ thuộc tĩnh, chưa chạy mô phỏng
MATLAB hoặc tái hiện kết quả số.

Kiểm tra checksum từ gốc repo:

```bash
shasum -a 256 -c docs/BASELINE_SHA256SUMS.txt
```
