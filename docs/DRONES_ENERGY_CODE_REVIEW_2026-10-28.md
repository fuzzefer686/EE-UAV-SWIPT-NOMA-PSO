# Đối chiếu mô hình năng lượng Drones 10(4), 238 với code hiện tại

Ngày: 28/10/2026. Đây là báo cáo phân tích, không phải thay đổi mô hình đã triển khai.

## Kết luận

Có thể dùng mô hình propulsion của bài báo làm nền cho code. Tuy nhiên,
không thể giữ đồng thời mọi giả định hiện tại rồi gọi đó là bê nguyên mô hình:
bài dùng bay ngang, độ cao cố định và cùng tốc độ hành trình; code dùng
quỹ đạo thay đổi x/z, y cố định theo lưới và thời gian 1 s cho mỗi đoạn.

Công việc trước mắt là thống nhất hình học và thời gian, rồi hạch toán năng
lượng trong cùng evaluator cho baseline, Joint, Full PSO và Full IPSO.
Đưa một hằng số công suất vào phần in kết quả không làm solver tối ưu EE mới.

## Phạm vi và bằng chứng

- Nguồn chính: `docs/drones-10-00238.pdf`, 25 trang. Đã trích văn bản và
  kiểm tra trực quan trang 8 chứa (10), (11), (12), Table 2.
- Bài: Tianyi Zhang et al., *Trajectory and Power Control for Sustainable
  UAV-Assisted NOMA-Enabled Backscattering IoT*, Drones 2026, 10, 238.
  DOI: https://doi.org/10.3390/drones10040238.
- Kiểm tra mã nguồn: 21 file MATLAB đang dùng trong scripts/src/tests và
  setup_project; đối chiếu thêm 7 file MATLAB lưu trữ trong reference/original_code.
  Trọng tâm kết luận là pipeline đang chạy, không dùng lỗi Raw0 quy cho V8.
- Đã kiểm tra cấu hình, luồng evaluator → optimizer → polishing → diagnostics,
  cách tính bit/J, ràng buộc và các test hiện có.
- Không sửa `.m`, không chạy optimizer hoặc MATLAB. Không có tool
  `check_matlab_code`/resource `matlab_coding_guidelines` trong phiên này;
  không tuyên bố đã chạy Code Analyzer hoặc test MATLAB.
- Các phép tính số trong báo cáo là kiểm tra công thức độc lập bằng Python,
  không phải kết quả mô phỏng lại PSO và không phải kiểm chứng phần cứng.

## Mô hình trong bài báo

### Giả định đi kèm

Mục 2 và 2.3, trang 5–8:

- UAV quad-rotor, 4 rotor, khối lượng mô hình 2 kg.
- Bay trên mặt phẳng ngang ở độ cao cố định.
- Bay thẳng giữa các điểm thu dữ liệu, cùng tốc độ hành trình v.
- Thu dữ liệu khi bay treo tại các điểm; thời gian thu mỗi điểm là t_hov.
- Bỏ chi phí quá độ do đổi hướng/tăng giảm tốc tại các điểm chuyển tiếp.
- Chỉ tính propulsion và truyền RF trong energy budget; bỏ mạch/điều khiển
  theo xấp xỉ của bài. Đây không phải sổ năng lượng đầy đủ của phần cứng.

Bài tối đa sum-throughput với energy budget; không trực tiếp tối đa tỷ số bit/J.
Chỉ kế thừa propulsion không đòi hỏi đổi bài toán hiện tại sang BackCom,
TSP/GA, reflection coefficients hoặc các thuật toán của bài.

### Lực đẩy và công suất

(10) biểu diễn cân bằng lực của từng rotor khi bay ngang đều. Khi triển khai
dạng vô hướng, cần dùng độ lớn lực đẩy. Với lực cản ngang và trọng lực thẳng
đứng vuông góc, cách diễn giải vật lý cho độ lớn này là:

