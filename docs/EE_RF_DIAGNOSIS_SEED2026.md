# Vì sao ba kết quả EE RF gần nhau — log seed 2026

Phân tích ngày 14/10/2026 từ log người dùng cung cấp và công thức trong mã.
Không chạy MATLAB. Không thay optimizer, mô hình hoặc thiết lập scenario.
File V9 hiện có seed mặc định 608060 do người dùng thay; số liệu ở đây vẫn
theo log đã gửi, có mainSeed=2026. Không coi chúng là kết quả của seed mới.

## 1. Kết quả khác nhau, không phải ba giá trị bằng nhau

| Luồng | EE cuối (bit/J) | Tổng bit | Tổng năng lượng RF (J) |
|---|---:|---:|---:|
| Joint PSO | 8.526046044124e12 | 2.385241e7 | 2.797593e-6 |
| Full PSO, sau polishing | 8.491757029058e12 | 2.247560e7 | 2.646755e-6 |
| Full IPSO, sau polishing | 8.472150221818e12 | 2.214989e7 | 2.614435e-6 |

Chênh lệch Joint/Full PSO là 0.4038%, Joint/Full IPSO là 0.6362%.
Các cột bit/J đều nhất quán với phép chia tổng bit/tổng J; sai khác nhỏ khi
tính lại từ log là do cột bit/J và các tổng được in với số chữ số khác nhau.
Không thấy dấu hiệu cả ba biến kết quả bị ghi đè thành một hằng số.

Full PSO so với Joint truyền ít hơn 5.7722% bit và dùng ít hơn 5.3917%
năng lượng RF. Full IPSO truyền ít hơn 7.1377% và dùng ít hơn 6.5470%.
Tử và mẫu giảm gần cùng tỷ lệ, nên tỷ số EE gần nhau. Đây là quan sát trực
tiếp từ số liệu, chưa tự xác định nguyên nhân quỹ đạo tạo ra từng thay đổi.

## 2. Với ràng buộc alpha hiện tại, alpha đều là tối ưu sum-rate

Hai evaluator Joint dùng cùng `findAchievableRate_SWIPT_Joint`. Channel
gain được sắp yếu→mạnh: `g1 <= ... <= gN`. Repair sắp alpha giảm dần rồi
gán cho user theo thứ tự này: `a1 >= ... >= aN`, tổng alpha bằng 1.

Với vị trí UAV/BS cố định, công suất RF P chỉ phụ thuộc BS→UAV và không
phụ thuộc alpha. Vì vậy tối đa EE theo alpha tương đương tối đa tổng rate.

Đặt `c_i = P*g_i/noise` và `S_i = sum_{k=i}^N a_k`. Công thức rate của
code cho tổng spectral efficiency chính xác:

```text
sum_i R_i / B
  = log2(1 + c_1)
    + sum_{i=2}^N log2((1 + c_i*S_i)/(1 + c_(i-1)*S_i)).
```

Mỗi hạng sau tăng theo S_i, bởi đạo hàm của nó là

```text
(c_i - c_(i-1)) / [ln(2)*(1+c_i*S_i)*(1+c_(i-1)*S_i)] >= 0.
```

Alpha giảm dần và tổng bằng 1 suy ra `S_i <= (N-i+1)/N`. Alpha đều
`a_i=1/N` đạt mọi giới hạn S_i cùng lúc. Do đó **alpha đều tối đa tổng
rate**, và cũng tối đa EE RF khi giữ quỹ đạo/BS cố định, trong mô hình hiện
tại (SIC lý tưởng, cùng noise, không QoS hoặc fairness trong fitness EE).
Nếu có channel gain bằng nhau có thể có nhiều alpha cho cùng mức tối ưu;
không khẳng định alpha đều là nghiệm duy nhất trong trường hợp đó.

Với 5 user: alpha tối ưu theo ràng buộc này là `[0.2 0.2 0.2 0.2 0.2]`.
Đây là hệ quả của **sum-rate + alpha ordering đang áp dụng**, không phải
mệnh đề mọi bài toán NOMA đều nên chia đều công suất. Không áp dụng kết
luận này cho mục tiêu min-rate/fairness của V8 hoặc mô hình mới khác.

Đã kiểm tra số học riêng biểu thức tổng và bất đẳng thức trên 1000 bộ kênh
chuẩn hóa với 2, 3, 5 và 10 user. Sai số đẳng thức tối đa 3.56e-15; không
có alpha giảm dần nào vượt alpha đều. Đây là kiểm chứng đại số, không phải
mô phỏng MATLAB hoặc tái hiện kết quả quỹ đạo người dùng.

## 3. Polishing củng cố tính chất này, nhưng không xóa khác biệt quỹ đạo

