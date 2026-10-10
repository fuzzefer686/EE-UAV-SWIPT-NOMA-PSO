# Đánh giá độc lập các đại lượng V9 và cách so sánh fitness V8–V9

Ngày: 2026-09-28. Phạm vi: mã đang có trong working tree, không lấy tài liệu mô tả cũ hoặc `tauRef = 0.5` làm chuẩn vật lý. Đây là rà soát mã và suy luận toán học; chưa chạy benchmark MATLAB để kết luận mức cải thiện thực nghiệm.

**Cập nhật 2026-09-29:** Phân tích dưới đây lưu lại snapshot trước khi sửa. Bước 1 đã đổi `achRate` V9 thành `tau * phaseRate`, bỏ `tauRef`, và quy baseline/bảng benchmark về cùng rate trung bình trên toàn slot. Định nghĩa đang dùng được ghi trong README. Các nhận xét dưới đây về hệ số chuẩn hóa cũ không còn mô tả rate V9 mới.

## 1. Kết luận

V8 và V9 có thể so sánh được, nhưng phải định nghĩa cùng một đại lượng hiệu năng, cùng thời gian phục vụ, cùng mô hình vật lý và cùng cách chấm điểm. Thước đo tự nhiên cho downlink là số bit truyền được chia cho toàn bộ thời gian slot, bao gồm thời gian dành cho pha BS–UAV.

Nếu V8 thực sự dùng hai pha bằng nhau, các `achRate` hiện tại của cả V8 lẫn V9 đều bằng hai lần rate trung bình trên toàn slot. Vì vậy hệ số 2 hiện tại không tự tạo lợi thế cho V9. Với nghiệm khả thi, `lambdaSmooth = 0` và cùng hàm fitness Joint/Full, thứ hạng và phần trăm cải thiện fitness được giữ khi cả hai chuyển về rate vật lý (bỏ qua sai khác số học rất nhỏ do `eps`).

Điều này không biến `tauRef` thành một chuẩn vật lý. Tính hợp lệ đến từ giả định hai pha của V8 và việc áp dụng cùng thước đo cho cả hai bản. Hiện có các vấn đề độc lập với chuẩn hóa: ngân sách chạy khác nhau, thời lượng dùng để ghi nhận năng lượng khác nhau, endpoint không nằm trong objective, và polish alpha không kiểm tra fitness tổng trước khi nhận nghiệm.

## 2. Các đại lượng V9, xây dựng từ thời gian và năng lượng

Gọi toàn bộ thời lượng slot là Δt; k là user; t là chỉ số slot. Trong mô hình hai pha hiện tại, τ_t là phần thời gian dành cho UAV truyền xuống user:

\[
T_{\mathrm{DL},t}=\tau_t\Delta t,\qquad
T_{\mathrm{UL/EH},t}=(1-\tau_t)\Delta t.
\]

Pha đầu có thể đồng thời nhận dữ liệu và thu năng lượng theo SWIPT. Tuy nhiên pipeline hiện tại chỉ tính năng lượng nhận từ BS, chưa tính giới hạn dữ liệu đi vào UAV.

Đặt q_t là công suất thu hoạch hữu dụng khi pha đầu đang hoạt động:

\[
q_t=\eta\phi\sum_m P_{\mathrm{BS},m}|h_{m,t}|^2.
\]

Với giả định dùng hết năng lượng thu được trong slot cho phát RF, không tính mạch, tổn hao bộ khuếch đại bổ sung hoặc năng lượng chuyển sang slot sau:

\[
E_{h,t}=q_t(1-\tau_t)\Delta t,\qquad
P_{\mathrm{UAV},t}=\frac{E_{h,t}}{\tau_t\Delta t}
=q_t\frac{1-\tau_t}{\tau_t}.
\]

Khi τ thay đổi, công suất thay đổi, nên SINR và tốc độ trong pha truyền cũng thay đổi. Không được xem tốc độ đó là hằng số khi tối ưu τ.