```text
F_drag(v) = 0.5 * rho * S_FP * v^2
T_r(v)   = sqrt((m*g)^2 + F_drag(v)^2) / n_r
```

Đây là cách chuyển cân bằng vector thành độ lớn cho công thức công suất,
không phải phép lấy số vô hướng `F_drag - m*g`. Ký hiệu (10) của PDF có
vector hướng và vector trọng trường nhưng chưa viết rõ chuẩn độ lớn;
cần ghi nhận cách diễn giải này khi tái hiện.

Viết lại (11) với T_r là lực đẩy một rotor, đơn vị N:

```text
P_profile = n_r * delta/8 * (T_r/(c_T*rho*A) + 3*v^2)
            * sqrt(T_r*rho*c_s^2*A/c_T)

P_induced = n_r * (1+c_f) * T_r
            * sqrt(sqrt(T_r^2/(4*rho^2*A^2) + v^4/4) - v^2/2)

P_parasite = n_r * 0.5*d_0*rho*c_s*A*v^3

P_f(v) = P_profile + P_induced + P_parasite       [W]
```

- Profile: công suất khắc phục lực cản của cánh rotor.
- Induced: công suất tạo dòng khí/lực nâng; vẫn khác 0 khi bay treo.
- Parasite: công suất thắng lực cản thân, có hạng v^3.
- T_r và A đều theo **một rotor**; hệ số n_r bên ngoài mới cộng 4 rotor.
  Không dùng mg làm lực đẩy mỗi rotor rồi lại nhân n_r.

Tham số Table 2:

| Ký hiệu | Giá trị | Ý nghĩa |
|---|---:|---|
| n_r | 4 | Số rotor |
| rho | 1.293 kg/m³ | Mật độ không khí |
| S_FP | 0.01 m² | Diện tích cản tương đương của thân |
| m | 2 kg | Khối lượng UAV |
| g | 9.8 m/s² | Độ lớn gia tốc trọng trường |
| v | 15.521 m/s | Tốc độ hành trình dùng trong mô phỏng |
| c_s | 0.0955 | Rotor solidity |
| delta | 0.012 | Hệ số cản tiết diện cánh |
| c_T | 0.302 | Hệ số lực đẩy |
| c_f | 0.131 | Hệ số hiệu chỉnh induced |
| d_0 | 0.8333 | Tỷ số lực cản thân theo rotor |
| A | 0.0314 m² | Diện tích đĩa một rotor |

Bài nói rõ đây là bộ tham số mô hình lý thuyết lấy từ tài liệu [30], không
phải bộ hệ số được đo và công bố đầy đủ cho một mẫu DJI cụ thể.

### Từ W sang J

Trang 8–9 định nghĩa:

```text
D_f = sum_n norm(q[n+1] - q[n])                  [m]
T_fly = D_f / v                                 [s]
E_f = P_f(v) * D_f / v                          [J]
E_t = sum_n P_t[n] * t_hov                      [J]
E_f + E_t <= E_max
```

Phải cộng cả đoạn rời điểm đầu và đoạn đến điểm cuối. Trong bài, z không đổi
nên norm 3D và norm ngang cho cùng chiều dài.

Mục 5, trang 19 sử dụng P_f=108.9118 W, v=15.521 m/s, E_max=17000 J,
t_hov=0.1 s. Theo các số tác giả báo, chi phí bay là khoảng 7.01706 J/m;
đường ngang 300 m cần khoảng 19.32865 s và 2105.118 J, chỉ tính hành trình.

Kiểm tra độc lập Table 2 với độ lớn lực đẩy ở trên cho:

| v (m/s) | Profile (W) | Induced (W) | Parasite (W) | Tổng (W) |
|---:|---:|---:|---:|---:|
| 0 | 0.185855 | 172.201778 | 0 | 172.387633 |
| 15 | 0.500972 | 86.779773 | 21.809048 | 109.089793 |
| 15.521 | 0.523368 | 84.256024 | 24.161396 | 108.940787 |

