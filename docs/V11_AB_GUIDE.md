# V11A và V11B

V11 là bản fork độc lập của V10, giữ nguyên file V10/V9/V8 và `setup_project.m`.
V11B là biến thể chính; V11A giữ đối chứng hình học. Các file vật lý rate, kênh và
energy được sao chép nguyên văn sau đổi tên V10→V11; propulsion dùng lại trực tiếp
`dronePropulsionPower.m`. Không cần Optimization Toolbox hoặc CVX.

## Cấu trúc file

- `src/config`: `v11Config`, `buildV11Simulation`, `v11AlphaPreset`.
- `src/geometry`: layout, decode, initial, repair V11 và `alphaPolicyV11`.
- `src/models`: `v11Channel`, `findAchievableRateV11`; dùng lại propulsion.
- `src/evaluators`: `evaluateTrajectoryV11`, `addV11EnergyMetrics`.
- `src/optimizers`: Joint PSO, Full PSO, Full IPSO V11; `polishAlphaV11`, `solveAlphaQoSV11`.
- `scripts`: main A/B, `runV11`, `plotV11Diagnostics`, `runV11AlphaStudy`.
- `tests`: `testV11Models.m`, `check_v11_static.py`, các fixture checksum và baseline.

## Chạy

```matlab
setup_project;
run('scripts/maincodeV11B_EE.m'); % bản chính
% run('scripts/maincodeV11A_EE.m'); % Y cố định
```

Hai main mặc định dùng cấu hình tương đương V10: particle / noma / random.
Các tham số radio, geometry, mission, flight và ngân sách swarm giữ giá trị V10.
Không tự chạy hai main trong kiểm thử; mặc định 120 particle × 1000 vòng là nặng.

```matlab
setup_project;
cfg=v11Config();
cfg=v11AlphaPreset('uniform_noma_qos',cfg);
data=runV11('B',cfg);
```

`v11AlphaPreset(name)` tự gọi `v11Config`; đối số thứ hai tùy chọn giữ các tùy chỉnh
đã có. `runV11()` mặc định B. Các hàm đọc alpha field có fallback tương đương V10
khi `sim` cũ chưa có field đó.

## Một cấu hình chung và ba trục alpha

| Trục | Giá trị | Ý nghĩa |
|---|---|---|
| `variant` | A, B | A tối ưu X; B tối ưu X/Y; Z cố định |
| `cfg.alpha.mode` | particle, uniform | Có/không có alpha trong particle |
| `cfg.alpha.repair` | noma, none | Bật/tắt C3: alpha yếu→mạnh giảm dần |
| `cfg.alpha.finalSolver` | none, random, qos | Xử lý alpha sau khi PSO kết thúc |

| Preset | mode | repair | finalSolver |
|---|---|---|---|
| particle_noma_random | particle | noma | random |
| particle_noma_none | particle | noma | none |
| uniform_noma_none | uniform | noma | none |
| uniform_noma_qos | uniform | noma | qos |
| uniform_noc3_qos | uniform | none | qos |
| particle_noc3_random | particle | none | random |
| uniform_noma_qos_fair | uniform | noma | qos |

`particle_noma_random` tái lập hành vi V10, gồm polishing random cho Full PSO/IPSO.
Joint mặc định giữ hành vi V10: không final polishing.
`cfg.alpha.finalizeJoint=false` ở default và cả sáu preset ban đầu. Preset
`uniform_noma_qos_fair` bật cờ này để cả Joint/Full/IPSO đều xử lý alpha cuối.
Có thể bật `cfg.alpha.finalizeJoint=true` trực tiếp ở preset khác. `uniform_noma_qos` là cấu hình thí
nghiệm được đề xuất trong đặc tả; chưa có campaign để khẳng định ưu thế trong paper.
C3 bật/tắt trên alpha cố định 1/N cho kết quả giống nhau; cấu hình none/none phát
warning. `noc3` chỉ thay đổi phân bổ khi alpha được phép thay đổi.

| Hình học | optimizeBS | particle | uniform |
|---|---|---:|---:|
| A | false | 124 | 19 |
| A | true | 130 | 25 |
| B | false | 143 | 38 |
| B | true | 149 | 44 |

