# V11 — báo cáo triển khai và kiểm chứng ngày 02/11/2026

Đã tạo V11A/V11B độc lập, V11B là bản chính. Default particle/noma/random giữ hành
vi V10. Chỉ tạo file mới; `git diff --exit-code` trả 0. Không sửa file đã theo dõi,
không sửa setup_project.m, không thêm dependency, không chạy campaign dài.

## 1. File tạo mới

**Config:**
- `src/config/v11Config.m`
- `src/config/buildV11Simulation.m`
- `src/config/v11AlphaPreset.m`

**Geometry:**
- `src/geometry/v11ParticleLayout.m`
- `src/geometry/decodeV11Particle.m`
- `src/geometry/initialV11Particle.m`
- `src/geometry/repairV11Particle.m`
- `src/geometry/alphaPolicyV11.m`

**Models/evaluators:**
- `src/models/v11Channel.m`
- `src/models/findAchievableRateV11.m`
- `src/evaluators/evaluateTrajectoryV11.m`
- `src/evaluators/addV11EnergyMetrics.m`

**Optimizers:**
- `src/optimizers/optimizeTrajectoryV11JointPSO.m`
- `src/optimizers/optimizeTrajectoryV11FullPSO.m`
- `src/optimizers/optimizeTrajectoryV11FullIPSO.m`
- `src/optimizers/polishAlphaV11.m`
- `src/optimizers/solveAlphaQoSV11.m`

**Scripts:**
- `scripts/runV11.m`
- `scripts/maincodeV11A_EE.m`
- `scripts/maincodeV11B_EE.m`
- `scripts/plotV11Diagnostics.m` — bản sao thêm theo phê duyệt trong chat.
- `scripts/runV11AlphaStudy.m`

**Tests/fixtures:**
- `tests/testV11Models.m`
- `tests/check_v11_static.py`
- `tests/fixtures/v10_matlab_sha256_before_v11.json`
- `tests/fixtures/v11_baseline_50iter_seed2026.json`

**Docs:**
- `docs/V11_AB_GUIDE.md`
- `docs/superpowers/plans/2026-11-02-v11-alpha.md`
- `docs/V11_VERIFICATION_2026-11-02.md`

Tổng: 29 file mã/test/docs mới. Danh sách máy đọc được, log và số đo nằm trong
`results/v11/verification_20261102/`. Output smoke được lưu riêng theo mục 4.
Không có file cũ bị sửa; các tài liệu/output untracked có sẵn được giữ nguyên.

## 2. Kết quả thật theo mục 6.1–6.5

Chạy MATLAB R2025a, core only:

```matlab
setup_project;
addpath('tests');
report=testV11Models();
testV10Models();
testRFSlotMetrics();
testSaveV9Figures();
```

Lệnh MATLAB cuối kết thúc với **exit code 0**. Log đầy đủ:
`results/v11/verification_20261102/matlab_unit_tests.log`.

| Mục | Kết quả | Bằng chứng |
|---|---|---|
| 6.1a | PASS | totalBits, eeUAV, totalEnergy, rfEnergy, achRate, alphaTrace, pt và fitness V10/V11 sai khác <1e-12 |
| 6.1b | PASS | Full PSO seed 2026, 50 vòng, 4 particle: bestFitness, bestParticle, totalBits <1e-12; thêm random polish cùng RNG cũng khớp |
| 6.2 | PASS | Cả 8 tổ hợp variant × optimizeBS × alphaMode đúng các số chiều yêu cầu |
| 6.3 | PASS | Uniform, RNG không đổi, C3 bật/tắt, sim thiếu alpha fields vẫn tương thích |
| 6.4 | PASS về đúng đắn | Uniform optimum; hai lần gọi isequal; không đổi global RNG; L=1e12 và C5 bất khả thi trả finite/false; C3 tắt cho phép cấp nhiều hơn cho user mạnh; final bits/min-rate được tính lại |
| 6.5 | PASS | Static V11 5/5; static V10 12/12; snapshot V10/V9 đều đúng checksum |
| SLA mỗi solver <100 ms | **CHƯA ĐẠT** | Ca QoS khó: 4.992427 s, 200 vòng, 727052 rate evaluations |

Các dòng chính trong log thực tế:

