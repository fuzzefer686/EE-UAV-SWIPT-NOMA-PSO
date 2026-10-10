# UAV SWIPT-NOMA — V8 và V9 DTS

Repository MATLAB này giữ pipeline V8 làm mốc và có bản V9 riêng cho Dynamic Time Splitting (DTS). V9 giữ cấu hình scenario, mô hình kênh, NOMA, fitness, PSO/IPSO, alpha polishing và biểu đồ của V8. Thay đổi mô hình duy nhất là thêm `tau(t)` cho mỗi slot cùng các đại lượng phụ thuộc trực tiếp vào nó.

## Chạy V8

Mở MATLAB tại thư mục này, sau đó chạy:

```matlab
setup_project;
run('scripts/main/maincodev8nUser.m');
```

Để chạy bản V8 có Cooperative Co-evolutionary PSO:

```matlab
setup_project;
run('scripts/main/maincodeV8_CCPSO.m');
```

Hai script mặc định dùng bài toán 300 × 300 × 60 m, 5 users, 3 BS và 21 vị trí bay. `maincodev8nUser.m` có thể chạy lâu với cấu hình đầy đủ; hãy chỉnh số hạt và số vòng trong script khi kiểm tra nhanh.

## Chạy V9

Kiểm thử nhỏ trước:

```matlab
setup_project;
test_v9_rewrite;
```

Chạy pipeline V9 giống V8, gồm Joint PSO, Full PSO, Full IPSO và alpha polishing:

```matlab
run('scripts/main/maincodeV9_DTS.m');
```

Script V9 hiện chạy Joint PSO 120 hạt × 750 vòng; Full PSO và Full IPSO 400 hạt × 750 vòng; sau đó polish alpha với cùng cách chọn ứng viên. Bước polish chỉ sửa alpha, giữ nguyên quỹ đạo, vị trí BS và tau.

Để chạy 20 lần V9 và lưu từng log TXT cạnh các log V8, dùng:

```matlab
setup_project;
run_v9_20_times;
```

Script dùng đúng 20 seed của `result_v9/RESULT_1_V8.txt` đến `RESULT_20_V8.txt` và tạo `result_v9/RESULT_1_V9.txt` đến `RESULT_20_V9.txt`. Có thể chạy một đoạn, ví dụ `run_v9_20_times(1, 2)`, rồi tiếp tục `run_v9_20_times(3, 20)`. File đã có sẽ không bị ghi đè. Nếu một run lỗi, log chạy dở nằm trong file `.txt.partial`; hãy kiểm tra hoặc đổi tên file này trước khi chạy lại run đó. Cả ba bộ tối ưu V9 chạy 750 vòng mỗi run. Các log V8 cũ dùng 1000 vòng, riêng Joint ở run 1 dùng 450 vòng; cần tính đến khác biệt ngân sách này khi so sánh kết quả.

Benchmark cặp V8/V9 với cùng scenario và cùng số hạt/vòng:

```matlab
results = benchmark_v8_v9_fair(2026);
```

Lệnh trên dùng ngân sách thử nhanh (10 hạt × 5 vòng, 10 ứng viên polish/slot). Với benchmark chính thức, truyền `opts` như ví dụ ở đầu file `scripts/benchmarks/benchmark_v8_v9_fair.m`. Hàm trả về bảng trong MATLAB và không tự ghi PDF/TXT/CSV. Số lần evaluator được profiler đếm; thời gian đo gồm overhead của profiler ở cả V8 và V9. IPSO có thể có số lần đánh giá đột biến khác nhau do particle V9 dài hơn; cần xem cột `evaluations` khi so sánh.

### Các đại lượng phụ thuộc tau

- `phaseRate = B*log2(1+SINR)` là tốc độ khi đang truyền downlink [bit/s]. `spectralRate` được giữ như tên tương thích cho cùng giá trị này.
- `achRate = tau * phaseRate` là tốc độ trung bình trên toàn slot, kể cả pha EH [bit/s]. Fitness V9 dùng trực tiếp giá trị này, không có `tauRef`.
- `physicalAverageRate = achRate` là tên tương thích cho cùng rate vật lý.
- `bitsPerSlot = Tslot * achRate` là lượng bit có thể truyền theo mô hình khi luôn có dữ liệu.

Từ 2026-09-29, rate V9 xuất phát từ `bitsPerSlot/Tslot`, thay cho chuẩn hóa theo nửa slot. Cấu trúc fitness vẫn là min-rate + trọng số mean-min-rate - fairness penalty - các penalty khác; các thành phần rate đều dùng rate trung bình trên toàn slot. Đây là điểm tổng hợp dựa trên rate, chưa phải EE.

Rate gốc của V8 được tính trong pha downlink; V8 giả định uplink và downlink dài bằng nhau. Để so sánh, benchmark đánh giá lại nghiệm V8 bằng evaluator V9 với lịch chia đều hai pha và báo cùng rate/fitness vật lý. Baseline thẳng trong script V9 cũng được chấm bằng evaluator V9 với alpha theo kênh. Việc chia đều là giả định lịch truyền của baseline, không phải chuẩn hóa rate V9. Không so trực tiếp fitness V9 mới với fitness trong log V8/V9 cũ. Với nghiệm khả thi và `lambdaSmooth = 0`, fitness V9 mới bằng một nửa fitness V9 cũ tại cùng nghiệm; đó là đổi thang đo, không phải mất hiệu năng.

Mô hình cache và ràng buộc data demand trong báo cáo chưa được đưa vào pipeline này để giữ đúng yêu cầu V9 chỉ thêm tau. `Tslot = 1e-6` giữ nguyên từ V8; không diễn giải `bitsPerSlot` như dữ liệu của một chuyến bay thực nếu chưa chọn thời lượng slot vật lý.

## Cấu trúc mã

- `scripts/main/`: entry point V8/V9 và hàm tạo scenario V9 cùng phân phối với V8.
- `scripts/benchmarks/`: benchmark V8/V9 và kiểm thử V9.
- `src/evaluators/`: giải mã particle và tính fitness V8/V9.
- `src/models/`: kênh, SWIPT, NOMA và tau.
- `src/optimizers/pso/`, `src/optimizers/ipso/`, `src/optimizers/V9/`: các optimizer tương ứng.
- `src/optimizers/postprocessing/`: alpha polishing V8 và bản V9 giữ nguyên tau.
- `setup_project.m`: thêm các thư mục mã đang dùng vào MATLAB path.

V8 dùng tỷ lệ thu năng lượng và truyền downlink cố định, tương đương `tau = 0.5`. Hàm mục tiêu dùng min-rate của các vị trí nội bộ, mean-rate, Jain fairness và các penalty đã có. Vị trí đầu/cuối được giữ cố định.

Các log TXT V8 đã được phục hồi trong `result_v9/`; log V9 mới được tạo bằng `run_v9_20_times`. Kế hoạch và nguồn công thức V9 nằm trong `docs/`.
