# Phân tích campaign V10A/V10B ngày 29/10/2026

Reference files read: `matlab-analyze-data/references/exploration.md`, `grouping-and-aggregation.md`, `answering-data-questions.md`. Áp dụng thêm skill `statistical-analysis`, `data-visualization` và `verification-before-completion`.

**Kết quả chính:** Full IPSO đạt mọi ràng buộc ở 54/54 lượt chạy. V10B tạo mức EE cao hơn V10A, đi kèm giảm độ công bằng dữ liệu giữa user. Các kết quả cho thấy lợi ích của tối ưu hình học và BS, nhưng chưa đủ để khẳng định hội tụ toàn cục hoặc độ ổn định qua nhiều seed của chính thuật toán.

## 1. Nguồn dữ liệu và cách kiểm tra

Nhánh `feature/ee-optimization`, commit đang xem `309b7bf` (`added V10 alpha run`). Nguồn chính là [campaign_summary.csv](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/results/v10/campaign_20261029_125559/campaign_summary.csv), `campaign.mat` cùng 54 file `results.mat` được chính campaign tham chiếu. Không trộn các lượt chạy V10 cũ ngoài campaign. Không chạy lại MATLAB hoặc PSO; chỉ đọc dữ liệu đã lưu bằng Python/HDF5.

Campaign lưu profile **quick**, **120 particles × 1.000 iterations**, seed thuật toán **151459287**, seed polishing **152459287**, budget **17.000 J**, cruise power **108,940787 W**, hover power **172,387633 W**. Đây là thông số đọc từ MAT đã chạy, không suy từ entry point hiện tại. `maincodeV10Campaign.m` hiện được chỉnh sang 6 lượt, nên không dùng nó để suy ngược cấu hình của campaign 54 lượt này.

Đã xác minh: đủ 216 dòng/54 thư mục, không có lỗi chạy được ghi nhận; CSV khớp các trường kết quả đã đối chiếu trong MAT; tổng bit theo user-slot, tổng năng lượng các thành phần, EE=bit/J và Jain tính lại khớp dữ liệu. Lịch sử mỗi optimizer có 1.001 điểm, fitness tốt nhất không giảm. Vị trí user và mẫu fading giống nhau giữa A/B và các sweep ở cùng scenario seed. Chi tiết nằm trong `mat_csv_audit.csv` và `run_config_audit.csv`.

## 2. 54 lượt gồm những gì?

`2 biến thể × 3 scenario seed × 9 cấu hình có nhãn = 54 lượt`; mỗi lượt chứa Baseline, Joint PSO, Full PSO và Full IPSO, tổng 216 kết quả. Scenario seeds: **2026, 608060, 3486784401**.

| Sweep | Các giá trị thay đổi | Giữ cố định |
| --- | --- | --- |
| L | 1, 2, 3 Mbit/user | user-slot=5 kbit; hover=1 s |
| User-slot | 0, 5, 10 kbit/user/serving-slot | L=3 Mbit/user; hover=1 s |
| Hover | 1, 2, 3 s/điểm phục vụ | L=3 Mbit/user; user-slot=5 kbit |

Ba nhãn **L=3M, slot=5k, hover=1s trùng hoàn toàn bộ tham số**. Các chỉ số kết quả đã kiểm tra cũng giống nhau, vì RNG được reset về cùng seed. Do đó chỉ có **7 bộ tham số khác nhau mỗi seed/biến thể**, tức **42 tổ hợp khác nhau và 168 kết quả phương pháp**. Có 12 lượt lặp bộ tham số. Khi tổng hợp chung bên dưới, loại trùng theo `(variant, seed, L, user-slot, hover, algorithm)` để không làm bộ mặc định có trọng số gấp ba. Đây vẫn không phải 42 quan sát thống kê độc lập: nhiều tổ hợp dùng chung scenario.

## 3. Tỷ lệ tìm được nghiệm khả thi

| Phương pháp | A: toàn campaign | B: toàn campaign | Tổng/54 | A: loại trùng | B: loại trùng |
| --- | --- | --- | --- | --- | --- |
| Baseline | 1/27 | 1/27 | 2/54 | 1/21 | 1/21 |
| Joint PSO | 10/27 | 16/27 | 26/54 | 10/21 | 14/21 |
| Full PSO | 26/27 | 27/27 | 53/54 | 20/21 | 21/21 |
| Full IPSO | 27/27 | 27/27 | 54/54 | 21/21 | 21/21 |