Particle mode cố ý giữ 21×5=105 trọng số, gồm 5 chiều ở waypoint đến không phục vụ.
Không cắt các chiều này vì sẽ đổi chuỗi RNG và phá tương đương V10. Uniform mode
không tạo alpha block và không gọi `rand` cho block đó.

**RNG:** hai mode tiêu thụ chuỗi ngẫu nhiên khác nhau. Cùng scenario seed vẫn giữ
cùng user/fading, nhưng không diễn giải hai nghiệm swarm cùng seed thành một cặp
khởi tạo giống nhau. Báo cáo mean±std nhiều seed; bảng thời gian cùng seed chỉ là
benchmark chi phí, không phải bằng chứng ưu thế nghiệm.

## Mô hình năng lượng và bài toán alpha

Giữ toàn bộ vật lý V10: EH cấp RF lý tưởng; pin cấp cruise/hover; mẫu số EE gồm
cruise + hover + RF. Không cộng EH thêm lần nữa. Khi quỹ đạo và BS cố định, mẫu số
không phụ thuộc alpha, nên tối đa EE tương đương tối đa tổng bit.

Trong mô hình ideal SIC hiện tại, với C3 và tổng alpha=1, alpha=1/N đạt tổng bit
lớn nhất khi bỏ ràng buộc dữ liệu từng user. C4 (tổng bit từng user) hoặc C5 (bit
user/slot) có thể buộc alpha rời 1/N. Kết luận này không áp dụng khi bỏ C3.

Đặt gain tăng dần, `s_i=noise/(P*g_i)` giảm dần và `S_i=sum(alpha_i:end)`.
Mỗi hạng phụ thuộc `S_i` trong tổng rate là
`log(s_i+S_i)-log(s_(i-1)+S_i)`, không giảm theo `S_i`. C3 cho
`S_i <= (N-i+1)/N`; chia đều đạt đồng thời các cận này.

`solveAlphaQoSV11` dùng kênh và rate helper V11, cache kênh cho từng slot; năm điểm
khởi tạo từ RandStream riêng, projected gradient với backtracking, và dual multiplier
cho thiếu dữ liệu mission. Chọn nghiệm theo tổng shortfall rồi tổng bit; các ứng
viên phải tôn trọng C5 nếu C5 khả thi trên slot đó. Không bảo đảm tối ưu toàn cục.

Sau khi normalize/sort và kẹp C5 từ user mạnh về yếu, solver chuẩn hóa theo một
vector tối thiểu khả thi. Chia trực tiếp cho tổng có thể làm vi phạm C5, nên bước
này dùng tổ hợp affine để giữ ràng buộc SINR và tổng alpha=1. Nếu C5 bất khả thi,
trả một vector hữu hạn và báo không khả thi, không phát lỗi do không hội tụ.

Có hai đường dừng có chứng minh dưới C3: uniform đã đạt mọi QoS; hoặc tất cả L đều
vượt cận trên rate không nhiễu của từng user và uniform đạt C5. Trường hợp thứ hai,
min tổng shortfall chính là max tổng bit nên uniform đã là tối ưu của tiêu chí đó.
Các trường hợp khác dùng tối đa `qosMaxOuterIter=200`, `qosTol=1e-3`, `qosSeed=12345`.
`info.feasible` dùng tolerance của solver; `result.isFeasible` vẫn dùng tiêu chí
nghiêm ngặt của evaluator V10. Luôn dùng cờ evaluator để báo nghiệm khả thi của paper.

Solver là **bước cuối**, không nằm bên trong mỗi lần đánh giá PSO. Vì vậy PSO ở
mode uniform tìm hình học với alpha đều; solver cuối không quay lại sửa quỹ đạo
nếu hình học đó không cho phép đạt QoS. Đây không phải tối ưu luân phiên.

## Kết quả và đồ thị

Output tách riêng theo cấu trúc đã duyệt:
`results/v11/V11A|V11B/<preset>/<seed_L_timestamp>/`.
Mỗi thư mục chứa `results.mat`, `summary.txt`, và các hình nếu bật lưu.
`plotV11Diagnostics` là bản sao đổi định danh của V10; không dùng nhãn V10 cho V11.