| Biến đang dùng | Ý nghĩa | Đơn vị |
|---|---|---|
| `tau(t)` | Tỷ lệ thời gian downlink; hiện bị giới hạn trong [0.01, 0.99] | Không có |
| `EH(t)` | Năng lượng UAV thu được trong pha đầu của slot | J |
| `pt(t)` | Công suất RF của UAV khi đang truyền downlink | W |
| `spectralRate(t,k)` | C_tk = B log₂(1 + SINR_tk), tốc độ trong pha downlink | bit/s |
| `physicalAverageRate(t,k)` | r_tk = τ_t C_tk, tốc độ trung bình tính trên toàn slot | bit/s |
| `bitsPerSlot(t,k)` | D_tk = Δt r_tk, lượng bit có thể truyền theo mô hình | bit |
| `achRate(t,k)` | Đại lượng chấm điểm được chuẩn hóa; hiện bằng 2 r_tk | bit/s theo quy ước chuẩn hóa |

`spectralRate` là tên dễ gây hiểu nhầm: code đã nhân B, nên đây không phải spectral efficiency (bit/s/Hz). Tên `phaseRate` hoặc `instantaneousDownlinkRate` sẽ rõ hơn. `EH` và `pt` đã tồn tại ở V8; điểm mới là sự phụ thuộc vào τ.

Ví dụ minh họa, không phải kết quả mô phỏng: một slot dài 1 s, τ = 0.3 và C = 4 Mbit/s tại cấu hình đó cho D = 1.2 Mbit và r = 1.2 Mbit/s. Giá trị `achRate` hiện tại là 2.4 theo thang chuẩn hóa. Ví dụ không giả định C giữ nguyên nếu đổi τ.

Không có nhu cầu L, mô hình được hiểu là luôn có đủ dữ liệu để truyền. `bitsPerSlot` là lượng dữ liệu có thể phục vụ với achievable rate đang tính, không phải số bit ứng dụng đã được kiểm chứng bằng mô phỏng gói tin.

Nguồn mã: [evaluateTauPower_V9.m](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/src/models/evaluateTauPower_V9.m:11), [evaluateTauStep_V9.m](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/src/models/evaluateTauStep_V9.m:37).

## 3. Thước đo chung không cần tauRef

Định nghĩa rate trung bình bằng số bit chia cho tổng thời gian:

\[
r_{t,k}=\frac{D_{t,k}}{\Delta t}.
\]

Nếu baseline có tỷ lệ downlink cố định ρ, thì:

\[
r^{(8)}_{t,k}=\rho C^{(8)}_{t,k},\qquad
r^{(9)}_{t,k}=\tau_t C^{(9)}_{t,k}.
\]

ρ phải xuất phát từ lịch truyền của baseline. Bài *Flight to Efficiency*, trang 3, mục C và chú thích 1, giả định uplink và downlink có thời lượng bằng nhau. Trong mô hình hai pha không có khoảng phụ thêm, điều này cho ρ = 1/2. Đây là căn cứ cho baseline 50/50, độc lập với biến `tauRef` trong code.

Với lịch truyền đó, V8 trả về C8 trong `achRate`, còn V9 trả về 2τC9. Suy ra:

\[
\texttt{achRate}_8=2r_8,\qquad
\texttt{achRate}_9=2r_9.
\]

Do đó:

- Không có việc chỉ V9 được nhân đôi so với đại lượng vật lý còn V8 thì không.
- Có thể quy đổi hai bản về r trước khi so sánh và vẽ biểu đồ.
- Chỉ xóa phép chia 0.5 ở V9 nhưng giữ nguyên `achRate` V8 sẽ tạo hai thang đo khác nhau.
- Kiểm tra V9 bằng V8 khi τ = 0.5 chỉ xác nhận tương thích của code. Tự nó không chứng minh mô hình vật lý hoặc tính đúng của năng lượng.