Giá trị cuối khác số tác giả báo khoảng 0.0266%. Chưa xác định nguyên nhân;
không sửa tham số để ép khớp và không coi 108.9118 W là số đã tái hiện chính
xác từ công thức. Cần giữ riêng số tác giả công bố và số tự tính.

### Giới hạn ngay trong cách hạch toán của bài

Mặc dù giao thức có bay treo để thu dữ liệu, biểu thức E_f=P_f*D_f/v và
E_t=sum(P_t*t_hov) không có hạng `P_f(0)*sum(t_hov)` riêng. Với đúng các
định nghĩa đã in, năng lượng động cơ trong thời gian bay treo chưa được
hạch toán tường minh. Không thể nói E_t đã chứa nó vì P_t là công suất RF.

Cần phân biệt tái hiện đúng biểu thức của bài với bổ sung tải bay treo cho
mô hình UAV của mình. Nếu bổ sung thì đó là mở rộng phải công bố rõ.
Nếu UAV truyền thông trong lúc bay liên tục thì không cộng thêm cùng một
khoảng thời gian bay treo; phải chọn lịch hoạt động nhất quán.

## Các vấn đề của code và điểm không tương thích

### Những điểm phải giải quyết để đưa mô hình vào

1. **Mẫu số hiện chỉ là RF.** `src/evaluators/addRFSlotMetrics.m:25–50`
   tính sum(pt*0.5), gán eeRF và fitness. Chưa có propulsion/energy budget.
   Phải tính năng lượng trong đánh giá từng particle, không chỉ sau tối ưu.

2. **Độ cao thay đổi trái giả định bài.** `scripts/maincodeV9_EE.m:121–130`
   cho z=15–45 m; ba evaluator giải mã zInternal. Đổi norm ngang sang norm
   3D trong E_f=P_f*D/v không tự thêm vật lý lên/xuống. Bê nguyên bài cần
   giữ z cố định; muốn giữ 3D cần mô hình phù hợp hơn. Tài liệu [30] của bài
   là Ding, Gao, Shen, IEEE TWC 2020, DOI 10.1109/TWC.2020.3016024, có
   chủ đề mô hình 3D; chưa thẩm định các phương trình của [30] trong lượt này.

3. **Thời gian 1 s và cùng tốc độ không đồng thời đúng cho đường tùy ý.**
   `maincodeV9_EE.m:76–86,161–165`: delta_y=15 m/slot, Tslot=1 s,
   dxMax=dzMax=Inf. Tốc độ đoạn thực là
   sqrt(dx²+15²+dz²)/1, không phải tự động bằng 15.521 m/s.
   Trong miền hiện tại, một đoạn được phép dài khoảng 153.704 m.
   Đây là khả năng của miền tìm kiếm, chưa khẳng định nghiệm đã chạy có đoạn đó.
   Ngay cả z cố định, giới hạn 15.521 m/s với slot 1 s chỉ cho |dx|<=3.98766 m.
   Nếu dùng tốc độ đúng bằng 15.521 m/s, thời gian đoạn phải là d_n/v;
   nếu thêm thời gian dừng, missionTime phải cộng thêm thời gian đó.

4. **Lịch bay và lịch UL/DL đang dùng chung một đồng hồ.**
   `addRFSlotMetrics.m:13–20` xem 1 s vừa là thời gian di chuyển vừa là
   0.5 s UL + 0.5 s DL, lấy kênh tại đầu đoạn. Bài báo truyền khi hover,
   bay giữa các điểm là thời gian riêng. Chuyển sang fly-hover phải xác định
   riêng t_fly, t_UL, t_DL; bay liên tục thì dùng propulsion trong toàn Tslot.
   Không chỉ nhân công suất động cơ với thời gian DL.
   Thay thời gian truyền còn đổi tổng bit và tính khả thi của L=4.2 Mbit.

