# V10 figure audit — 2026-10-29

Đối chiếu `scripts/plotV10Diagnostics.m` với field/dimension thực tế trong
`results.mat` và với lịch hover/fly của V10. Static check 12/12 OK; chưa
render MATLAB.

## Đã sửa

1. **Figure 1**: thêm Joint PSO vào trajectory và legend; trước đây dòng Joint
   bị comment nên hình chỉ có Baseline/Full PSO/IPSO. `rotate3d on` được bật
   sau `view(3)` để kéo xoay 3D trong MATLAB; PNG/FIG đã lưu là ảnh tĩnh,
   nhưng file `.fig` mở lại vẫn xoay được.
2. **Figure 2**: chỉ vẽ 20 slot phục vụ (bỏ waypoint đến); baseline ghi
   `(infeasible)` thay vì chỉ `QoS-infeasible`.
3. **Figure 4/5**: trước đây dùng `1:numSteps` (21 điểm, gồm waypoint đến
   không phục vụ). Nay dùng `slotAxis = 1:numSteps-1`, nhãn `Mission slot`;
   đổi tên `Full PSO`/`Full IPSO` để không lẫn với thuật toán Joint PSO.
4. **Figure 6/11/13**: endpoint sau polishing là `o` nếu feasible, `x` nếu
   infeasible; title ghi rõ `pre-polish gbest`.
5. **Figure 9/10/17/18**: figure 9/17/18 có `sgtitle` liệt kê nghiệm cuối
   không khả thi; figure 10 đã có marker `x`.
6. **Figure 18**: trước đây nối thẳng waypoint nên trông như UAV di chuyển
   trong lúc hover. Nay vẽ đúng lịch: hover tại waypoint n, rồi bay đoạn n;
   marker đặt tại các waypoint.
7. **Figure 12/14–16**: title ghi `pre-polish gbest`; màu dùng thang chung.

## Dimension đã kiểm

Các field trong MAT (MATLAB view):

```text
bestHistory                  (N,1)
totalBitsHistory             (N,1)
totalEnergyHistory           (N,1)
feasibleHistory              (N,1)
totalBitsPerUserHistory      (N,5)
transmitPowerHistory          (N,20)
alphaUserHistory              (N,20,5)
slotIdx                       (1,20)
timeSeconds                   (1,21)
flightTimePerSegment          (20,1)
alphaTrace                    (21,5)
achRate                       (21,5)
pt                            (21,1)
```

- Figure 12: `powerNanoW.'` là 20×N, khớp `imagesc(iteration (1×N), slotIdx
  (1×20), C (20×N))`.
- Figure 14–16: `alphaUserHistory(:,:,u).'` là 20×N, cùng quy ước.
- Figure 13: `mean(alphaUserHistory,2)` là N×1×5, reshape N×5 đúng.
- Figure 2/4/5: index 1:20 trên vector 21 phần tử; đúng.

## Còn lại (cố ý)

- Các đường/map lịch sử (Figure 6 panel 2–3, 11, 12, 13, 14–16) là
  **pre-polish gbest**, có thể không khả thi ở một số vòng; chỉ endpoint được
  đánh dấu `o/x`, không mask từng vòng. Đây là lịch sử tìm kiếm, không phải
  nghiệm đạt yêu cầu.
- Figure 4/5 chỉ vẽ Full PSO/IPSO (kiểu V9); Joint PSO nằm ở Figure 1/2 và
  các hình chẩn đoán 6–18.
- `saveV9Figures` lưu **mọi** figure đang mở. Chạy `close all` trước mỗi case
  nếu không muốn lẫn figure của lần trước.
- `sgtitle`/`yline` cần MATLAB R2018b+.

## Vẽ lại không cần chạy PSO

```matlab
saved = load('results/v10/V10A/.../results.mat');
plotV10Diagnostics(saved.data);
% hoặc nếu workspace còn data:
plotV10Diagnostics(data);
```
