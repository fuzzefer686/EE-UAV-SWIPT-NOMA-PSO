# Bàn giao ngữ cảnh cho agent tiếp theo

Cập nhật: 28/10/2026. Repo: `EE-UAV-SWIPT-NOMA-PSO`.

## Triển khai V10A/V10B theo yêu cầu mới

Người dùng đã yêu cầu triển khai **cả hai** phương án A/B, giữ V9 chạy được,
và sau đó chỉ dẫn rõ **không mở/chạy MATLAB**. Chỉ dẫn này còn hiệu lực.

- Entry points: `scripts/maincodeV10A_EE.m`, `scripts/maincodeV10B_EE.m`.
- Cấu hình chung: `src/config/v10Config.m`. A giữ Y grid và tối ưu X; B tối ưu
  X/Y với độ tiến Y tối thiểu cấu hình được; cả hai giữ Z=30 m mặc định.
- Theo yêu cầu tổ chức lại file, đã chuyển 17 hàm V10 khỏi `src/v10` vào
  `src/config`, `src/models`, `src/evaluators`, `src/optimizers`,
  `src/geometry` và `scripts` theo chức năng; xóa folder rỗng `src/v10`.
  Nội dung 17 file được đối chiếu SHA-256 không đổi khi di chuyển.
  Setup và lệnh chạy không đổi; guide và kiểm tra tĩnh đã cập nhật đường dẫn.
- Theo phản hồi giao diện đồ thị, `scripts/plotV10Diagnostics.m` đã dùng lại
  các block vẽ V9 cho Figure 1/2/4/5 và 11–16, nét/màu V9 ở 6–10.
  Figure 5 dùng dBm; Figure 9 có EE từng slot; vẫn giữ total-energy units,
  feasible filtering và ba công tắc nhóm. Chỉ sửa plotting, không sửa solver
  hay source V9; chưa render bằng MATLAB theo chỉ dẫn người dùng.
- Các file `.m` trước lượt V10 được giữ nguyên từng byte; manifest 21 file
  tại `tests/fixtures/v9_matlab_sha256_before_v10.json` gồm cả thay đổi chưa
  commit vốn có của người dùng, không so nhầm với HEAD cũ.
- Phi/eta/B/Pr/noise/pathloss/Rician đều lấy từ cấu hình V10; không sửa
  hàm rate chung cũ của V8/V9. Radio và ngân sách PSO/IPSO mặc định giữ V9.
- Drones Eq.(11), Table 2 tính cruise/hover; thêm hover theo yêu cầu đã chốt.
  Có 20 điểm hover phục vụ ở đầu 20 đoạn, điểm đến cuối không hover nhưng
  đoạn bay đến cuối vẫn tính đủ. T_hover=1 s, chia .5 EH/.5 RF; t_fly=d/v.
- Mục tiêu bit/(cruise+hover+RF); giữ L=4.2e6 bit/user; gross energy budget
  mặc định 17000 J theo Drones, có thể đặt Inf trong cấu hình.
- Kết quả MAT/config/raw/final và summary lưu riêng `results/v10/V10A|B`.
  Plots mới giữ thông tin V9 và tách total energy khỏi RF; saveV9Figures
  được gọi lại dưới tên gốc, không sửa hoặc shadow bất kỳ helper V9 nào.
- Đã chạy 10 kiểm tra Python source-contract/số học, gồm công thức công suất,
  Y progression, bảo toàn các phương trình update V9 và SHA-256 file cũ.
  **Chưa chạy** test MATLAB `tests/testV10Models.m`, compiler/Code Analyzer
  hoặc mô phỏng. Không diễn giải kết quả kiểm tra Python thành MATLAB pass.
- Reviewer độc lập đã phát hiện alpha floor lặp lại sau chuẩn hóa; đã sửa
  theo guard 1e-12 của V9 và thêm kiểm tra. Review độc lập bị ngắt bởi giới
  hạn usage trước khi kết thúc; đã bổ sung tự kiểm tra nguồn và cấu trúc.
- Hướng dẫn: [`V10_AB_GUIDE.md`](V10_AB_GUIDE.md). Plan và trạng thái tại
  `docs/superpowers/plans/2026-10-28-v10ab.md`.

## Yêu cầu và phân tích mới ngày 28/10/2026

Người dùng cung cấp `docs/drones-10-00238.pdf`, nói mentor yêu cầu đưa
mô hình năng lượng bay của bài vào code; lượt này yêu cầu kiểm tra code và
giải thích mô hình. Đã tạo báo cáo
[`DRONES_ENERGY_CODE_REVIEW_2026-10-28.md`](DRONES_ENERGY_CODE_REVIEW_2026-10-28.md).
Chưa sửa code, chưa chạy MATLAB hoặc PSO trong lượt review.

