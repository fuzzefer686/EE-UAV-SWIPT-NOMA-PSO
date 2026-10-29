# EE-UAV-SWIPT-NOMA-PSO

Pipeline V8 của UAV-SWIPT-NOMA, dùng làm nền để phát triển tối ưu Energy
Efficiency (EE). Bản mới `maincodeV9_EE.m` thử EE theo năng lượng phát RF;
entry point `maincodev8nUser.m` vẫn giữ fitness theo rate của V8.

## Cấu trúc

```text
scripts/             Entry point V8
src/models/          NOMA, SWIPT và phân bổ công suất
src/evaluators/      Fitness quỹ đạo, Joint và Joint+BS
src/optimizers/      Joint PSO, Full PSO, Full IPSO và alpha polishing
reference/           Bài báo Flight to Efficiency và mã gốc Raw0
results/baseline_v8/  20 log V8 đã có
docs/               Định hướng EE, mốc seed 2026, nguồn và checksum
setup_project.m      Cấu hình MATLAB path
```

Mã gốc được giữ nguyên ở `reference/original_code`; V8 có các tham số khác
bài báo. `docs/BASELINE_PROVENANCE.json` ghi nguồn và SHA-256 từng file.
Log là kết quả đã có, chưa được chạy lại sau khi dọn repo.

## Chạy mô phỏng

Mở MATLAB tại gốc repo, rồi chạy:

```matlab
setup_project;
run('scripts/maincodeV9_EE.m');
```

Script chạy đường bay thẳng, Joint PSO, Full PSO, Full IPSO và alpha
polishing. Cấu hình đầy đủ có thể chạy lâu. Mã gốc được chạy riêng trong
phiên MATLAB khác, với Current Folder là `reference/original_code`.
Không thêm toàn bộ repo bằng `addpath(genpath(pwd))`, vì mã tham khảo có
hàm trùng tên với pipeline V8.

### Lưu biểu đồ V9 sau khi chạy

V9 mặc định lưu toàn bộ figure đang mở sau khi vẽ xong vào thư mục
`results/ee_rf/figures/run_YYYYMMDD_HHMMSS_mmm/`. Mỗi lần lưu tạo một thư
mục riêng; mỗi biểu đồ có file PNG 300 dpi và file `.fig` để mở/chỉnh sửa
trong MATLAB. Đường dẫn thực tế được in ra Command Window và giữ trong
biến `v9FigureFolder`.

Hàm lưu toàn bộ `.fig` trước, rồi xuất PNG từ bản sao mở ẩn để việc đóng
cửa sổ gốc trong giai đoạn xuất PNG không làm mất các hình còn lại.
Nếu xuất PNG lỗi, bản `.fig` đã lưu vẫn được giữ để mở hoặc xuất lại sau.

Có thể đổi thư mục hoặc tắt lưu trước khi chạy:

```matlab
setup_project;
saveV9Plots = true; % false để tắt lưu tự động
v9FigureRoot = fullfile(pwd, 'results', 'my_v9_figures');
run('scripts/maincodeV9_EE.m');
```

Nếu biểu đồ đã mở sẵn, lưu ngay mà không chạy lại tối ưu:

```matlab
v9FigureFolder = saveV9Figures();
```

### EE RF tạm thời — thay đổi tối thiểu

- `Tslot = 1 s`, gồm `0.5 s` uplink và `0.5 s` downlink.
- 21 waypoint tạo 20 slot, tổng thời gian 20 s. Slot n là đoạn waypoint
  n→n+1, tạm lấy kênh tại waypoint n và giả định uplink cấp đủ dữ liệu.
- User u nhận `R_DL(n,u) * 0.5` bit/slot; tổng RF energy là
  `sum(pt(1:end-1) * 0.5)` J. Fitness là tổng bit chia tổng RF energy.
- Giới hạn bước dx/dz được đặt `Inf` trong chế độ này; biên vùng bay và
  endpoints giữ nguyên. Chưa thêm QoS, năng lượng bay/mạch hoặc tổn hao PA.
- Công thức tập trung trong `src/evaluators/addRFSlotMetrics.m`; ba evaluator
  chỉ gọi thêm hàm này ở cuối. PSO/IPSO giữ nguyên cách tìm kiếm; alpha
  polishing chọn nghiệm theo EE trong chế độ EE RF.

Xem kết quả chi tiết trong `resBase`, `trajJoint`, `trajFull`, `trajIPSO`:
`bitsPerUserPerSlot` (20×5), `bitsPerSlot`, `totalBitsPerUser`, `totalBits`,
`energyPerSlot`, `totalEnergy` (chỉ RF), `eeRF` (bit/J), `timeSeconds`.
`achRate`/`pt` vẫn có 21 hàng để giữ diagnostics waypoint; hàng cuối không
được cộng vào tổng của hành trình. `rateFitness` giữ score cũ để kiểm tra.

### Đồ thị để phân tích EE gần nhau

Tổng quãng đường Euclid 3D của ba quỹ đạo cuối được in tự động khi chạy V9
và lưu trong `flightDistanceSummary` (m). Độ dài từng đoạn nằm trong
`flightSegmentDistances{1/2/3}` theo thứ tự Joint PSO/Full PSO/Full IPSO.
Nếu đã có kết quả workspace, không cần chạy lại tối ưu:

```matlab
[flightDistanceSummary, flightSegmentDistances] = measureV9FlightDistance(trajJoint, trajFull, trajIPSO);
```

