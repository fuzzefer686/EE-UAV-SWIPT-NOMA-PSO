# V10C — bản thử nghiệm PSO/IPSO chạy tối ưu

## Chạy trọn bộ đúng cấu hình đã yêu cầu

Tại thư mục gốc dự án, chạy trong MATLAB:

```matlab
setup_project;
maincodeV10CCampaign;
```

Script `scripts/maincodeV10CCampaign.m` đã đặt C0–C5, ba seed 2026/608060/3486784401, L=3 Mbit/user, q=5 kbit/user/slot, ba thuật toán, 120 particle và 1000 vòng. Hàm comparison ghi checkpoint sau mỗi tổ hợp. C5 được bật rõ ràng là mô hình thử nghiệm; không gọi nó là mô hình Dai.

## Chạy một cấu hình

Từ thư mục gốc dự án, trong MATLAB:

```matlab
setup_project;
cfg = v10cConfig('C4','quick');
v10c = runV10C(cfg);
```

Hoặc chạy `scripts/maincodeV10C_EE.m`. Mặc định chương trình thực hiện **Joint PSO (BS cố định), Full PSO và Full IPSO (tối ưu BS)**, tìm nghiệm, lưu MAT/summary và vẽ đồ thị. Không còn dừng ở khởi tạo.

| Profile | Particle | Iteration | Ý nghĩa |
|---|---:|---:|---|
| smoke | 4 | 3 | Kiểm tra chạy và cấu trúc output, không đánh giá chất lượng tối ưu |
| trial | 20 | 100 | Bộ chạy thử C0–C5 trên ba seed |
| quick | 40 | 300 | Bản thử ý tưởng mặc định |
| full | 120 | 1000 | Ngân sách lớn hơn; vẫn không bảo đảm tối ưu toàn cục |

Đổi nhanh: `cfg=v10cConfig('C2','quick')`. Chỉ chạy một thuật toán: `cfg.execution.algorithms={'FULL_PSO'}`. Đổi ngân sách: `cfg.search.numParticles=80; cfg.search.maxIter=500;`. Tắt ghi file/vẽ: `cfg.output.saveResults=false; cfg.output.makePlots=false;`.

## Các cấu hình

| Preset | Quy tắc Y | Hover | Chia UL/DL | Năng lượng chuyển động | Chiều particle |
|---|---|---|---|---|---:|
| C0 | Tiến >=1 m/chặng | 1 s | 50/50 | Zhang bay đều | 144 |
| C1 | Một chiều, cho phép stay | 1 s | 50/50 | Như C0 | 144 |
| C2 | Như C1 | Biến thiên | 50/50 | Như C0 | 164 |
| C3 | Như C1 | 1 s | Biến thiên | Như C0 | 164 |
| **C4** | Như C1 | Biến thiên | Biến thiên | Như C0 | 184 |
| C5 | Như C1 | Biến thiên | Biến thiên | Tăng/giảm tốc quasi-steady thử nghiệm | 184 |

Particle Full PSO/IPSO chứa 19 X + 19 Y + 6 tọa độ BS + 100 trọng số NOMA. Joint PSO giữ BS cố định nên ít hơn 6 chiều: C0/C1=138, C2/C3=158, C4/C5=178. Mỗi loại thời gian biến thiên thêm 20 biến. Không có hàng alpha cho arrival.

**Bản này là PSO/IPSO toàn biến làm mốc thử nghiệm**, chưa phải thuật toán lai PSO hình học + SCA + Dinkelbach đã thảo luận. Thiết kế 44 chiều chỉ áp dụng cho khối hình học của thuật toán lai tương lai. Bộ xuất hệ số `v10cTimeBlockData` vẫn được giữ để tích hợp bộ giải thời gian sau này.

C0 có cùng mô hình/ràng buộc chính với V10B, nhưng **không phải bản sao thuật toán hoặc quỹ đạo V10B**: encoding chuẩn hóa, số biến và search operators khác. Cùng input vật lý thì evaluator phải tương đương; không kỳ vọng cùng seed sẽ tạo cùng nghiệm tối ưu.

