# V10A và V10B

Hai bản phát triển từ V9, chỉ thêm file mới. Các main, evaluator, optimizer,
helper và test MATLAB V8/V9 được giữ nguyên từng byte trong lượt triển khai.

## Cấu trúc file

```text
scripts/          maincodeV10A_EE, maincodeV10B_EE, runV10, plotV10Diagnostics
src/config/       v10Config, buildV10Simulation
src/models/       dronePropulsionPower, v10Channel, findAchievableRateV10
src/evaluators/   evaluateTrajectoryV10, addV10EnergyMetrics
src/optimizers/   ba optimizer V10 và polishAlphaV10
src/geometry/     layout, khởi tạo, giải mã và repair particle V10
tests/            testV10Models.m, check_v10_static.py
```

Không còn folder `src/v10`. `setup_project` đã thêm đệ quy `src` và folder
`scripts`, nên cách chạy giữ nguyên sau khi sắp xếp.

## Chạy

Mở MATLAB tại repo khi bạn muốn chạy, rồi chọn **một** bản:

```matlab
run('scripts/maincodeV10A_EE.m');
% hoặc:
run('scripts/maincodeV10B_EE.m');
```

Chạy campaign nhiều seed/cấu hình cho cả A và B:

```matlab
run('scripts/maincodeV10Campaign.m');
% hoặc xem cấu hình trước khi chạy:
campaign = runV10Campaign(struct('dryRun',true));
```

Campaign có hai profile, cùng **120 particle**:

- `quick`: 1000 iteration (mặc định của `maincodeV10Campaign`);
- `full`: 3000 iteration (production).

Với 3 seed x 3 cấu hình mỗi nhóm, campaign generic là 54 run rất nặng; nên
xem `dryRun` trước và cân nhắc thu hẹp `variants`/`groups`.

`maincodeV10Campaign` hiện được đặt cho một lần chạy cụ thể: seed
**3486784401**, cả A và B, **L = 1, 2, 3 Mbit**, **5 kbit/user/slot**,
**hover = 1 s**; tổng 6 run và `makePlots=true` để xem Figure 1.

Log của optimizer in `EE = ... bit/J | L:1 bitSlot:1 bitUserSlot:1 | feasible:1`
thay cho fitness âm. `summary.txt` in EE tính được cùng các cờ QoS; score nội
bộ của PSO chỉ còn trong `results.mat` (`fitness`, `bestFitness`) và không
được in ra.

Hai main tự gọi `setup_project`. Các biến `cfg`, `sim`, `resBase`,
`trajJoint`, `trajFullRaw`, `trajIPSORaw`, `trajFull`, `trajIPSO`, `v10` và
`v10OutputFolder` được đưa vào workspace. Các biến cùng tên có thể bị thay
thế khi chạy bản tiếp theo; kết quả tự lưu tách thư mục A/B.

V9 vẫn dùng lệnh cũ `run('scripts/maincodeV9_EE.m')`; cấu hình V10 không
làm thay đổi V9.

## Một cấu hình chung

Chỉnh `src/config/v10Config.m`. Cả hai main đọc cùng file này mỗi lần chạy.

| Nhóm cấu hình | Nội dung |
|---|---|
| `geometry` | Vùng bay, điểm đầu/cuối, số waypoint, độ cao, BS, số user |
| `radio` | Công suất mỗi BS, phi, eta, băng thông, noise, path loss, Rician |
| `mission` | Hover, tỷ lệ EH/RF, L, QoS bit/slot, energy budget |
| `flight` | Toàn bộ tham số Drones Table 2, tốc độ hành trình |
| `optimizers` | Joint PSO, Full PSO, IPSO và số mẫu polishing |
| `output` | Lưu MAT/figure, vẽ hình, thư mục kết quả |

Mặc định giữ radio V9: 46 dBm mỗi BS, phi=eta=0.9, B=1 MHz,
beta0=-30 dB, seed=2026, L=4.2e6 bit/user; không tự đổi thành Table I của
Flight to Efficiency. Không còn hằng Pr/phi/eta/B/time riêng trong hàm rate V10.

Có thể dùng cấu hình tạm mà không sửa file chung:

```matlab
setup_project;
cfg = v10Config();
cfg.mission.minBitsPerUser = 3e6;
cfg.geometry.altitude = 30;
dataA = runV10('A', cfg);
dataB = runV10('B', cfg);
```

## Khác nhau giữa A và B

- **A:** Z cố định; tối ưu X và alpha; Y chia đều từ startXY đến endXY,
  mặc định giảm 15 m/đoạn. Full PSO/IPSO thêm tọa độ BS như V9.