- Bài Drones dùng quad-rotor, bay ngang ở z cố định, một tốc độ hành trình
  chung; P_f theo (11), E_f=P_f*D_f/v, energy budget gồm E_f+E_t.
- Khác biệt phải giải quyết: code tối ưu z và mỗi đoạn mất 1 s; không gọi
  việc dùng chiều dài 3D với công thức bay ngang là bê nguyên mô hình.
- Ledger đã in của bài chưa có hạng propulsion trong thời gian hover riêng,
  dù giao thức thu dữ liệu khi hover. Cần phân biệt tái hiện và bổ sung tải này.
- Không chỉ đổi mẫu số: mode EE, polisher, RF parameters đang hardcode,
  histories, kiểm tra energy trong plots và feasible reporting cần đồng bộ.
- Thêm propulsion không tự làm alpha rời 0.2 khi giữ quỹ đạo/BS cố định.
- Báo cáo phân biệt số P_f tác giả công bố 108.9118 W với phép kiểm tra
  độc lập Table 2 khoảng 108.940787 W theo độ lớn cân bằng lực ngang.
  Chưa xác định nguyên nhân sai khác nhỏ, không ép tham số khớp số báo.
- Đã xác minh thêm nguồn RF parameters trong phụ lục báo cáo: Table I
  Flight to Efficiency dùng eta=phi=0.7, còn Raw0 lưu ở repo và V8/V9 dùng
  0.9. Pr=46 dBm khớp; B=1 MHz và T nội bộ=1e-6 có trong code, không nêu
  trong Table I. beta0 của bài là -50 dB, V8/V9 dùng -30 dB. Main/hàm rate
  hiện khớp Pr/phy/neta mặc định; rủi ro hardcode là khi thay cấu hình.

## Điểm tiếp nối mới nhất — đối chiếu ngày 27/10/2026

Đã đọc lại chat `Làm rõ ràng buộc alpha và chọn L`, tài liệu nghiên cứu và
mã hiện tại. Các mục lịch sử trong `EE_RESEARCH_CONTEXT.md` mô tả từng thời
điểm; mục 16 chưa bao gồm ràng buộc dữ liệu hiện đã có trong mã.

- Công việc gần nhất là phân tích alpha tiến về 0.2 và ảnh hưởng của yêu cầu
  dữ liệu tối thiểu `D_u >= L_u` cho từng user trong cả hành trình.
- `scripts/maincodeV9_EE.m` hiện mặc định `mainSeed = 2026` nếu workspace
  chưa có biến này; `sim.minBitsPerUser = 4.2e6` bit/user. Không suy ra seed
  của một lần chạy chỉ từ giá trị mặc định vì workspace có thể ghi đè seed.
- `addRFSlotMetrics.m` đã kiểm tra QoS theo tổng bit của từng User ID gốc.
  Khi vi phạm dữ liệu nhưng các kiểm tra trước đó hợp lệ, fitness là âm tổng
  thiếu chuẩn hóa; khi khả thi, fitness là EE RF. Điểm thiếu dữ liệu âm không
  phải EE âm; không lấy EE của nghiệm đủ bit trừ điểm này để báo gain EE.
- Với quỹ đạo/BS cố định, năng lượng RF độc lập alpha. Sum-rate kết hợp
  alpha ordering ưu tiên alpha đều 1/N; hai ràng buộc tổng bằng 1 và ordering
  không tự ép chia đều. Nếu chia đều vẫn thỏa L, alpha 0.2 là nghiệm hợp lệ.
  Nếu không thỏa, cần đổi alpha hoặc hình học. Sau khi đủ L, solver tiếp tục
  tối ưu EE và luôn kiểm tra lại L cho các nghiệm mới.
- Tăng L đã cho thấy alpha khác đều trong các kết quả người dùng cung cấp,
  nhưng không có bảo đảm độ phân tán tăng đơn điệu. Alpha trung bình 0.2
  không chứng minh mọi slot đều 0.2; cần phân biệt raw và sau polishing.
- L nên có căn cứ từ yêu cầu phục vụ/scenario; log dùng để khảo sát tính khả
  thi và độ nhạy, không chọn L chỉ nhằm ép alpha rời 0.2. L hiện tại 4.2 Mbit
  là cấu hình thử nghiệm, chưa tự trở thành yêu cầu ứng dụng đã xác nhận.