“Không khả thi” ở đây nghĩa là phương pháp **chưa tìm được nghiệm đạt mọi ràng buộc trong ngân sách chạy này**; không chứng minh bài toán bất khả thi. Trên 42 tổ hợp sau loại trùng, không có trường hợp nào vi phạm budget hoặc hình học. Trở ngại là lượng dữ liệu tổng và lượng dữ liệu tối thiểu từng user-slot.

Full PSO thất bại duy nhất ở **A, seed 2026, L=3 Mbit, user-slot=10 kbit, hover=1 s**: cả 5 user đủ L, nhưng **2/100 user-slot** thiếu, tổng thiếu **11.859,98 bit**, slot thấp nhất **1.421,79 bit**. EE tính được là **1.564,35 bit/J**, song không được xem là nghiệm đạt yêu cầu. Full IPSO cùng trường hợp đạt **4.133,53 bit/J** và thỏa mọi ràng buộc.

Baseline là quỹ đạo thẳng với **alpha theo kênh**, không phải baseline chia alpha đều. Joint giữ BS cố định, Full tối ưu cả vị trí BS. So sánh Joint–Full gồm cả khác biệt không gian tìm kiếm và phần polishing chỉ có ở Full; không quy toàn bộ gain đó cho một cải tiến PSO đơn lẻ.

## 4. Full IPSO hơn Full PSO bao nhiêu?

So sánh ghép đúng scenario seed và bộ tham số; chỉ đưa vào phép so EE các cặp mà cả hai đều khả thi. Phần trăm bên dưới là **trung bình các tỷ lệ từng cặp**, không phải tỷ lệ của hai trung bình.

| Biến thể | Số cặp | IPSO thắng/thua | Gain EE trung bình | Gain trung vị | Khoảng gain |
| --- | --- | --- | --- | --- | --- |
| A | 20 | 19 / 1 | +6,33% | +2,93% | −4,88% đến +62,53% |
| B | 21 | 16 / 5 | +17,61% | +6,10% | −16,54% đến +88,60% |

IPSO có lợi thế tổng thể và về khả năng tìm nghiệm khả thi, nhưng **không thắng mọi lần**. Ví dụ A/seed2026/hover2s: PSO=8.553,03 so với IPSO=8.135,42 bit/J. Mức EE lớn nhất toàn campaign cũng thuộc **B + Full PSO, seed2026, hover3s: 16.901,86 bit/J**, cao hơn IPSO cùng bộ tham số 16.392,53 bit/J. Không dùng một kỷ lục riêng lẻ để xếp hạng tổng thể.

## 5. Lợi ích của V10B và đánh đổi fairness

A giữ lưới Y đều, tối ưu X; B tối ưu X/Y với tiến Y tối thiểu 1 m/đoạn. Với Full IPSO, cả A/B đều đạt yêu cầu trên đủ 21 cặp sau loại trùng, nên so sánh trực tiếp được:

| Chỉ số, trung bình 21 tổ hợp | V10A + Full IPSO | V10B + Full IPSO |
| --- | --- | --- |
| EE (bit/J) | 6.452,96 | 9.956,75 |
| Tổng bit (Mbit) | 59,58 | 84,51 |
| Năng lượng UAV (J) | 8.749,74 | 8.052,59 |
| Chiều dài bay (m) | 544,87 | 445,54 |
| Jain fairness | 0,749 | 0,569 |

B cao hơn A ở **21/21 cặp**, gain EE ghép cặp trung bình **55,79%**, trung vị **42,92%**. Theo tỷ lệ của hai trung bình EE, gain là **54,30%**; hai cách tính khác nhau. Gain ghép cặp của tổng bit là **+42,40%**, năng lượng **−7,79%**, chiều dài **−16,84%**. Vì vậy lợi ích gồm cả tăng dữ liệu lẫn giảm đường bay/năng lượng, với phần tăng dữ liệu nổi bật.

Dữ liệu quỹ đạo mặc định cho thấy A tiến đều 15 m theo Y mỗi đoạn, còn B có nhiều đoạn xấp xỉ 1 m xen các đoạn dài. Điều này phù hợp với việc B gom nhiều điểm phục vụ vào vùng kênh có lợi. Tuy nhiên, chưa có thí nghiệm cố định từng thành phần để tách riêng đóng góp của hình học, BS, alpha và cách tìm nghiệm.

Jain thấp hơn phản ánh dữ liệu tập trung vào một số user. Đây là hệ quả phù hợp với mục tiêu tối đa **tổng bit/tổng năng lượng**, trong khi các user còn lại chỉ cần đạt ngưỡng tối thiểu. Ví dụ điểm EE kỷ lục B/PSO/seed2026/hover3s có Jain **0,380**; B/IPSO cùng bộ có Jain **0,329**. Cần trình bày EE và fairness cạnh nhau khi báo cáo kết quả.