`polishAlphaAllSteps_JointBS` luôn thử alpha đều ở candidate đầu tiên tại
mỗi trong 20 slot, rồi nhận candidate tăng EE toàn hành trình. Tổng RF
năng lượng giữ nguyên khi chỉ đổi alpha. Do đó Full PSO và Full IPSO đều
có candidate tối ưu alpha cho từng bộ kênh của chính quỹ đạo/BS đang giữ.

Polishing không đổi quỹ đạo/BS. Việc hai luồng đều được tối ưu alpha không
buộc chúng có cùng fitness. Joint không được polishing trong main; nó
cũng có particle khởi tạo alpha đều nhưng alpha cuối chưa được ghi trong
log. Cần trace alpha để xác nhận nó gần alpha đều đến mức nào.

Log: polishing Full PSO tăng 8.873172e5 bit/J (0.00001045%); Full IPSO tăng
2.938887e8 bit/J (0.003469%). Phần lớn khác biệt cuối vẫn đến từ nghiệm
quỹ đạo/BS và mức hội tụ, không phải polishing tạo ra một gain lớn.

## 4. Biến vị trí BS tác động cả tử và mẫu

Với quỹ đạo cố định, BS không đổi trực tiếp channel UAV→user. Nó tác động
channel BS→UAV, từ đó đổi P_RF dùng trong cả rate DL và năng lượng RF.
Do đó thêm biến BS không tự động tạo gain EE như tạo thêm rate với năng
lượng miễn phí. Cần xem sự thay đổi rate và công suất tại từng slot.

Chỉ số EE RF hiện tại là:

```text
EE = 0.5*sum_n sum_u R[n,u] / (0.5*sum_n P[n])
   = sum_n sum_u R[n,u] / sum_n P[n].
```

Chỉ hệ số thời gian 0.5 triệt tiêu. **P không triệt tiêu chính xác** vì
nằm bên trong log/SINR. Nếu tất cả `P*g_i/noise` đủ nhỏ thì xấp xỉ bậc
một làm rate gần tỷ lệ P, khiến EE ít nhạy với P. Tuy nhiên, log hiện không
có SNR/h2 nên chưa thể kết luận đây là nguyên nhân chủ đạo. Công suất RF
nhỏ tự nó không chứng minh low-SNR khi noise cũng rất nhỏ.

## 5. Không có bằng chứng cả ba đạt cùng tối ưu toàn cục

Full cho phép BS ở vị trí ban đầu, nên miền nghiệm Full bao gồm nghiệm
Joint nếu đưa đúng trajectory và alpha Joint vào. Cùng evaluator RF sẽ
cho cùng EE tại điểm đó. Vì thế tối ưu toàn cục Full phải không kém tối
ưu toàn cục Joint. Kết quả Full trong log thấp hơn nghiệm Joint là dấu
hiệu các lần chạy Full chưa tìm được nghiệm ít nhất tốt bằng Joint; không
phải bằng chứng tối ưu BS vô ích hay cả ba cùng đạt một trần EE.

Full có 149 biến, Joint có 143; các chiều alpha trong EE có nghiệm lý
thuyết đơn giản nhưng optimizer vẫn tìm trên toàn particle. Main không
truyền nghiệm Joint làm seedFullParticle cho Full, dù hai optimizer Full
hỗ trợ tùy chọn đó. Không sửa warm start trong lượt phân tích này.

Full PSO/IPSO reset cùng seedAlgo nên khởi tạo swarm như nhau; điều này
giải thích sự giống nhau ban đầu. Inertia/mutation khiến stream và quá
trình tìm kiếm sau đó khác nhau. Hình thức chia sẻ evaluator không đồng
nghĩa cùng thuật toán hoặc nghiệm cuối.

Hiện tắt giới hạn bước x/z và không tính năng lượng bay hoặc smoothness
trong EE. Các waypoint nội bộ ít liên kết động học hơn V8, nên ba luồng
cùng được phép khai thác một miền hình học chung. Không có trace quỹ đạo
trong log để xác nhận chúng dùng cùng độ cao/vị trí hoặc sát biên nào.

## 6. Dữ liệu bổ sung để xác nhận nghiệm thực tế

`scripts/diagnoseV9_EE.m` chỉ đọc `trajJoint`, `trajFull`, `trajIPSO` có sẵn
trong workspace; không khởi chạy optimizer hoặc đổi nghiệm. Người dùng
có thể tự chạy khi muốn, sau lượt V9 đã xong. Script báo:

- Sai lệch alpha so với 1/N và EE nếu đổi sang alpha đều tại cùng quỹ đạo.
- RF power, altitude và SNR thuần `P*|h|^2/noise` của từng nghiệm.
- Chênh lệch x/z giữa ba quỹ đạo để phân biệt EE gần nhau và path bằng nhau.

Script chưa được chạy trong MATLAB. Các tham số B/noise ở đó khớp hàm rate
hiện tại; nếu mô hình rate đổi tham số thì diagnostic cần cập nhật cùng.