- Có 6 log seed `3486784401`, L=1/1.5/2/3/4/4.2 Mbit/user tại
  `results/ee_rf/logs/`. Theo tổng hợp trong chat cũ, Joint chưa tìm được
  nghiệm đủ bit ở L=3/4/4.2 trong ngân sách chạy đó; hai Full tìm được.
  Điều này không chứng minh miền bài toán Joint bất khả thi hay nghiệm toàn
  cục đã được tìm thấy. Không gán các số liệu này cho seed 2026.
- Bộ figure seed 2026 ở `results/ee_rf/figures/` đã được sửa nhãn mức L;
  hai bộ L=3 đã gộp và giữ các bản Figure 6–7 bổ sung bằng hậu tố
  `_diagnostics`. Figure 11 là bit/user; Figure 13 là alpha trung bình.
  Nhãn L=1.5 được giữ theo tên cũ, chỉ phù hợp với dữ liệu chứ chưa xác định
  duy nhất từ hình. README và `folder_labels.json` lưu bằng chứng.
- Log cũ không đủ khôi phục chính xác toàn bộ quỹ đạo, alpha theo slot và
  lịch sử từng vòng; cần workspace/MAT hoặc FIG phù hợp. Chat trước ghi nhận
  đã sửa và kiểm tra việc lưu figure khi cửa sổ gốc bị đóng. Lượt tiếp quản
  này chỉ đọc mã/tài liệu, không chạy MATLAB hay xác minh lại các mô phỏng.

Các câu hỏi còn mở: căn cứ chọn L và tính khả thi qua nhiều seed; đóng góp
của optimizer so với polishing; mô hình năng lượng UAV đầy đủ; dữ liệu relay
UL→DL. Không tự thêm mô hình hoặc chạy mô phỏng chỉ vì tiếp quản ngữ cảnh.

## Đọc trước

1. [`README.md`](../README.md) — cấu trúc repo, cách chạy và mô tả prototype EE-RF.
2. [`docs/EE_RESEARCH_CONTEXT.md`](EE_RESEARCH_CONTEXT.md) — ghi nhớ nghiên cứu chi tiết, quyết định và các phân tích trước đây; mục 16 là phân tích mới nhất trong file này.
3. [`docs/RESEARCH_DIRECTION_EE.md`](RESEARCH_DIRECTION_EE.md) — phạm vi nghiên cứu và hướng phát triển.
4. [`docs/EE_RF_DIAGNOSIS_SEED2026.md`](EE_RF_DIAGNOSIS_SEED2026.md) — phân tích log/alpha, không được gán các số liệu đó cho seed hiện hành.
5. [`GIT_GUIDE.md`](../GIT_GUIDE.md) — quy trình nhánh và merge.

Nếu ghi chú cũ khác mã nguồn hoặc chỉ dẫn mới của người dùng, kiểm tra trạng thái hiện tại và ưu tiên chỉ dẫn mới nhất của người dùng. Phân biệt rõ điều đã được người dùng quyết định, điều mới chỉ là giả định/prototype, và điều chưa chốt.

## Mục tiêu và phạm vi

- Hướng nghiên cứu dài hạn đã được người dùng chọn: tối ưu Energy Efficiency (EE, bit/J) **của UAV**, gồm năng lượng bay và truyền thông, trên nền mô hình UAV-SWIPT-NOMA và pipeline V8.
- Chỉ lấy V8 trở xuống làm nền. Các hướng V9/V10 lịch sử, DTS/tau tối ưu, ICIT, cache, finite-data và các ràng buộc nhiệm vụ từ những hướng đó nằm ngoài phạm vi hiện hành.
- Người dùng chưa chọn rotary-wing hay fixed-wing. Trước tiên cần tìm hiểu và hạch toán các loại năng lượng; không mặc định mô hình rotary-wing.
- Chưa chốt: công thức propulsion phù hợp khi UAV đổi cả x và z; EE theo tổng tải UAV hay năng lượng lấy từ pin; mô hình PA/mạch/phụ tải; rate relay qua UL/DL; căn cứ chọn L và tính khả thi năng lượng. QoS tổng bit/user đã có trong prototype.
- EE toàn mạng chỉ là chỉ số bổ sung tiềm năng, chưa phải mục tiêu chính. EH là nguồn năng lượng, không tự động được tính là năng lượng tiêu thụ hay làm mất tải bay/mạch.
- Ưu tiên trao đổi bằng tiếng Việt. Không hỏi lại các quyết định đã có trong tài liệu này trừ khi yêu cầu mới làm chúng thay đổi.

## Trạng thái mã và prototype