- **B:** Z cố định; tối ưu X/Y và alpha; Full PSO/IPSO thêm tọa độ BS.
  `geometry.minYProgress=1` m mặc định, áp dụng cho **độ tiến mỗi đoạn**.
  Nếu endY < startY thì Y giảm; đổi chiều điểm đầu/cuối thì Y tăng.
  Cấu hình bị từ chối nếu `(numWaypoints-1)*minYProgress` vượt khoảng Y.
- Với 21 waypoint và 5 user, A có 124/130 biến Joint/Full, B có 143/149.
  Khối alpha vẫn có 21 hàng để giữ thứ tự V9; hàng cuối chỉ là diagnostic,
  không đóng góp bit/năng lượng RF.

## Thời gian và năng lượng

Mỗi waypoint **trừ điểm đến cuối** có một lần hover phục vụ, rồi UAV bay
đến waypoint tiếp theo. Mặc định có 20 lần phục vụ và 20 đoạn bay.

```text
hover n: EH/UL 0.5 s → RF/DL 0.5 s → bay đoạn n ở tốc độ 15.521 m/s
```

Kênh/rate được tính tại điểm hover. UL được giả định cấp đủ dữ liệu như V9;
không thêm mô hình forwarding hai chặng. Đoạn bay cuối vẫn được tính đủ.
Không truyền dữ liệu trong thời gian di chuyển.

```text
t_fly[n] = norm(q[n+1]-q[n]) / cruiseSpeed
E_fly   = P_fly(cruiseSpeed) * sum(t_fly)
E_hover = P_fly(0) * numberOfServingPoints * hoverTime
E_H[n]  = eta*phi*P_received[n]*T_EH
P_RF[n] = E_H[n]/T_RF
E_RF    = sum(P_RF[n]*T_RF)
E_total = E_fly + E_hover + E_RF
D_user  = sum(rate_user[n]*T_RF)
EE_UAV  = sum(D_user)/E_total
```

`mission.minBitsPerSlot` và `mission.minBitsPerUserPerSlot` là QoS bit trong
mỗi slot phục vụ (0 = tắt). Mặc định per-user **5 kbit**; xem
[`V10_SLOT_QOS_AND_FIXES_2026-10-28.md`](V10_SLOT_QOS_AND_FIXES_2026-10-28.md)
để biết ngưỡng chọn từ log và các sửa lỗi cùng ngày.

Ba thành phần profile/induced/parasite dùng đúng Eq.(11), Table 2 Drones;
lực đẩy một rotor là độ lớn cân bằng lực ngang/trọng trường chia số rotor.
Hover được bổ sung theo yêu cầu của bạn bằng cùng hàm ở v=0; ledger đã in
của bài không có hạng hover riêng. Không thêm năng lượng gia tốc, quay,
leo/hạ độ cao, mạch hoặc PA losses.

Với Table 2, hàm cho cruise khoảng 108.940787 W và hover 172.387633 W.
Không ép cruise thành 108.9118 W tác giả báo; sai khác nhỏ đã được ghi nhận
trong `DRONES_ENERGY_CODE_REVIEW_2026-10-28.md`.

EH cấp RF lý tưởng; pin cấp động cơ. `batteryEnergyIdeal` chỉ gồm fly+hover;
mẫu số mục tiêu là **tổng năng lượng sử dụng** gồm cả RF, không phải chỉ pin.
Không cộng EH vào mẫu số thêm lần nữa.

`mission.energyBudgetJ` mặc định 17000 J theo budget tổng tải của Drones;
đặt `Inf` nếu muốn bỏ ràng buộc budget. L được áp dụng theo tổng bit từng
User ID gốc. Nghiệm đủ dữ liệu/budget/geometry có fitness=EE_UAV; nghiệm
thiếu dữ liệu hoặc vượt budget được xếp bằng âm tổng vi phạm chuẩn hóa.
EE của nghiệm không khả thi được in kèm cờ QoS; không dùng làm EE đạt yêu cầu.

## Kết quả và đồ thị

Trong `src/config/v10Config.m`, ba nhóm figure mặc định đều bật:

```matlab
cfg.output.figureGroups.base = true;            % Figure 1-8, không có Figure 3
cfg.output.figureGroups.EH_Alpha_config = true; % Figure 9-16
cfg.output.figureGroups.flyingEnergy = true;   % Figure 17-18
```

Đổi nhóm muốn tắt thành `false`. `cfg.output.makePlots = false` tắt toàn bộ
đồ thị. Tắt cả ba nhóm cũng không tạo hoặc lưu figure mới. Các công tắc
không thay đổi tối ưu, dữ liệu MAT hoặc summary. Khi gọi vẽ lại trong một
phiên có sẵn figure, công tắc chỉ bỏ qua việc vẽ nhóm, không đóng hình cũ.