5. **Chưa có giới hạn tốc độ/budget.** Các evaluator mới kiểm tra biên và
   chênh x/z, không kiểm tra norm vận tốc, gia tốc hoặc E_max. Chênh từng
   trục không tương đương giới hạn tốc độ tổng. Gia tốc/chi phí rẽ không bắt
   buộc nếu tái hiện đúng xấp xỉ của bài, nhưng cần công bố việc bỏ qua chúng.
   Không tự lấy E_max=17000 J làm dung lượng pin thực của UAV mình.

6. **Mode mới có thể âm thầm quay về fitness V8.** Cả ba evaluator chỉ gọi
   helper EE nếu objectiveMode='ee-rf'; ba optimizer và polisher cũng nhận
   riêng chuỗi này. Chỉ đổi tên thành 'ee-uav' sẽ bỏ tính EE/lịch sử,
   polisher đi vào nhánh min-rate. Phải nối đồng bộ toàn pipeline.

7. **Năng lượng tổng và RF phải tách field.**
   `scripts/plotV9EEUserHistories.m:31–37` buộc totalEnergyHistory bằng
   sum(transmitPowerHistory)*downlinkTime. Nếu chỉ cộng E_f vào totalEnergy
   mà không đổi code này, plotting sẽ báo HistoryMismatch. Các nhãn µJ/nW,
   eeRF, energyScope, diagnose và test RF phải giữ đúng ý nghĩa của chúng.

8. **Nguồn EH không thay thế propulsion.** Code hiện dùng EH lý tưởng cấp
   RF DL. Nếu tính tổng tải UAV thì cộng propulsion và tải truyền thông;
   không trừ EH rồi vẫn gọi là tổng tải. Nếu tính điện lấy từ pin thì phải
   định nghĩa đường cấp EH, hiệu suất và cân bằng năng lượng riêng.
   Bài Drones không cung cấp ledger SWIPT BS→UAV cho mô hình này.

### Lỗi và rủi ro sẵn có cần sửa hoặc kiểm soát

9. **Tham số RF bị hardcode và có thể không nhất quán.**
   Hai hàm `src/models/findAchievableRate_SWIPT*.m` tự đặt Pr=46 dBm,
   phy=neta=0.9 và B=1e6. Các evaluator Joint không dùng sim.pr/phy/neta
   để tính pt; baseline dùng sim để ghi pt nhưng gọi hàm rate với hằng số.
   Đổi sim.phy hoặc sim.pr sẽ khiến rate và năng lượng baseline dùng hai
   công suất khác nhau; Joint có thể không đổi công suất như người dùng nghĩ.
   Với các giá trị mặc định hiện tại chúng đang khớp; đây là lỗi khi cấu hình đổi.
   T=1e-6 bên trong hiện triệt tiêu trong E_h/T, không tự gây sai hệ số thời
   gian cho RF EE hiện tại, nhưng không còn tổng quát nếu đổi tỷ lệ UL/DL.

10. **Log đang trừ hai loại fitness khác nhau.**
    `scripts/maincodeV9_EE.m:321` in Full-Joint fitness gain bằng EE Full
    trừ điểm thiếu bit âm của Joint nếu Joint chưa khả thi. Giá trị này không
    phải gain bit/J. Các log vòng lặp cũng gắn bit/J cho điểm thiếu dữ liệu.

11. **Plot cuối có thể vẽ EE nghiệm không khả thi như kết quả đạt yêu cầu.**
    `plotV9EEDiagnostics.m:19,55–57,127–139` lấy eeRF và vẽ điểm sau
    polishing/reference mean mà không lọc isFeasible. Phần đường hội tụ
    có lọc fitness âm, nhưng điểm cuối và reference chưa đồng nhất.
    `diagnoseV9_EE.m:27–40` tính lại alpha đều nhưng không kiểm tra L theo
    user, nên uniform-alpha gain chỉ là tỷ số chẩn đoán, chưa là cải thiện hợp lệ.

