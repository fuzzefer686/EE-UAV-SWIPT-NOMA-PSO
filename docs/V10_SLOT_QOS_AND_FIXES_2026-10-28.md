# V10: sửa lỗi và thêm QoS bit/slot

Ngày: 28/10/2026. Phạm vi: V10A/V10B. Không sửa V8/V9.

## Đã sửa

1. **Seed của Joint.** `scripts/runV10.m` reset `algorithmSeed` trước Joint.
   Trước đây Joint dùng tiếp random stream sau khi tạo scenario (hành vi V9),
   nên Joint và Full/IPSO không cùng seed. Sau khi sửa, **chỉ kết quả Joint
   thay đổi**; Full/IPSO vẫn tái lập vì đã reset seed riêng.

2. **Figure 2.** Chỉ vẽ 20 slot phục vụ (`slotIdx`), không vẽ waypoint đến;
   thêm lại Joint PSO; baseline được ghi rõ `(QoS-infeasible)` nếu không đạt L.

3. **Hàng alpha cuối.** `decodeV10Particle` đặt hàng ứng với waypoint đến
   thành `1/N`. 5 trọng số cuối của particle trở nên vô tác dụng; chúng vẫn
   tồn tại trong vector nhưng không ảnh hưởng bit/năng lượng/fitness.
   Việc xoá hẳn 5 chiều này là refactor riêng, chưa làm.

4. **QoS bit/slot.** Thêm hai trường cấu hình:

   ```matlab
   cfg.mission.minBitsPerSlot = 0;           % tổng bit mọi user trong 1 slot
   cfg.mission.minBitsPerUserPerSlot = 5e3;  % bit của từng user trong 1 slot
   ```

   Cả hai tính trên 20 slot phục vụ. Giá trị 0 = tắt. Ràng buộc vào
   `dataQoSFeasible`, vào fitness (sai lệch chuẩn hoá) và vào `summary.txt`.
   Đặt cả hai bằng 0 để tái lập đúng log V10A trước ngày 28/10.

5. **Cảnh báo `pMax`.** `pMax` chỉ chặn raw weight trước normalize, không
   chặn alpha sau normalize. Đã thêm comment và warning nếu `pMax < 1`.
   Hành vi số không đổi (mặc định `pMax = 1`).

## Chọn ngưỡng bit/slot từ log

Vấn đề thật là **một user bị bỏ đói trong một slot**, không phải slot rỗng:
L3 Full có slot mà user yếu chỉ nhận 42 bit, trong khi tổng slot vẫn 36,9 kbit.
Vì vậy ưu tiên ràng buộc **per-user per-slot**.

| Ngưỡng/user/slot | L1 Full | L2 Full | L3 Full | L3 IPSO |
|---:|---:|---:|---:|---:|
| 5 kbit | 0 lỗi | 3 lỗi / 7 kbit | 8 lỗi / 33 kbit | 4 lỗi / 15 kbit |
| **10 kbit** | 2 lỗi / 4 kbit | 6 lỗi / 32 kbit | 8 lỗi / 73 kbit | 8 lỗi / 48 kbit |
| 20 kbit | 9 lỗi / 64 kbit | 10 lỗi / 114 kbit | 9 lỗi / 162 kbit | 13 lỗi / 160 kbit |

Chọn **10 kbit/user/slot** là ngưỡng phân tích từ log: bắt được các slot 42
bit/1 kbit, tổng thiếu hụt chỉ 0,1–0,17% tổng bit nên không làm bài toán bất
khả thi. **Cấu hình hiện tại dùng 5 kbit** (milder, theo lựa chọn 29/10);
muốn chặt hơn thì đặt 10 hoặc 20 kbit. Nếu chỉ muốn chặn slot gần rỗng, dùng
tổng 300 kbit/slot.

Ràng buộc tổng bit/slot (300 kbit) chỉ ảnh hưởng Full ở L2/L3 (2–3 slot),
không chặn được trường hợp một user nhận 42 bit. Vì vậy mặc định để tổng = 0.

## Chưa sửa (có lý do)