Kết quả nằm trong `results/v10/V10A/` hoặc `results/v10/V10B/`, thư mục run
có seed, L và thời gian để không ghi đè. `results.mat` giữ cấu hình, sim,
baseline và raw/final của cả ba thuật toán; `summary.txt` ghi các thành phần
năng lượng, tổng bit/user, thiếu bit, budget, chiều dài và thời gian.

Figure 1/2/4/5 và 6–16 giữ các nhóm thông tin quen thuộc của V9, nhưng EE
và tổng năng lượng dùng phạm vi V10; RF power vẫn báo riêng. Figure 17
tách cruise/hover/RF và có panel µJ riêng cho RF; Figure 18 đối chiếu Y với
đồng hồ nhiệm vụ gồm cả hover. Điểm EE sau polishing chỉ hiển thị nếu khả thi.

Kiểu vẽ đã được đối chiếu lại trực tiếp với mã V9: Figure 1 có nhãn GU,
cột BS, điểm đầu/cuối và marker/màu V9; Figure 2/4/5 dùng các đường và
chú thích như V9 (Figure 5 trở lại dBm). Joint vẫn hiện ở các đồ thị
chẩn đoán 6–18; các đồ thị đầu theo cách V9 hiển thị baseline/Full PSO/IPSO.
Figure 9 trở lại bốn ô bit, năng lượng, EE từng slot và độ lệch alpha;
năng lượng/EE dùng tổng tải UAV đúng mô hình V10. Figure 10 có đường EE
tham chiếu chỉ tính từ nghiệm khả thi. Figure 11–16 giữ bố cục, nét,
colorbar và thang màu chung của V9. Các công tắc nhóm vẫn giữ nguyên.

Có thể vẽ lại workspace hiện có mà không chạy lại PSO:

```matlab
plotV10Diagnostics(v10);
```

Hoặc đọc một `results.mat` đã lưu rồi gọi `plotV10Diagnostics(saved.data)`
với `saved = load('đường_dẫn/results.mat')`. Lượt sửa giao diện đồ thị này
chỉ kiểm tra tĩnh, không mở/chạy MATLAB nên chưa xác nhận hình render.

Các field chính: `eeUAV`, `eeRF` (chỉ diagnostic RF), `totalBits`,
`totalBitsPerUser`, `flightEnergy`, `hoverEnergy`, `rfEnergy`, `totalEnergy`,
`totalHarvestedEnergy`, `flightTime`, `totalHoverTime`, `missionTime`,
`totalDistance`, `isFeasible`, `dataQoSFeasible`, `energyFeasible`.

Lịch sử raw bao gồm `flightEnergyHistory`, `hoverEnergyHistory`,
`rfEnergyHistory`, `totalEnergyHistory`, `totalBitsHistory`,
`totalBitsPerUserHistory`, `transmitPowerHistory`, `alphaUserHistory`,
`feasibleHistory`, `totalDistanceHistory`, `missionTimeHistory`.
Polishing giữ lịch sử raw và chỉ đổi kết quả cuối/alpha.

## Kiểm chứng

Theo yêu cầu, agent **không mở/chạy MATLAB hoặc Octave**. Đã chạy các kiểm
tra source contract/Python, kiểm tra công thức số và bảo toàn SHA-256 các
file MATLAB cũ. Đây không phải xác nhận MATLAB runtime hoặc mô phỏng pass.

Bạn có thể tự chạy test phân tích và smoke test ngắn khi muốn:

```matlab
setup_project;
addpath('tests');
testV10Models;
```

Để chạy thử rất ngắn thay vì mặc định quick 1000 vòng (full 3000):

```matlab
cfg = v10Config();
cfg.optimizers.joint.numParticles = 4;
cfg.optimizers.full.numParticles = 4;
cfg.optimizers.ipso.numParticles = 4;
cfg.optimizers.joint.maxIter = 2;
cfg.optimizers.full.maxIter = 2;
cfg.optimizers.ipso.maxIter = 2;
cfg.optimizers.alphaPolishMinimumSamples = 2;
cfg.optimizers.alphaPolishSamplesPerUser = 0;
cfg.output.makePlots = false;
cfg.output.saveFigures = false;
cfg.output.saveResults = false;
data = runV10('B',cfg);
```

Một run ngắn có thể chưa tìm được nghiệm đủ L; đó không phải bằng chứng
miền bài toán bất khả thi. Ngân sách đánh giá Joint/Full và mutation/polishing
vẫn khác nhau như V9, nên không kết luận ưu thế thuật toán chỉ từ số vòng.