12. **Optimizer có thể lỗi nếu cả swarm ban đầu fitness=-Inf.**
    `optimizeTrajectory_JointPSO_SWIPT_clean.m:44,92–101`, Full PSO
    `:53,107–116`, IPSO `:60,104–113`: gbestRes bắt đầu là struct rỗng;
    -Inf > -Inf là false nên không được gán, sau đó đọc totalBits gây lỗi.
    Vi phạm dữ liệu thông thường hiện cho điểm hữu hạn, nên không đồng nhất
    trường hợp này với L cao. Nhưng lỗi dễ lộ khi thêm hard speed/budget
    constraints hoặc đầu vào gây năng lượng không hợp lệ. Cần có khởi tạo
    hợp lệ hoặc cơ chế đánh giá mức vi phạm/thoát rõ ràng.

13. **Index bằng giá trị gây lỗi khi kênh/alpha trùng.**
    `src/models/findPowCoeff.m:10–17` dùng find(h==h_sort(i)); nếu h đều
    thì mọi user bị gán lặp cùng lúc. Kiểm tra đại số với ones(1,5) cho
    fractional coefficients cuối đều 116.9375, tổng 584.6875, trái simplex.
    `findAchievableRate_SWIPT.m:30–38` cũng suy user từ equality của alpha,
    không có hoán vị SIC một-một khi alpha trùng. Baseline vẫn tính cả nhánh
    fractional dù chỉ sử dụng ach_ch. Hai hàm Joint dùng sort lấy indices
    nên không có cùng lỗi mapping này. Chưa chạy tái hiện MATLAB.

14. **Baseline evaluator thiếu kiểm tra dzMax.**
    `evaluateTrajectory_SWIPT_clean.m:33–46` chỉ kiểm tra delta_x; các
    evaluator Joint có kiểm tra delta_z. Đường baseline thẳng hiện tại không
    vi phạm, nhưng nếu dùng evaluator này để đánh giá đường khác với dzMax
    hữu hạn thì isFeasible chưa cùng nghĩa giữa các phương pháp.

15. **Ngân sách so sánh khác nhau.** Joint dùng 120 particles, hai Full dùng
    400, đều 1000 vòng; IPSO còn thêm evaluation khi mutation. Hai Full có
    polishing 20*1250 candidate và Joint không có. Đây là các cấu hình khác
    nhau có chủ đích, nhưng cùng 1000 vòng không có nghĩa cùng ngân sách.
    Khi so sánh cần báo số evaluations/thời gian, raw và sau polishing.
    Full hỗ trợ seedFullParticle nhưng main chưa truyền nghiệm Joint;
    miền Full chứa Joint không bảo đảm heuristic sẽ tìm được nghiệm tốt hơn.

16. **Biến alpha ở waypoint cuối dư trong EE hiện tại.** D_pow=T*noUsers
    nhưng chỉ có T-1 slot. Với 21 waypoint/5 user có 5 trọng số không tác
    động fitness RF hiện tại. Khi đổi lịch hover cần xác định lại mapping,
    không tự xóa vì mô hình mới có thể định nghĩa khác.

17. **Kết quả chưa lưu đủ cấu hình để tái lập tự động.** saveV9Figures chỉ
    lưu figure, không lưu sim/seeds/raw/final trong MAT hoặc manifest của
    mỗi run. mainSeed có thể được giữ từ workspace; mức L chưa được in thành
    một dòng cấu hình rõ ràng. Chuyển mô hình cần lưu thêm phiên bản mô hình
    và các thành phần năng lượng, tránh trộn với các log RF trước đây.

## Hai cách hiểu yêu cầu tích hợp