![Năng lượng và fairness](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/energy_fairness.png)

## 6. Độ nhạy theo L, user-slot và hover

Bảng sau lấy trung bình trên ba scenario seeds, **chỉ các nghiệm khả thi**. Số trong ngoặc là số nghiệm khả thi/3; dấu “—” nghĩa là không có. Vì số seed còn lại có thể khác nhau, không so trực tiếp các trung bình lệch mẫu để kết luận hơn kém.

| Biến thể | Cấu hình | Joint EE (bit/J) | Full PSO EE | Full IPSO EE |
| --- | --- | --- | --- | --- |
| A | L=1M | 2.236,1 (3/3) | 6.041,6 (3/3) | 6.082,9 (3/3) |
| A | L=2M | 2.418,8 (1/3) | 5.624,1 (3/3) | 5.857,0 (3/3) |
| A | L=3M | — (0/3) | 5.420,5 (3/3) | 5.649,7 (3/3) |
| A | slot=0k | — (0/3) | 4.417,0 (3/3) | 5.500,2 (3/3) |
| A | slot=5k | — (0/3) | 5.420,5 (3/3) | 5.649,7 (3/3) |
| A | slot=10k | — (0/3) | 5.406,2 (2/3) | 5.097,3 (3/3) |
| A | hover=1s | — (0/3) | 5.420,5 (3/3) | 5.649,7 (3/3) |
| A | hover=2s | 2.542,2 (3/3) | 7.916,3 (3/3) | 7.787,0 (3/3) |
| A | hover=3s | 3.313,8 (3/3) | 8.917,9 (3/3) | 9.196,5 (3/3) |
| B | L=1M | 3.438,0 (3/3) | 8.721,0 (3/3) | 8.343,6 (3/3) |
| B | L=2M | 2.549,2 (2/3) | 7.157,0 (3/3) | 9.360,2 (3/3) |
| B | L=3M | 1.876,0 (1/3) | 7.556,7 (3/3) | 9.390,4 (3/3) |
| B | slot=0k | 1.500,1 (1/3) | 7.034,8 (3/3) | 8.875,2 (3/3) |
| B | slot=5k | 1.876,0 (1/3) | 7.556,7 (3/3) | 9.390,4 (3/3) |
| B | slot=10k | 2.680,2 (1/3) | 7.019,1 (3/3) | 8.073,6 (3/3) |
| B | hover=1s | 1.876,0 (1/3) | 7.556,7 (3/3) | 9.390,4 (3/3) |
| B | hover=2s | 3.917,0 (3/3) | 11.125,5 (3/3) | 12.021,8 (3/3) |
| B | hover=3s | 5.200,0 (3/3) | 13.671,9 (3/3) | 13.632,3 (3/3) |

**Tăng L:** với A/IPSO, EE giảm 6.082,93 → 5.856,99 → 5.649,71 bit/J. Joint A đạt 3/3 ở L=1M, 1/3 ở L=2M và 0/3 ở L=3M. Với B/IPSO, EE lại tăng 8.343,62 → 9.360,22 → 9.390,43. Không diễn giải thành “thắt ràng buộc làm tăng optimum”: khi chỉ tăng L, miền khả thi thu hẹp và optimum thật không thể tăng. Đây là dấu hiệu kết quả phụ thuộc đường tìm kiếm, nghiệm cục bộ và ngân sách hữu hạn.

**Tăng user-slot từ 5 lên 10 kbit:** IPSO A giảm **9,78%** theo tỷ lệ trung bình, B giảm **14,02%**; cả hai vẫn đạt 3/3. Ở B/IPSO mặc định, giá trị user-slot thấp nhất lần lượt khoảng **5.346**, **9.302**, **12.960 bit** cho ba seed, cho thấy ngưỡng 5 kbit có tác dụng rõ ở seed2026. So sánh 0 với 5 kbit cho EE tăng trong kết quả tìm được cũng là ảnh hưởng tìm kiếm; bỏ ràng buộc không làm optimum thật xấu đi.