Kết quả lưu `alphaPresetName`, `alphaFinalizeJoint`, `particleLayout`, cấu hình/sim và raw/final của ba
thuật toán, gồm `trajJointRaw` và `trajJoint`. `summary.txt` ghi
`Finalize Joint = 0|1`. Joint random polishing tự xác định layout 124/143 chiều
(particle) hoặc 19/38 chiều (uniform), không giả định có biến BS. `bestParticle` giữ đúng chiều của preset, không pad 44 thành 149.
Sau QoS solver, `alphaTrace`, `rawAlpha`, `achRate`, `pt` và energy/QoS đã tính lại
là kết quả cuối; `alphaSource='final-solver'`. `bestParticle` khi đó vẫn là particle
raw của optimizer và không được dùng một mình để tái dựng alpha cuối. Đọc kèm
`alphaTrace` và `particleLayout`. Các history vẫn thuộc nghiệm raw, không ghi đè
điểm cuối lịch sử bằng giá trị sau solver. Điều này cũng áp dụng random polishing
khi mode uniform không có alpha block.

`numFitnessEvals` đếm đánh giá trajectory/mission thực tế của mỗi thuật toán, gồm
đánh giá lại và random polish; IPSO tính thêm mutation thực sự có đánh giá.
`alphaSolverInfo.numRateEvals` đếm riêng số lần gọi rate helper bên trong QoS solver.
Một lần QoS solver không được giả thành hàng nghìn lần fitness, hoặc bỏ mất chi
phí đó khi diễn giải ngân sách. `data.numFitnessEvals` gồm baseline và ba thuật toán.

### Chi phí: điều V11 không hứa

Giảm số chiều particle **không** làm giảm wall clock ở cùng `numParticles`/`maxIter`,
vì số lần đánh giá giữ nguyên và chi phí mỗi lần đánh giá bị tính kênh cho toàn bộ
21 waypoint chiếm gần hết; bỏ 105 trọng số alpha chỉ tiết kiệm vài phép chia. Vì
vậy không được viết "V11 nhanh hơn V10" dựa trên số chiều.

Cái V11 thực sự đổi:

- **Chất lượng trên mỗi ngân sách**: cùng số particle và số vòng, PSO trải 120
  particle trên 44 chiều thay vì 149 chiều, nên phủ không gian tốt hơn nhiều.
- **Bỏ được bước random polish** ở cấu hình `uniform_noma_none`: một lần đánh giá
  thay cho 25000 lần của polish.
- **Solver QoS không rẻ hơn polish**: ca khó đo được khoảng 727000 rate
  evaluation, tương đương cùng bậc (thậm chí cao hơn) 25000 fitness evaluation của
  polish. Lợi ích của solver là **cấu trúc** (lexicographic, dual multiplier cho
  C4), không phải tốc độ.

Câu đúng để dùng: *bỏ alpha khỏi particle cho phép cùng ngân sách đánh giá đạt
nghiệm hình học tốt hơn; bước solver cuối thay thế random polish với chi phí cùng
bậc nhưng có bảo đảm cấu trúc.*

## Ma trận alpha study

```matlab
setup_project;
opts=struct('dryRun',true,'presets',{{'uniform_noma_qos'}}, ...
    'variants',{{'B'}},'minBitsPerUser',1e6,'seeds',2026);
T=runV11AlphaStudy(opts); % một tổ hợp, không chạy PSO, không ghi output
```

Mặc định: 5 preset × 2 variant × 3 mức L × 3 seed = 90 run; **không chạy tự động**.
Đặt `dryRun=false` chỉ khi chủ động muốn chạy study. Có thể override `presets`,
`variants`, `minBitsPerUser`, `seeds`, và `cfg`. `numParticles`/`maxIter` là override
rõ ràng cho smoke test; mặc định giữ 120/1000 cho mọi preset.