Ví dụ minh họa: V8 có C8 = 10 Mbit/s và ρ = 0.5, nên r8 = 5 Mbit/s. V9 có C9 = 8 Mbit/s ở τ = 0.8, nên r9 = 6.4 Mbit/s. Cải thiện rate trung bình là 28%; so các giá trị chuẩn hóa 10 và 12.8 cũng cho 28%. Đây chỉ là minh họa phép quy đổi, không phải một cặp nghiệm mô phỏng.

## 4. Fitness hiện tại thực sự đánh giá gì?

Với tập slot được chấm điểm I, đặt:

\[
m=\min_{t\in I,k}r_{t,k},\qquad
\mu=\frac{1}{|I|}\sum_{t\in I}\min_k r_{t,k}.
\]

m là rate thấp nhất trong mọi user và mọi slot được xét. μ là trung bình theo thời gian của rate user yếu nhất từng slot. **μ không phải trung bình rate của tất cả users và cũng không phải tổng throughput.**

J_t là chỉ số Jain giữa các users trong slot t. Với các trọng số mặc định và nghiệm khả thi, không phạt độ gấp khúc:

\[
F=m+0.05\mu-0.1\mu(1-\overline J).
\]

Đây là điểm tổng hợp do người thiết kế lựa chọn, có thang đo theo rate. Nó không phải một tốc độ truyền riêng, không phải tổng dữ liệu, và chưa phải EE. Nó cũng không phải ưu tiên max-min tuyệt đối: các thành phần phụ vẫn có thể đổi thứ hạng của hai nghiệm có m gần nhau.

Khi tất cả r được nhân cùng hằng số dương a, m và μ nhân a, còn Jain không đổi. Vì vậy F nhân a trong cấu hình khả thi, `lambdaSmooth = 0`. Điều này giải thích vì sao chuẩn hóa chung không làm đổi thứ hạng và phần trăm tăng fitness. Nếu giữ penalty hoặc smoothness cố định trong khi đổi thang rate, kết luận này không còn áp dụng trực tiếp; phải chuẩn hóa lại các hệ số hoặc xử lý feasibility riêng.

Một điểm đáng xem lại trong thiết kế trọng số:

\[
F=m+(0.1\overline J-0.05)\mu.
\]

Nếu Jain trung bình dưới 0.5, hệ số của μ là âm. Khi giữ m và Jain cố định, tăng μ lúc đó lại làm giảm F. Đây là hệ quả toán học của trọng số hiện có, không phải lỗi riêng V9; chưa có bằng chứng rằng các nghiệm đang chạy thực sự rơi vào trường hợp này. Vì vậy nên báo cáo m, μ và Jain riêng, không chỉ một fitness.

Nguồn mã: [fitness Joint+BS](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/src/evaluators/evaluateTrajectory_JointBS_SWIPT_V9.m:206).

### Hai mục tiêu khác nhau cần phân biệt

Nếu cần duy trì chất lượng ở mọi slot, dùng min_t,k r_tk phù hợp với mục tiêu bảo vệ thời điểm xấu nhất. Nếu phục vụ file trong toàn nhiệm vụ, đại lượng min_k Σ_t D_tk / Σ_t Δt đánh giá user có throughput trung bình thấp nhất sẽ phù hợp hơn.

Hai tiêu chí có thể xếp hạng ngược nhau. Với 2 slot bằng nhau và 2 users, nghiệm A có rate (1,9) rồi (9,1); nghiệm B có (4,4) ở cả hai slot. Worst-slot rate ưu tiên B (4 > 1), còn worst-user average rate ưu tiên A (5 > 4). Đổi thứ tự phép cộng và phép min là đổi bài toán nghiên cứu, không chỉ đổi cách trình bày.

Jain trung bình từng slot cũng khác Jain tính trên tổng bit mỗi user. Khi đánh giá nhiệm vụ, nên ghi rõ loại fairness được báo cáo.

## 5. Các vấn đề cụ thể trong phép so sánh hiện tại

### 5.1 Hai script chính đang dùng ngân sách khác nhau