Khoảng cách tính theo đoạn thẳng nối mọi waypoint liên tiếp, kể cả đoạn
đến waypoint cuối; đây là độ dài quỹ đạo, chưa phải năng lượng bay.

V9_EE tự vẽ Figure 6–16 cho cả ba thuật toán:

- Figure 6: EE theo vòng lặp, đơn vị bit/J.
- Figure 7: tổng bit của nghiệm tốt nhất theo EE, đơn vị Mbit.
- Figure 8: năng lượng RF của cùng nghiệm đó, đơn vị µJ.
- Figure 9: bit, năng lượng, EE và sai lệch alpha so với 1/N theo slot.
- Figure 10: tổng bit theo tổng năng lượng của nghiệm cuối; đường nét đứt
  là một mức EE tham chiếu để thấy hai đại lượng thay đổi cùng tỷ lệ.
- Figure 11: tổng bit mỗi User nhận trong cả nhiệm vụ, theo vòng lặp; ba
  subplot tương ứng Joint PSO, Full PSO và Full IPSO, đơn vị Mbit.
- Figure 12: công suất RF UAV theo vòng lặp, đơn vị nW: trung bình/min/max
  qua các slot và bản đồ màu slot × vòng lặp cho từng thuật toán.
- Figure 13: alpha trung bình qua các slot của mỗi User theo vòng lặp.
- Figure 14–16: alpha của từng User ở từng slot và từng vòng lặp, lần lượt
  cho Joint PSO, Full PSO và Full IPSO. Không lấy trung bình ở các bản đồ này.

Lần chạy mới lưu thêm `totalBitsHistory`, `totalEnergyHistory`, cùng chiều
với `bestHistory`: phần tử đầu là vòng 0 sau khởi tạo, tiếp theo là vòng
1…maxIter. Chỉ ghi các metrics đã có; không đổi RNG, fitness hay optimizer.
Polishing không ghi đè điểm cuối lịch sử EE; kết quả sau polishing được
đánh dấu bằng vòng tròn riêng ở Figure 6–8. Tổng bit/năng lượng của nghiệm
best-EE có thể tăng hoặc giảm qua các vòng; chúng không tối ưu riêng lẻ.

Lần chạy mới cũng lưu `totalBitsPerUserHistory` (vòng × User),
`transmitPowerHistory` (vòng × slot, W) và `alphaUserHistory`
(vòng × slot × User). User là ID gốc, không phải hạng kênh weak→strong.
Các giá trị đều thuộc cùng nghiệm best-EE; bit không cộng dồn qua các vòng
PSO. Figure 11/13 đánh dấu giá trị sau polishing bằng vòng tròn riêng.
Figure 12 và 14–16 chỉ lưu slot truyền thông, bỏ waypoint đến cuối.
Muốn các Figure 11–16 cần chạy lại V9; kết quả cũ không có các lịch sử này.

Nếu workspace vẫn giữ kết quả chạy cũ, có thể vẽ ngay bằng:

```matlab
plotV9EEDiagnostics(trajJoint, trajFullRaw, trajIPSORaw, trajFull, trajIPSO);
```

Dữ liệu cũ chưa có lịch sử bit/năng lượng: Figure 7–8 sẽ hiển thị cột kết
quả cuối và ghi rõ thiếu lịch sử. Muốn hai đường theo vòng lặp cần chạy
lại `maincodeV9_EE.m`. Agent không chạy MATLAB hoặc dựng lịch sử giả.
Ảnh `results/ee_rf/seed608060_final_diagnostics.png` chỉ dùng các tổng cuối
từ output diagnose seed608060 người dùng cung cấp; không là đồ thị vòng lặp.

Chạy `run('scripts/maincodev8nUser.m')` để dùng fitness và thiết lập
thời gian/giới hạn bước của baseline V8. Tên V9_EE mới do người dùng đặt;
bản này phát triển trực tiếp từ V8, không dùng mô hình V9 lịch sử.
Kiểm tra cách tính slot khi người dùng muốn chạy MATLAB:

```matlab
setup_project;
addpath('tests');
testRFSlotMetrics;
```

## Nhánh Git

- `main`: baseline đã rút gọn.
- `feature/ee-optimization`: bắt đầu từ đúng commit của main; dùng viết EE
  và merge lại main khi hoàn tất.
- Tag `baseline-v8-clean`: mốc baseline rút gọn cố định để đối chiếu sau
  khi main đã nhận các thay đổi EE.
- Tag `baseline-flight-to-efficiency-v8`: bộ lưu trữ đầy đủ ban đầu, có
  V4–V7 và các thí nghiệm cũ. Không giữ các bản sao này trong cây thư mục.

Không có CCPSO trong pipeline baseline. Nếu cần thử lại, thực hiện trên
nhánh thí nghiệm riêng. Báo cáo phụ, snapshot trùng lặp, checkpoint,
autosave, mã GA/FA/DE và Python thử nghiệm đã bỏ khỏi cây thư mục baseline.

Xem [hướng dẫn Git](GIT_GUIDE.md) và [định hướng EE](docs/RESEARCH_DIRECTION_EE.md).

Context từ bài gốc, 5 bài tham khảo, đối chiếu mã V8 và các quyết định về
năng lượng được lưu tại [ghi nhớ nghiên cứu EE](docs/EE_RESEARCH_CONTEXT.md).