`opts.smoke=true` ép **5 particle × 3 vòng** cho mọi thuật toán, ưu tiên hơn
`numParticles`/`maxIter` override và phát cảnh báo **SMOKE — không dùng cho kết quả paper**.
Numeric `opts.minBitsPerUser=[1e6,2e6,3e6]` vẫn là sweep ba mức scalar; cell như
`{[1e6,2e6,3e6,1e6,2e6]}` là một mục tiêu theo User ID. Có thể trộn scalar/vector
trong cell. Cột `L` là NaN cho vector; `LLabel`/`LPerUser` giữ đầy đủ vector dạng chữ,
các cột metric vẫn là số. Một mẫu cho std=NaN; nhóm rỗng bỏ qua; nhóm không có
nghiệm khả thi ghi `(no feasible run)`. Cột `alphaFinalizeJoint` lưu cờ theo mỗi hàng.

Study lưu `table.csv`, `table.mat`, `summary.txt` tại
`results/v11/alphaStudy/<timestamp>/`. Mỗi hàng báo Full PSO; giữ thêm số đánh giá
raw swarm, toàn run và số rate evaluation QoS để phân biệt chi phí. `wallClockSeconds`
đo toàn `runV11` gồm cả Joint/IPSO, như mô tả trong summary. Mean±std nhóm theo
preset/variant/L qua nhiều seed; báo tỷ lệ khả thi và EE của nhóm khả thi riêng.
**Cùng swarm settings không có nghĩa tổng số đánh giá bằng nhau** vì random polish
và mutation có thêm chi phí.

## Kiểm chứng

```matlab
setup_project;
addpath('tests');
report=testV11Models();
```

```sh
python3 tests/check_v10_static.py
python3 tests/check_v11_static.py
```

Unit test gồm evaluator/optimizer 50 vòng tương đương V10 (4 particle để giới hạn
thời gian), random polish cùng RNG, 8 số chiều, repair/RNG/fallback, solver C3 bật/tắt,
không hội tụ, C5 bất khả thi, all optimizers/modes và một study dryRun. Fixture
`v11_baseline_50iter_seed2026.json` chứa kết quả V10 đo thật với 4 particle; không
phải fixture của cấu hình 120 particle. Test vẫn đối chiếu V10 trực tiếp mỗi lần.
Snapshot `v10_matlab_sha256_before_v11.json` kiểm tra 41 file; fixture V9 kiểm tra
riêng và các phương trình sao chép được đối chiếu nguyên văn.

Thời gian solver và bảng benchmark phải đọc từ báo cáo kiểm chứng thực tế đi kèm;
không suy ra yêu cầu <100 ms từ kiểm tra source hoặc từ riêng đường tắt alpha đều.

Báo cáo đo thật và danh sách nghiệm thu:
[V11_VERIFICATION_2026-11-02.md](V11_VERIFICATION_2026-11-02.md).
Ca QoS khó cuối cùng mất khoảng 4,99 s (200 vòng), chưa đạt 100 ms; người dùng đã
chọn giữ thuật toán và công bố giới hạn này. Ca không QoS khoảng 11 ms; ca C3 tắt
được test khoảng 23 ms. Đây là số đo trên máy hiện tại, không phải bảo đảm thời gian.


## Đối chiếu V10/V11 trước study

```matlab
setup_project;
opts=struct('numParticles',4,'maxIter',50);
report=compareV11V10Equivalence('B',2026,3e6,opts);
assert(report.allPass);
```

Không bỏ opts nếu chỉ muốn kiểm tra ngắn: mặc định **120×1000**, giữ đủ random
polishing mặc định. Script không tự chạy, không tạo figure hay output của V10;
chỉ ghi log riêng `results/v11/verification_<timestamp>/equivalence_full.log`.
So 10 trường × 3 thuật toán với ngưỡng tuyệt đối 1e-12. Với preset khác
`particle_noma_random`, cảnh báo và chỉ so hình học; không hứa hẹn geometry sẽ khớp.
`opts.dryRun=true` chỉ trả cấu hình/budget, không tạo thư mục hoặc chạy optimizer.
Script này là ngoại lệ duy nhất được phép gọi V10 trong guard source V11; test
tương đương cũng được phép. Mọi file V11 vận hành vẫn bị kiểm tra lời gọi V10.

Fixture baseline thêm ghi chú rằng fitness âm không phải nghiệm tham chiếu khả
thi. Unit test đọc/đối chiếu fixture, không ghi đè nó. Các giá trị số vẫn giữ nguyên.
Xem [báo cáo B1–B5](V11_PATCHES_2026-11-02.md) và log đi kèm.