[V8](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/scripts/main/maincodev8nUser.m:161) dùng 1000 vòng; [V9](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/scripts/main/maincodeV9_DTS.m:162) dùng 750 vòng cho Joint PSO, Full PSO và Full IPSO. README còn mô tả V9 chạy 1000 vòng, không khớp snapshot mã đang đọc.

Hàm [benchmark_v8_v9_fair](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/scripts/benchmarks/benchmark_v8_v9_fair.m:23) là hướng tốt hơn: tạo cùng scenario và truyền cùng số hạt/vòng cho cặp V8/V9. Tuy nhiên số lần đánh giá fitness của IPSO có thể khác do mutation. Nên so cùng ngân sách đánh giá và báo thêm thời gian thực thi, tính cả polish. Thời gian đo bằng profiler trong benchmark có overhead của profiler.

### 5.2 Cùng công suất ở τ = 0.5 nhưng năng lượng đang khác nhau

V8 lưu `EH = pt * sim.Tslot` tại [evaluator V8](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/src/evaluators/evaluateTrajectory_JointBS_SWIPT_clean.m:190). V9 dùng `EH = pt * tau * sim.Tslot` theo mô hình năng lượng.

Cùng kênh, alpha, `sim.Tslot` và τ = 0.5:

\[
P_8=P_9,\qquad E_{H,8}=2E_{H,9}.
\]

V8 đang ghi năng lượng tương ứng với thời gian của một pha; V9 dùng `Tslot` cho cả chu kỳ. Không được kết luận V9 tiết kiệm 50% năng lượng từ chênh lệch này. Cần định nghĩa Δt chung và tính lại năng lượng cho cả hai theo thời gian hoạt động của từng pha. Nếu giữ thời lượng mỗi pha V8 cũ bằng 1 microsecond, chu kỳ V9 tương đương ở τ = 0.5 phải dài 2 microsecond; nếu chọn chu kỳ chung 1 microsecond thì mỗi pha V8 dài 0.5 microsecond.

Kiểm thử [test_v9_rewrite](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/scripts/benchmarks/test_v9_rewrite.m:20) có so sánh fitness, rate, công suất, nhưng không so sánh `EH` giữa V8 và V9.

### 5.3 Thời gian truyền chưa gắn với chuyển động vật lý

`Tslot = 1e-6 s`, nhưng các waypoint cách nhau 15 m theo y. Không thể dùng hai con số này làm thời lượng và dịch chuyển của cùng một đoạn bay. `pt` và rate có thể không đổi khi đổi Δt vì Δt triệt tiêu trong công thức công suất; số bit và năng lượng mỗi slot thì thay đổi.

Cần xác định rõ N waypoint tương ứng N−1 khoảng bay hay N vị trí phục vụ với dwell time riêng. Khi đánh giá toàn nhiệm vụ, không được lấy thời gian N−1 khoảng bay nhưng cộng dữ liệu của N slot đủ độ dài mà không giải thích cách tích phân hoặc thời gian dừng.

### 5.4 Tập slot tối ưu và tập slot báo cáo chưa nhất quán

Mặc định fitness dùng 19 slot nội bộ trong tổng số 21 vị trí. `globalMinRate` lại lấy min cả 21 vị trí, còn `mean(pt)` và `mean(tau)` cũng thường lấy toàn bộ.

V9 vẫn có biến τ và alpha ở hai endpoint, nhưng các biến này không được fitness nội bộ đánh giá và không có ràng buộc pin liên slot để kết nối chúng với phần nội bộ. Vì vậy rate ở endpoint có thể rất kém dù fitness tốt. Alpha polishing mặc định cũng chỉ xử lý các slot nội bộ.

Chọn một tập slot phục vụ chung cho báo cáo chính. Nếu endpoint có phục vụ, cần đưa chúng vào bài toán thích hợp; nếu chỉ là mốc đường bay thì không cộng dữ liệu hoặc thời gian phục vụ một cách tùy ý. Lưu ý evaluator Joint không tối ưu BS hiện cố định dùng slot nội bộ, trong khi evaluator Full đọc `fitnessStepMode`; chỉ đổi cờ này chưa đồng bộ tất cả pipeline.