- `scripts/maincodev8nUser.m` là entry point giữ fitness rate của V8 để đối chiếu.
- `scripts/maincodeV9_EE.m` là prototype mới theo yêu cầu người dùng, phát triển trực tiếp từ V8; tên V9_EE không có nghĩa kế thừa mô hình V9 lịch sử.
- Prototype hiện dùng `objectiveMode='ee-rf'`: 21 waypoint/20 slot, mỗi slot 1 s (0.5 s UL + 0.5 s DL); bit được tính từ rate DL × 0.5 s; mẫu số là năng lượng RF `pt × 0.5 s`. Kênh lấy tại waypoint đầu slot và giả định UL đủ dữ liệu. Tạm bỏ giới hạn bước dx/dz, vẫn giữ biên vùng bay và endpoints.
- Đây **chưa phải** EE UAV dài hạn: chưa gồm năng lượng bay, PA losses, mạch/điều khiển hay cân bằng năng lượng pin. Đã có QoS tổng bit/user; chưa có ràng buộc dữ liệu forwarding UL→DL.
- Công thức slot tập trung ở `src/evaluators/addRFSlotMetrics.m`; ba evaluator gọi helper. Optimizer chính: Joint PSO, Full PSO, Full IPSO; có alpha polishing.
- Các lịch sử theo vòng lặp và biểu đồ EE/bit/năng lượng/user/power/alpha đã được thêm cho kết quả EE. Dữ liệu cũ thiếu lịch sử thì không được dựng giả; cần chạy lại mới có các trace đó.
- Có helper `scripts/measureV9FlightDistance.m` để tính tổng chiều dài đường gấp khúc 3D từ workspace kết quả; đây chưa phải năng lượng bay.

## Kết quả và phân tích cần giữ đúng

- Seed mặc định hiện là `2026` nếu workspace chưa đặt `mainSeed`. Log seed `3486784401`, log cũ seed `2026` và diagnose seed `608060` phải được phân biệt theo cấu hình, L và thời điểm; cùng seed chưa đủ để coi mọi kết quả là cùng thí nghiệm.
- Phân tích đại số cho thấy, với objective sum-rate/EE-RF và ràng buộc alpha ordering, alpha đều `1/N` tối ưu theo alpha khi giữ trajectory/BS cố định nếu không xét QoS. Khi có L, kết luận chỉ áp dụng nếu alpha đều thỏa yêu cầu dữ liệu. Điều đó không chứng minh ba optimizer đạt cùng nghiệm toàn cục; khác biệt quỹ đạo/BS vẫn quan trọng.
- Fitness hiện tại bỏ qua các thành phần min-rate/fairness/smoothness của V8 khi chuyển sang EE-RF. Không gọi prototype này là EE đầy đủ hoặc kết luận về tính khả thi bay.
- Các số EE cỡ `1e12–1e13 bit/J` trong log cũ có mẫu số chỉ là RF energy. Ghi rõ giới hạn này khi diễn giải.

## Workspace hiện tại

- Đang ở nhánh `feature/ee-optimization`, tracking `origin/feature/ee-optimization`.
- Working tree vốn đã có nhiều sửa đổi và file mới chưa commit trước khi tạo handoff này. Không reset, checkout làm mất thay đổi, hoặc coi toàn bộ working tree là thay đổi của riêng lượt hiện tại. Kiểm tra `git status --short --branch` trước mọi thao tác Git.
- Thay đổi hiện diện gồm README/direction docs, V8 entry point, evaluators, optimizers, alpha polishing; có thêm prototype/diagnostics, tests, kết quả và tài liệu tham khảo. Xem `git status` để biết danh sách đầy đủ tại thời điểm agent tiếp quản.
- `setup_project.m` chỉ thêm `scripts` và `src`; không dùng `addpath(genpath(pwd))` vì `reference/original_code` có hàm trùng tên.
- Các ghi chú triển khai cũ yêu cầu không tự chạy MATLAB. Chat sau có ghi nhận chạy MATLAB để kiểm tra/xử lý figure; không suy rộng thành toàn bộ mô phỏng/tests đều pass. Lượt tiếp quản này không chạy MATLAB; chỉ chạy tiếp khi người dùng yêu cầu hoặc chỉ dẫn mới cho phép rõ ràng.

## Quy ước khi tiếp tục

- Bắt đầu bằng việc đọc các tài liệu ở trên và kiểm tra trạng thái Git; không lặp lại các phân tích hoặc chạy lại mô phỏng chỉ để tái tạo số cũ.
- Giữ riêng baseline V8, prototype EE-RF và mục tiêu EE UAV đầy đủ; nêu rõ mô hình/đơn vị/phạm vi năng lượng cho mọi kết quả.
- Mã gốc nằm trong `reference/original_code`; chạy độc lập nếu cần vì trùng tên hàm.
- Hướng Git và tag baseline được mô tả trong `GIT_GUIDE.md` và README. Không commit/push/merge nếu người dùng chưa yêu cầu.