**Tăng hover:** IPSO A: 5.649,71 → 7.787,04 → 9.196,52 bit/J; B: 9.390,43 → 12.021,76 → 13.632,34. Nhưng nhiệm vụ dài hơn và tiêu thụ nhiều năng lượng hơn. A/IPSO trung bình: **55,96 → 76,50 → 93,91 s**, năng lượng **7,37 → 10,87 → 14,04 kJ**. B/IPSO: **46,93 → 68,77 → 85,58 s**, **6,38 → 10,03 → 13,13 kJ**. Dữ liệu truyền tăng theo thời gian phục vụ, làm chi phí bay được phân bổ trên nhiều bit hơn. Chưa có ràng buộc deadline hay cơ chế tối ưu hover liên tục, nên không kết luận “hover càng lâu càng tốt” hoặc “3 s là tối ưu”.

![Các sweep của campaign](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/sweep_comparison.png)

## 7. Alpha: 0,2 không phải dấu hiệu thuật toán lỗi

`alphaMean=0,2` trong CSV là trung bình trên toàn bộ 20 slot × 5 user. Với tổng alpha mỗi slot bằng 1, trung bình này luôn bằng 1/5 kể cả các slot phân bổ rất lệch. Cần xem `alphaTrace`, độ lệch lớn nhất so với 0,2, hoặc số slot hoàn toàn chia đều.

Sau loại trùng, Full IPSO có **10/21 nghiệm A và 13/21 nghiệm B** mà cả 20 serving-slot đều chia alpha=0,2 trong sai số 1e−8. A/IPSO ở L=1M và hover3s đều chia đều toàn bộ; B/IPSO ở hover2s và hover3s cũng vậy. Các bộ mặc định L=3M/5k/1s vẫn có alpha khác đều. Như vậy các ràng buộc không ép alpha khác đều ở mọi cấu hình.

Chia đều công suất không đồng nghĩa chia đều bit: kênh và thứ tự SIC khác nhau. B/IPSO hover3s vẫn có Jain trung bình **0,489** dù tất cả các serving-slot của cả ba seed chia alpha đều. Nếu mục tiêu nghiên cứu là công bằng dữ liệu, alpha khác 0,2 không phải thước đo đủ; cần Jain, bit nhỏ nhất và bit thiếu từng user.

## 8. Đóng góp của alpha polishing

So trực tiếp `trajFullRaw`/`trajIPSORaw` với kết quả cuối. Các hàng sau dùng các nghiệm cuối khả thi; tất cả cũng khả thi trước polishing. Gain là trung bình phần trăm mỗi lượt.

| Biến thể/phương pháp | n | EE raw trung bình | EE cuối trung bình | Gain polishing TB | Gain trung vị |
| --- | --- | --- | --- | --- | --- |
| A / Full PSO | 20 | 6.231,27 | 6.291,22 | 1,064% | 0,373% |
| A / Full IPSO | 21 | 6.450,70 | 6.452,96 | 0,041% | 0,000% |
| B / Full PSO | 21 | 8.466,55 | 8.897,99 | 7,025% | 3,923% |
| B / Full IPSO | 21 | 9.846,19 | 9.956,75 | 1,237% | 0,143% |

Polishing **không cứu** trường hợp A/PSO/seed2026/user-slot10k còn vi phạm. Gain của IPSO phần lớn đã có trước polishing; polishing đóng góp nhiều hơn cho B/PSO, với mức cao nhất khoảng **31,56%**. Vì vậy biểu đồ hội tụ raw và kết quả sau polishing cần được gắn nhãn riêng.

## 9. Hội tụ và tính công bằng của ngân sách tính toán

Ở 21 tổ hợp B/IPSO, gain của raw EE từ vòng 800 tới 1.000 có **trung vị 7,21%**, trung bình **12,06%**, và **18/21** lượt còn tăng trên 1%. Bộ mặc định seed2026 tăng **43,75%** trong 200 vòng cuối. A/IPSO có trung vị khoảng **0,002%**. Vì vậy giới hạn 1.000 vòng dường như đủ làm đường A gần phẳng trong nhiều lượt, nhưng B/IPSO còn tiếp tục cải thiện đáng kể.

![Hội tụ raw](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/raw_convergence.png)

Biểu đồ chuẩn hóa từng đường bằng **raw EE cuối của chính đường đó**, dùng trung vị và khoảng tứ phân vị; loại các vòng chưa khả thi. Nó mô tả tốc độ tiến tới kết quả của từng lượt, không chứng minh PSO đạt nghiệm tốt hơn khi đường xanh phẳng sớm. A/PSO có một lượt không bao giờ khả thi nên không góp vào đường chuẩn hóa EE khả thi.