### 5.5 Alpha polishing không bảo đảm tăng fitness toàn cục

[Polisher V9](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/src/optimizers/postprocessing/polishAlphaAllSteps_JointBS_V9.m:62) bỏ qua fitness trả về khi xét ứng viên; chọn theo min-rate tại một slot rồi dùng độ chênh lệch giữa users để phá hòa. Trong khi đó fitness chính còn có Jain và trung bình trên các slot.

Vì thế không có bảo đảm toán học rằng fitness cuối tăng. Cấu trúc này cũng tồn tại ở polisher V8. Nên nhận ứng viên theo fitness chung nếu mục tiêu là cải thiện fitness, hoặc công bố rõ rằng polish phục vụ một mục tiêu khác và báo các metric trước/sau.

Polisher còn gán `bestHistory(end) = fitFinal` tại dòng 95. Điểm cuối biểu đồ hội tụ vì vậy trộn kết quả PSO/IPSO với chi phí hậu xử lý. Nên đánh dấu kết quả polish riêng và tính ngân sách của nó.

### 5.6 Các loại baseline chưa dùng hoàn toàn cùng hàm chấm điểm

Baseline quỹ đạo thẳng được tính bằng [evaluateTrajectory_SWIPT_clean](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/src/evaluators/evaluateTrajectory_SWIPT_clean.m:140), không có fairness penalty. Joint/Full có fairness penalty. Do đó nếu đặt các fitness này cạnh nhau, chúng không cùng một công thức chấm điểm.

Điều này khác với phép so Joint V8–Joint V9 hoặc Full V8–Full V9, vốn có cùng cấu trúc fitness. Muốn so tất cả baseline, cần tính lại cùng metric chung từ các rate. Baseline thẳng cũng dùng quy tắc alpha riêng, nên không đủ để tách tác dụng riêng của τ.

### 5.7 Một số tham số V8 được hard-code

[findAchievableRate_SWIPT_Joint](/Users/fuzzefer/Documents/MATLAB/UAV/uav-swipt-noma-trajectory-optimization/src/models/findAchievableRate_SWIPT_Joint.m:10) tự đặt công suất BS 46 dBm, phi = 0.9 và eta = 0.9. V9 đọc các tham số tương ứng từ `sim`.

Tại cấu hình mặc định, các giá trị khớp nhau. Nếu sweep `sim.pr`, `sim.phy`, `sim.neta` mà không cập nhật V8, hai bản sẽ không còn mô phỏng cùng điều kiện dù nhận cùng một struct `sim`.

### 5.8 Fitness downlink chưa chứng minh hiệu năng toàn hệ thống hay EE

Mã hiện chưa có ràng buộc dữ liệu BS–UAV, nhu cầu L, năng lượng bay, năng lượng mạch hoặc giới hạn công suất RF riêng. `sim.pMax = 1` giới hạn biến raw alpha trong optimizer, không phải công suất phát UAV tối đa tính bằng W. `evaluateTauPower_V9` hiện không cắt ngưỡng công suất.

Các giả định này không tự làm phép so downlink giữa hai bản vô nghĩa nếu cùng áp dụng. Tuy nhiên, khi τ tăng, pha nhận dữ liệu từ BS ngắn lại; bỏ qua nguồn dữ liệu có thể làm đánh giá quá cao throughput đầu cuối. Cần giới hạn phạm vi kết luận ở downlink với dữ liệu sẵn có, hoặc bổ sung cùng mô hình luồng dữ liệu cho cả hai.

`mean(pt)` chỉ là trung bình công suất lúc phát theo các slot, không phải năng lượng. Với các slot dài bằng nhau, công suất RF trung bình trên toàn thời gian phục vụ là mean(τ .* pt). Khi tính EE, dùng tổng bit chia tổng năng lượng, không dùng trung bình các EE từng slot.