**Tái hiện sát giả định Drones:** giữ z cố định; dùng cùng v và thời gian
bay d_n/v; khai báo riêng thời gian phục vụ tại điểm; dùng công thức (11)
và E_f=P_f*D/v. Nếu đưa vào mục tiêu EE của dự án thì vẫn là bài toán EE
của dự án, không phải tái hiện toàn bộ objective/protocol của Drones.
Phải nói rõ giữ hay bổ sung năng lượng hover mà ledger đã in của bài bỏ qua.

**Giữ quỹ đạo 3D và slot 1 s:** vận tốc mỗi đoạn do hình học quyết định;
cần công suất phù hợp với chuyển động ngang/dọc và giả định gia tốc.
Đây là mở rộng, không thể gọi là chép nguyên mô hình bay ngang của Drones.

Nếu chọn dùng P_f(v_n) với độ cao cố định và tốc độ khác nhau giữa các đoạn,
đó là cách mở rộng theo các đoạn bay đều; vẫn phải nêu khác biệt với một v
chung của bài. Gán hằng P_f=108.9118 W cho mọi đường bay 20 s sẽ cho
E_f=2178.236 J giống nhau; cách đó không tạo chi phí quỹ đạo theo khoảng cách.

## Những hệ quả khi đổi mẫu số

- Propulsion dự kiến ở thang kJ, trong khi RF ở các log hiện tại chỉ cỡ µJ.
  EE mới có thể khác nhiều bậc độ lớn; cần chạy lại tối ưu để so sánh.
- Không thể suy thứ hạng thuật toán mới từ EE-RF cũ: quỹ đạo tác động thêm
  năng lượng bay, và BS gần hơn có thể tăng số bit với chi phí RF rất nhỏ
  so với propulsion. Đây là suy luận cấu trúc, chưa là kết quả chạy.
- Thêm E_f không tự giải quyết alpha về 0.2: tại quỹ đạo/BS cố định,
  E_f và RF vẫn độc lập alpha, nên lập luận sum-rate với alpha ordering
  vẫn áp dụng khi alpha đều thỏa L.
- Nếu chuyển sang P_f(v)*T bay và cộng RF lý tưởng, tên chỉ số nên diễn đạt
  đúng phạm vi, ví dụ EE theo propulsion + RF. Chưa có PA/mạch thì không
  khẳng định đã hạch toán mọi tải UAV hoặc điện pin thực.

## Kiểm tra cần có khi triển khai sau này

1. Công suất hữu hạn, dương tại hover và tốc độ hành trình; kiểm tra chuẩn
   lực đẩy, n_r và A theo rotor; ghi nhận sai khác số 108.9118 W của bài.
2. Số đoạn bằng số waypoint-1; đoạn đến cuối vào E_f dù cuối không có DL.
3. Đơn vị m/s, W, s, J; toàn bộ thời gian động cơ hoạt động được tính một lần.
4. Cùng trajectory và sim phải cho cùng physics/energy qua ba evaluator.
5. Đổi pr/phy/neta và tỷ lệ UL/DL tác động nhất quán rate, EH và RF energy.
6. Tách E_RF, E_fly, E_hover, E_total và tính EE bằng tỷ số tổng.
7. Kiểm tra QoS, budget/tốc độ, swarm toàn infeasible, và mapping user khi
   kênh bằng nhau; không diễn giải EE của nghiệm thiếu bit là kết quả khả thi.
8. Polishing phải tối ưu đúng objective mới; lịch sử/plots dùng đúng energy
   scope và kết quả raw/final; baseline V8 vẫn giữ được để đối chiếu.

Các kiểm tra trên là yêu cầu xác minh cho lần triển khai, chưa được chạy ở
lượt phân tích này. Không có thay đổi thuật toán, commit/push hoặc mô phỏng.

## Xác minh thêm nguồn tham số Flight to Efficiency → V8 → V9