Cùng 120 particles và 1.000 vòng chưa đồng nghĩa cùng chi phí. PSO có khoảng **120.120 lần đánh giá** ở khởi tạo và vòng lặp, rồi Full được **20 × 1.250 = 25.000** thử alpha. IPSO còn thêm đánh giá mutation. Chưa có bộ đếm evaluation hay runtime riêng từng thuật toán trong dữ liệu được phân tích, nên chưa kết luận IPSO tốt hơn trên cùng thời gian hoặc cùng số đánh giá. Hai biến thể cũng có số biến tối ưu khác nhau.

Chỉ có ba scenario seeds và **một algorithm seed cố định**. Độ phân tán qua ba seed hiện đo ảnh hưởng scenario/user/fading, không đo độ ổn định trước nhiều lần khởi tạo PSO trên cùng scenario. Các sweep và cấu hình trùng không phải các mẫu độc lập; báo cáo này không làm kiểm định p-value hay tuyên bố ý nghĩa thống kê.

## 10. Năng lượng: kết quả đang nói gì?

EE hiện là **tổng bit / (năng lượng cruise + hover + RF downlink)**, không phải EE chỉ RF của V9. RF chiếm tối đa **2,432×10⁻⁸** tổng năng lượng, tức **0,000002432%**. Vì vậy mẫu số gần như do propulsion quyết định; khác biệt EE không thể được giải thích chủ yếu bằng tiết kiệm RF energy. BS/EH vẫn ảnh hưởng công suất phát và dữ liệu đạt được.

EH trong mô hình cấp RF lý tưởng; không trừ EH khỏi năng lượng cruise/hover và không cấp động cơ bằng năng lượng thu hoạch. Năng lượng PA, mạch, động học tăng/giảm tốc và kiểm tra dữ liệu relay UL→DL không được mô hình hiện tại giải quyết đầy đủ; giữ nguyên phạm vi này khi diễn giải tính thực tế.

Trên tất cả 42 tổ hợp, năng lượng lớn nhất là **14.989,47 J**, còn cách budget khoảng **2.010,53 J**. Budget 17 kJ không bị vi phạm ở các nghiệm cuối đã lưu; chưa thể nói ràng buộc này đang hoạt động tại optimum. Không có khảo sát L=4M hay budget thấp hơn trong campaign này để kiểm tra vùng giới hạn khả thi.

## 11. Những kết luận có thể dùng và bước kiểm chứng tiếp theo

Có thể kết luận: **trong campaign đã chạy**, Full IPSO tìm được nghiệm khả thi ở mọi tổ hợp; B mở rộng khả năng bố trí điểm phục vụ và cho EE cao hơn A nhất quán khi dùng IPSO; nâng QoS từng user-slot có chi phí EE; tăng hover cải thiện EE đi kèm nhiệm vụ lâu hơn; fairness và tổng EE là hai chỉ số cần trình bày cùng nhau.

Ưu tiên lần chạy tiếp theo:

1. Chỉ chạy 42 tổ hợp khác nhau, lưu rõ `L`, user-slot, hover trong tên/manifest để tránh nhầm giữa các folder cùng seed/L.
2. Chạy nhiều algorithm seeds trên cùng ba scenario, trước hết ở bộ mặc định và user-slot10k; tách phân tán do scenario và do optimizer.
3. Với B/IPSO, tăng ngân sách vòng lặp ở các trường hợp còn tăng mạnh, đồng thời ghi số evaluation/runtime để so công bằng với PSO.
4. Báo cáo đồng thời raw và polished, feasibility rate, EE, Jain, min-user bit, min-user-slot bit, năng lượng và mission time. Thêm baseline quỹ đạo thẳng/alpha đều để tách ảnh hưởng alpha theo kênh của baseline hiện tại.
5. Nếu fairness hoặc latency là yêu cầu nghiên cứu, xác định ngưỡng Jain/min-rate hay deadline từ yêu cầu đó trước khi bổ sung mục tiêu/ràng buộc; không chọn tham số chỉ để ép alpha khác 0,2.

Các bước trên là đề xuất kiểm chứng; chưa sửa solver, chưa chạy mô phỏng bổ sung hoặc commit/push trong lượt phân tích này.

## 12. Tệp kết quả phân tích

- [Toàn bộ 216 kết quả và chỉ số bổ sung](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/all_216_results.csv)
- [168 kết quả sau loại trùng](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/unique_168_results.csv)
- [Thống kê nghiệm khả thi theo phương pháp](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/feasible_algorithm_summary.csv)
- [Đối chiếu MAT–CSV](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/mat_csv_audit.csv)
- [Cấu hình thực tế 54 lượt](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/run_config_audit.csv)
- [Dữ liệu chi tiết/lịch sử để dựng lại biểu đồ](/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO/output/v10_campaign_analysis_20261029/analysis_data.json)