## Mặc định mô phỏng

- 21 waypoint, 20 slot phục vụ; điểm đến cuối không hover/phát RF.
- 5 user, 3 BS; H=30 m; x trong [75,225] m, y từ 300 xuống 0 m.
- Seed kịch bản 2026; L=3 Mbit/user; q=5 kbit/user/slot; tổng tải UAV <=17000 J.
- Hover biến thiên trong [0.1,3] s, tổng <=20 s. Tỷ lệ UL/h biến thiên trong [0.05,0.95]. Đây là các giới hạn thí nghiệm, không phải thông số phần cứng đã đo.
- Mô hình kênh, radio, năng lượng Zhang bay đều và công suất hover kế thừa V10. UL vẫn được giả sử cấp đủ dữ liệu, chưa có ràng buộc relay hai chặng.

## Tối ưu diễn ra thế nào?

PSO cập nhật cả hình học, alpha và thời gian được bật. Particle được chuẩn hóa về [0,1]; repair giữ endpoints, miền BS/UAV, thứ tự Y, tổng hover. Alpha được chuẩn hóa rồi sắp theo kênh yếu đến mạnh tại mỗi vị trí mới, sau đó gán về User ID vật lý. `evaluateV10CCandidate` vẫn là API đánh giá không tự sửa candidate.

Có operator đề xuất stay chính xác: sao chép vị trí của slot trước cho một nhóm slot liên tiếp. Mỗi chuyển động khác 0 dù nhỏ vẫn được tính; không làm tròn khoảng cách để miễn phí bay. Operator không áp dụng cho C0 vì C0 bắt buộc tiến ít nhất 1 m.

IPSO dùng inertia giảm dần và mutation tăng khi bị stall. Mutation thay thế đề xuất trước khi đánh giá, không cộng thêm lượt đánh giá. Mỗi thuật toán dùng đúng `numParticles*(maxIter+1)` lần đánh giá, bắt đầu từ cùng seed thuật toán và cùng baseline. Các thuật toán có số chiều khác nhau nên cùng seed không tạo các ma trận ngẫu nhiên giống hệt nhau. Stay operator dùng cho cả PSO và IPSO.

Xếp hạng ưu tiên tính khả thi: mọi nghiệm đủ ràng buộc thắng nghiệm thiếu dữ liệu/vượt năng lượng. Khi chưa khả thi, giảm thiếu hụt chuẩn hóa; sau khi khả thi, tối đa EE. Best-so-far được giữ lại; không báo thiếu hụt âm như EE âm. Nếu chưa tìm được nghiệm khả thi, output vẫn chứa nghiệm ít vi phạm nhất và ghi rõ `feasible=false`; điều đó không chứng minh bài toán bất khả thi.

Giá trị `isOptimized=true` có nghĩa một quá trình search đã thực hiện; `optimalityGuaranteed=false` nói rõ không chứng minh nghiệm toàn cục.

## Slot, stay và thời gian

Candidate có `waypoints` (21x2), `bsXY` (3x2), `alpha` (20x5 theo User ID), `uplinkTime` và `downlinkTime` (20x1).

Slot t là UL/EH rồi DL NOMA tại waypoint t, sau đó bay đến t+1. Hai slot trùng vị trí vẫn có các chu kỳ UL/DL và QoS riêng, nhưng là một lần lưu lại vật lý. q là bit/user/slot, không phải bit/s. Giữ 20 slot để không thay đổi yêu cầu dịch vụ ngầm bằng cách chia nhỏ lịch.

    EH_t = eta * phi * P_received,t * UL_t
    P_RF,t = EH_t / DL_t
    D_t,n = DL_t * R_t,n
    E_RF,t = EH_t
    E_hover = P_Zhang(0) * sum(UL+DL)
    E_total = E_move + E_hover + E_RF
    EE = totalBits / E_total

Pin lý tưởng cấp move+hover; EH cấp RF. Không trừ EH thêm lần nữa. EE trên chưa bao gồm điện năng BS, mạch và tổn hao PA.

## Output và đồ thị

Mỗi lần chạy tạo thư mục duy nhất dưới `results/v10c/Cx/`, có:

- `results.mat`: cấu hình, kịch bản, baseline ban đầu, candidate/result của từng PSO/IPSO, history và số lần đánh giá.
- `summary.txt`: EE, từng cờ khả thi, năng lượng, thời gian, tọa độ và UL/DL từng slot.
- `diagnostics.fig`, `diagnostics.png`: quỹ đạo, hội tụ EE khả thi, score, thời gian, bit/user và breakdown năng lượng.

`v10c.searches.joint_pso`, `v10c.searches.full_pso` và `v10c.searches.full_ipso` lưu riêng kết quả. `v10c.candidate/result` là lựa chọn tốt hơn theo feasibility-first, không chỉ EE chẩn đoán. Điểm EE trước khi khả thi không được vẽ như EE đạt yêu cầu.

Warm start yêu cầu ít nhất 2 particle để giữ baseline. Warm start có chủ đích: `cfg.search.seedCandidate=oldRun.candidate;`. Các resource được encode/repair vào miền preset mới. Baseline thẳng vẫn được đánh giá và giữ trong swarm. Warm start không mặc định áp dụng giữa các cấu hình trong phép so sánh.

## So sánh C0–C5

```matlab
setup_project;
report = runV10CComparison('full',[2026 608060 3486784401],0:5);
```

Yêu cầu đã chốt: L=3 Mbit/user, q=5 kbit/user/slot, Emax=17 kJ; ba seed 2026, 608060, 3486784401; Joint PSO, Full PSO, Full IPSO; mỗi phương pháp 120 particle và 1000 vòng ở profile full. Tổng cộng 6 cấu hình x 3 seed x 3 thuật toán = 54 lượt tìm kiếm. Mỗi cấu hình dùng cùng ngân sách, không cross-warm-start. Hàm mặc định chạy cả C0–C5 và ba seed trên; truyền 0:4 để bỏ C5. Khi gọi bao gồm C5, campaign bật rõ ràng mô hình thử nghiệm và lưu energyModel trong từng dòng, không coi nó là mô hình Dai. CSV/MAT được cập nhật sau mỗi tổ hợp để giữ kết quả nếu chạy bị gián đoạn. `comparison.csv` và `comparison.mat` lưu dưới `results/v10c/comparisons/`. `computedEE` có thể tồn tại khi thiếu QoS; cột `feasibleEE` chỉ có giá trị nếu đủ ràng buộc. Không dùng một run để khẳng định cấu hình tốt hơn nói chung.

## C5 thử nghiệm

```matlab
cfg=v10cConfig('C5','quick');
cfg.motion.allowExperimental=true;
v10c=runV10C(cfg);
```

C5 dùng rest-to-rest với a0=2 m/s^2 giả định; tốc độ đỉnh min(vc,sqrt(a0*d)). Năng lượng ramp tích phân công suất Zhang với lực đẩy có thêm ma. Đây là **mở rộng quasi-steady chưa kiểm chứng, không phải mô hình Dai đã công bố**. Chưa xét jerk, quá độ attitude/yaw, gió hay hiệu suất động cơ. Không cộng thêm phí stop/turn. C5 có chi phí tính cao hơn vì tích phân năng lượng cho từng chặng.

Không so EE C5/C4 như một gain thuật toán khi hai bên dùng mô hình năng lượng khác nhau; cần đánh giá lại cùng các quỹ đạo dưới cùng một backend.

## Kiểm tra

```matlab
setup_project;
addpath('tests');
testV10CModels;
testV10CSearch;
```

Đã chạy `testV10CModels`, `testV10CSearch` và kiểm tra ngắn đủ C0–C5 với ba thuật toán bằng MATLAB R2025a. Bộ 120 particle × 1000 vòng × ba seed được chuẩn bị để người dùng khởi chạy, chưa được thực thi toàn bộ. Chi tiết và giới hạn nằm trong [báo cáo kiểm chứng hiện tại](V10C_VERIFICATION_2026-11-04.md).

Chế độ chẩn đoán cũ vẫn có nếu cần: `cfg.execution.mode='initialize';`.