## 6. Cách so sánh nên thực hiện

1. Chốt Δt, tập slot phục vụ, mô hình năng lượng và cùng các giới hạn vật lý. Baseline V8 dùng lịch 50/50 xuất phát từ giả định hai pha bằng nhau.
2. Tạo một evaluator báo cáo chung từ r và D; cho cả V8 và V9 cùng đi qua evaluator này. Tối thiểu báo worst-slot rate, worst-user average rate, tổng bit, fairness và feasibility; fitness hỗn hợp được ghi riêng.
3. Tách câu hỏi “DTS có lợi không?” khỏi “PSO/IPSO nào tìm nghiệm tốt hơn?”. So V8 đã tối ưu với cùng nghiệm đó chỉ tối ưu τ; sau đó so với nghiệm đồng tối ưu quỹ đạo, alpha, BS và τ. Nếu dùng thêm baseline τ cố định khác, phải tối ưu các biến còn lại theo cùng ngân sách.
4. Dùng cùng scenario/user/channel cho từng cặp; chạy nhiều seed optimizer. Cùng RNG seed không tạo ra cùng quần thể ban đầu khi V9 tiêu thụ thêm số ngẫu nhiên cho τ. Nếu muốn ghép cặp khởi tạo thật sự, cần tạo chung các block biến cũ rồi nối τ.
5. So trong cùng ngân sách evaluator, kèm thời gian chạy và chi phí polish. Báo cải thiện theo từng cặp scenario, trung vị/trung bình, độ phân tán và số lần V9 thắng; không kết luận từ một seed tốt nhất.
6. Công bố rate vật lý và các thành phần fitness bằng nhãn rõ ràng. Nếu giữ thang chuẩn hóa cũ để đối chiếu lịch sử, ghi rõ hệ số quy đổi và không gọi nó là rate trung bình trên toàn slot.

V9 có thêm 21 biến τ: Full tăng từ 149 lên 170 phần tử particle. Với cùng giả định và mục tiêu, tập nghiệm V9 chứa V8 thông qua τ_t = 0.5. Vì vậy optimum toàn cục của bài toán mở rộng không thấp hơn baseline. PSO/IPSO với ngân sách hữu hạn không có bảo đảm đạt optimum đó; thêm biến có thể khiến tìm kiếm khó hơn. Chênh lệch fitness quan sát được kết hợp cả lợi ích mô hình và chất lượng tìm kiếm.

## 7. Giới hạn kết luận và nguồn

Đã đọc mã mô hình, evaluator, script chính, optimizer, polisher, benchmark và kiểm thử tương thích. Đã đối chiếu trực quan trang 3–4 của bài gốc và kiểm tra số học minh họa bằng Python. Không chạy lại tối ưu MATLAB; không khẳng định phần trăm cải thiện thực nghiệm nào. Các tài liệu cũ về Golden Search không mô tả pipeline V9 hiện tại: τ đang là một block của particle PSO/IPSO.

Nguồn vật lý gốc: *Flight to Efficiency: Trajectory Optimization in SWIPT-Enabled UAV-Assisted NOMA for Future Wireless Networks*, mục C và chú thích 1 trang 3 (hai pha bằng nhau), mục G trang 4 (mục tiêu min achievable rate).

Tài liệu nghiên cứu liên quan để phân biệt throughput trên nhiệm vụ và causality: [Throughput Maximization for UAV-Enabled Wireless Powered Communication Networks](https://arxiv.org/abs/1801.04545) xét minimum throughput trên một thời gian bay hữu hạn; [Throughput Maximization for UAV-Enabled Relaying in Wireless Powered Communication Networks](https://www.mdpi.com/1424-8220/19/13/2989) nêu ràng buộc nhân quả dữ liệu khi UAV chuyển tiếp. Các tài liệu này không được dùng làm bằng chứng rằng code V9 hiện tại đã cải thiện hiệu năng.