Theo yêu cầu tiếp theo của người dùng, đã đọc lại toàn bộ PDF Flight to
Efficiency, xem trực quan Table I trang 5, đối chiếu hai main và hai hàm rate
active cùng hàm SWIPT Raw0 lưu trong reference. Không chạy MATLAB.

| Tham số | Flight to Efficiency | Raw0 trong repo | V8/V9 hiện tại |
|---|---|---|---|
| Công suất mỗi BS | 46 dBm | 46 dBm | 46 dBm |
| Hiệu suất EH eta | 0.7 | neta=0.9 | neta=0.9 |
| Power splitting phi | 0.7 | phy=0.9 | phy=0.9 |
| Băng thông | Không nêu trong Table I | 1 MHz | 1 MHz trong hàm rate |
| Thời gian tuyệt đối UL/DL | Mục II.C chỉ rõ hai pha bằng nhau | T=1e-6 s trong hàm | Hàm rate giữ T=1e-6; V8 main 1e-6; V9 slot 1 s, chia 0.5/0.5 |
| Reference gain beta0 | -50 dB | -50 dB trong main | -30 dB trong hai main |

Do đó không nói toàn bộ giá trị hiện tại trùng bài báo gốc. Đặc biệt .9/.9
đã có trong mã Raw0 lưu ở repo, không phải Table I .7/.7. Băng thông/thời
gian nội bộ có bằng chứng từ code, không gán thành giá trị Table I.

Các giá trị mặc định Pr, phy, neta trong V9 main và hai hàm rate hiện khớp
nhau. Chưa có sai lệch rate/energy do chúng ở cấu hình mặc định; hardcode
không tự làm giá trị sai. Rủi ro cụ thể là thay sim mà hàm vẫn dùng hằng số.

Mục II.C trang 3 cho E_H=eta*phi*P_received*T_UL và P_RF=E_H/T_DL.
Với UL=DL=0.5 s thì P_RF=eta*phi*P_received. Bởi vậy T=1e-6 nội bộ triệt
tiêu trong E_h/T, không làm công suất sai một hệ số 1e6 trong cấu hình
hiện tại; tổng EH/RF mission phải dùng thời gian 0.5 s đúng như helper.
Nếu thay tỷ lệ hai pha thì cần P_RF=eta*phi*P_received*T_UL/T_DL.

Ở cùng kênh, .9*.9/.7/.7=1.653061: công suất thu được dành cho DL lớn hơn
khoảng 65.3% so với Table I. Các giá trị .9 vẫn thuộc miền [0,1], nhưng
không tự chứng minh hiệu suất phần cứng thực ở mức RF đầu vào đang xét.
beta0 -30 so với -50 dB làm power gain mỗi link lớn hơn 100 lần ở cùng
khoảng cách/fading; đây là khác biệt scenario đáng kể, không do thêm drone.

Không có xung đột công thức bắt buộc giữa 46 dBm/1 MHz/.9/.9 và mô hình
propulsion. Công suất BS 46 dBm=39.810717 W là tại mỗi BS, không phải RF
đầu ra UAV hay công suất động cơ. Sau suy hao, log L4.2 seed3486784401 báo
RF mission Full PSO=1.242622e-5 J và IPSO=3.794910e-6 J.

Để minh họa thang năng lượng của mô hình dự kiến, đường **ngang** 300 m ở
15.521 m/s, dùng P_f tác giả báo 108.9118 W và 20 điểm hover mỗi điểm 1 s,
P_hover tự tính khoảng 172.387633 W, cho E_fly=2105.118227 J và
E_hover=3447.752666 J, cộng khoảng 5552.870893 J. Đây là ví dụ số học,
không lấy quỹ đạo 3D cũ gắn vào mô hình ngang và không là kết quả PSO mới.
Propulsion/hover ở thang kJ còn RF ở µJ sẽ làm EE giảm nhiều bậc và RF gần
như không đóng góp vào mẫu số. Đó là hệ quả hạch toán, không tự là lỗi.