```text
6.1 PASS: evaluator + 50-iteration optimizer + random polish exact equivalence.
6.2 PASS: all eight literal particle dimensions.
6.3 PASS: uniform policy, no RNG consumption, repair on/off, fallback fields.
Solver default constrained finalization: 4.992427 s, outerIter=200, rateEvals=727052
Solver C3-OFF: 0.023019 s, outerIter=1, rateEvals=1378
6.4 PASS: uniform optimum, determinism, impossible mission/C5, C3, final recomputation.
Solver no-QoS cold call: 0.011363 s; impossible-mission outerIter: 0
LATENCY <100ms across tested cases: 0
V11 runtime correctness acceptance tests PASSED.
V10 model/integration checks passed.
RF slot accounting checks passed.
Figure snapshot/export checks passed after closing original windows.
ALL MATLAB UNIT SUITES PASS.
```

Fixture baseline là số liệu V10 thật với **4 particle / 50 vòng**, không phải
120 particle. Giá trị: bestFitness=-0.062626972472287684;
totalBits=17172321.60887573. Nghiệm baseline còn vi phạm user-slot QoS, nên fitness
âm; không diễn giải con số EE của nó là nghiệm khả thi. JSON chứa đủ 149 tọa độ.

Ngoài bộ acceptance, đã giữ lại và chạy toàn bộ test model/integration V10 được
sao chép đổi định danh trong testInheritedV11Models; không bỏ các kiểm tra vật lý cũ.
Cũng đã chạy trực tiếp cả 3 bộ test V10/V9 có sẵn trong lượt xác nhận cuối.

## 3. Bảo toàn

Snapshot được tạo trước khi tạo source V11:

| Fixture | Số file | Kết quả |
|---|---:|---|
| v10_matlab_sha256_before_v11.json | 41 | PASS, 0 mismatch |
| v9_matlab_sha256_before_v10.json | 21 | PASS, 0 mismatch |

Phạm vi snapshot V10 đúng hợp của key fixture V9, V10_SOURCES và maincodeV10*.m /
runV10.m / plotV10Diagnostics.m. `v11Channel`, `findAchievableRateV11` và
`addV11EnergyMetrics` được đối chiếu nguyên văn với bản V10 sau đổi định danh.
`dronePropulsionPower` được gọi trực tiếp, không sao chép hoặc sửa.

Kết quả `check_v10_static.py`: **12/12 PASS**.
Kết quả `check_v11_static.py`: **5/5 PASS**.
Log và checksum máy đọc được: `static_checks.log`, `preservation.json` trong thư
mục verification. Không có xung đột tên hàm public V10/V11.

## 4. Thời gian và ngân sách

Benchmark ngắn, cùng scenario seed và optimizer seed **2026**, Full PSO:
**4 particle × 2 vòng**, tức cùng **12 đánh giá swarm**. Random polishing được giới
hạn **3 mẫu/slot** trong unit benchmark; không dùng mặc định 1250 mẫu/slot.

| Preset | Wall clock | Swarm evals | numFitnessEvals tổng |
|---|---:|---:|---:|
| particle_noma_random | 0.062404 s | 12 | 73 |
| uniform_noma_none | 0.008839 s | 12 | 12 |

73 = 12 swarm + 1 lần đánh giá lại + 20×3 ứng viên polishing. Đây là cùng ngân
sách swarm, **không phải cùng tổng ngân sách đánh giá**; báo riêng hai số để không
che chi phí polishing. Muốn bằng tổng số đánh giá thật phải đổi ngân sách một
nhánh, trái điều kiện giữ cùng numParticles/maxIter. Bảng chỉ đo chi phí ngắn,
không chứng minh tốc độ/độ tốt ở campaign 120×1000.

Đã thực hiện **đúng một run tích hợp ngắn** (các test tối ưu nhỏ còn lại là unit):
V11B / uniform_noma_qos, 4 particle, 2 vòng, QoS tối đa 2 vòng.
Kết quả: **0.847961 s**, dimension=44, **41 đánh giá fitness toàn run**.
Đã đọc lại results.mat và xác nhận layout, preset, final alpha và summary.
Nghiệm ngắn chưa đủ QoS; PASS ở đây là vận hành/lưu dữ liệu, không phải tối ưu đạt L.

Output:
`results/v11/V11B/uniform_noma_qos/seed2026_L3Mbit_20261102_170758_018/`.

Không chạy runV11AlphaStudy thật. Chỉ gọi **dryRun một tổ hợp**; xác nhận 1 dòng,
dimension=44, không chạy optimizer và không ghi output study. Chưa có kiểm chứng
runtime ghi table.csv/table.mat/summary của study đầy đủ hay campaign nhiều seed.

## 5. Diff tóm tắt ba file