- **Động năng dừng/khởi động** (~241 J mỗi lần dừng, tối đa ~4,8 kJ): giữ
  theo giả định của bài Drones; sẽ dùng làm sensitivity nếu cần.
- **PA/mạch/EH = RF**: là phạm vi mô hình, không sửa âm thầm vì sẽ đổi số.
- **Baseline khả thi**: cần chạy lại quỹ đạo V8 dưới ledger V10; là việc riêng.
- **Repair Y của V10B** dùng `sort`: đúng ràng buộc nhưng nhiều hạt map cùng
  quỹ đạo. Chưa đổi trước khi có log B; nếu B hội tụ kém mới thay bằng
  tham số hoá trơn (softmax/cummax) và cập nhật test.

## Thứ tự chạy đề xuất

1. `testV10Models` để kiểm tra mô hình và ràng buộc mới.
2. L=3, slot QoS = 0 rồi = 10k, cùng seed: đo giá EE của ràng buộc.
3. Hover 1/2/3 s ở L=3; h=4 chỉ chạy với budget `Inf` hoặc budget cao hơn
   (17 kJ bị chạm ở h≈3,6–3,9 s).
4. L=4 cho Full PSO/IPSO (test giới hạn QoS), dự kiến cần thêm slot α≈1.
5. V10B ở L=2/3 để xem quỹ đạo Y tự do có làm giảm α cực đoan không.

## Kiểm chứng

`tests/check_v10_static.py`: 12 test OK (kiểm tra cấu trúc/nguồn, không chạy
MATLAB). Chưa chạy `testV10Models` trong MATLAB.

## Hiển thị EE thay cho fitness âm

- `addV10EnergyMetrics` thêm `eeComputed` (luôn là tỉ số bit/J nếu dữ liệu
  hợp lệ, kể cả khi vi phạm ràng buộc), `missionQoSFeasible` và `statusLabel`.
- Log của Joint/Full/IPSO và polishing in:

  ```text
  EE = ... bit/J | L:1 bitSlot:1 bitUserSlot:1 | feasible:1
  ```

  Không còn in `best fitness` âm. `summary.txt` in `EE (computed)` cùng dòng
  `L / bit-slot / bit-user-slot QoS = ...`.
- `result.fitness` **vẫn là score nội bộ** để PSO/polishing so sánh các
  nghiệm vi phạm; nó không còn xuất hiện trên console/summary. Nếu cần debug,
  đọc `results.mat` hoặc `bestFitness`; `bestEE`/`bestFeasible` được thêm vào
  kết quả optimizer.
- EE in ra của nghiệm vi phạm chỉ để chẩn đoán, không phải EE đạt yêu cầu.

## Campaign nhiều seed

`scripts/runV10Campaign.m` chạy cả A và B. Mặc định generic:

- 3 seed: 2026, 608060, 3486784401;
- 3 giá trị L: 1, 2, 3 Mbit/user;
- 3 giá trị bit/user/slot: 0, 5k, 10k;
- 3 giá trị hover: 1, 2, 3 s.

`scripts/maincodeV10Campaign.m` là cấu hình chạy cụ thể hiện tại:

- **một seed 3486784401** cho cả A và B;
- **3 mức L: 1, 2, 3 Mbit/user**;
- **bit/user/slot = 5 kbit**, **hover = 1 s**;
- 2 variant x 1 seed x 3 L = **6 run**;
- `makePlots = true` để Figure 1 mở và kéo xoay được trong MATLAB.

Hai profile, cùng **120 particle**:

- `quick`: 1000 iteration (mặc định của `maincodeV10Campaign`);
- `full`: 3000 iteration (production).

Generic đầy đủ là 54 run (3 seed x 9 config), nặng; cấu hình main hiện tại
chỉ 6 run. Profile `full` có thể mất nhiều giờ/ngày. Bảng kết quả ghi EE, đủ
cờ QoS, bit, năng lượng, quãng đường, mission time, alpha max và Jain; lưu
`campaign_summary.csv` + `campaign.mat`.

Chạy:

```matlab
run('scripts/maincodeV10Campaign.m');
% hoặc
campaign = runV10Campaign(struct('dryRun',true));   % xem cấu hình trước
```