**v11ParticleLayout.m:** giữ nguyên X/Y/BS; particle mode giữ 105 alpha weights
(kể cả 5 chiều inert); uniform mode dùng alpha=[] và dịch BS về ngay sau hình học.
Dữ liệu kích thước lấy từ layout, không cộng cứng D_pow trong optimizer.

**decodeV11Particle.m:** nếu layout.alpha rỗng, gọi alphaPolicyV11(sim) không dùng
RNG; nếu không rỗng, reshape như V10. Hàng cuối vẫn alpha=1/U.

**evaluateTrajectoryV11.m:** giữ normalize như V10; repair noma sort giảm dần theo
kênh, repair none giữ User ID. Giữ rate/energy models. Lưu particleLayout,
alphaPresetName và alphaSource để đọc kết quả theo đúng preset.

Diff đầy đủ sau loại khác biệt đổi tên:
`results/v11/verification_20261102/layout_decode_evaluator.diff`.

## 6. Quyết định đã được người dùng duyệt và giới hạn

- Đã hỏi theo mục 9.6 trước khi nối output/biến chiều bestParticle. Người dùng duyệt
  cấu trúc results/v11/V11A|B/<preset>/<run>, particleLayout + alphaPresetName,
  và bản sao plotV11Diagnostics độc lập.
- Đã báo solver khó vượt 100 ms và hỏi lựa chọn. Người dùng trả lời:
  **“Giữ thuật toán, báo rõ chưa đạt 100 ms”**. Giữ 5 khởi tạo / tối đa 200 vòng,
  không cắt số phép tính theo đồng hồ, nên kết quả deterministic. Không tuyên bố
  hoàn thành SLA thời gian.
- Bước C5 dùng anchored normalization vì chia trực tiếp vector đã kẹp cho tổng
  có thể làm mất QoS. Không đổi công thức rate; khả thi được kiểm tra lại trên rate thật.
- Review độc lập phát hiện một lỗi các chỉ số min-rate bị stale sau final solver.
  Đã tái hiện bằng test MATLAB thất bại, sửa stepMin/minFit/meanFit/
  minInternal/meanInternal và xác nhận test PASS cho cả qos và uniform-random.
  Các history vẫn giữ nguyên. Không còn Critical/Important được reviewer xác lập.
- Solver local và các đường dừng giải tích không phải chứng minh tối ưu chung cho
  trajectory/BS. Final solver không nằm trong fitness PSO; xem giới hạn trong guide.
- Plot V11 là bản sao đổi tên đã kiểm tra tĩnh; chưa render riêng toàn bộ 18 hình
  V11. Test xuất FIG/PNG kế thừa V9 đã chạy và PASS.
- Không commit, merge hoặc push; các file mới sẵn để xem xét trong workspace.

## 7. Đối chiếu V10/V11 ở ngân sách đầy đủ (bổ sung 02/11/2026)

Mục 6.1b ở trên chỉ chạy 4 particle × 50 vòng. Đã chạy thêm một lượt đối chiếu ở
**ngân sách thật**:

```matlab
setup_project;
report = compareV11V10Equivalence('B', 2026, 3e6);
assert(report.allPass);
% preset = particle_noma_random, 120 particle, 1000 vòng, polish 1250 mẫu/slot
```

| Hạng mục | Kết quả |
|---|---|
| Số trường so sánh | **30/30 PASS** (10 trường × trajFull, trajIPSO, trajJoint) |
| maxAbsDiff | **0** trên mọi trường |
| relDiff | **0** trên mọi trường |
| Ngưỡng | tuyệt đối $\le 10^{-12}$ |
| Wall clock V10 | 149.867 s |
| Wall clock V11 | 157.122 s |
| `numFitnessEvals` V11 | 417309 |

Đây là bằng chứng V11B tái tạo V10B **chính xác tuyệt đối**, không chỉ "gần đúng",
ở đúng cấu hình sẽ dùng cho paper.

Log: `results/v11/verification_20261102_204745_620/equivalence_full.log`.

**Ghi chú về tốc độ:** V11 chậm hơn V10 4,8% ở cùng ngân sách. Điều này khớp với
kết luận trong `V11_AB_GUIDE.md`: giảm 149→44 chiều **không** giảm wall clock khi
`numParticles`/`maxIter` giữ nguyên, vì chi phí bị tính kênh cho 21 waypoint chiếm
gần hết. Chênh lệch 4,8% là nhiễu đo, không phải đặc trưng của V11.

Giá trị tham chiếu tại seed 2026, L=3e6, preset `particle_noma_random`:
`trajFull` EE = 1.065848183818e+04 bit/J, `trajIPSO` EE = 1.164910754441e+04 bit/J.
