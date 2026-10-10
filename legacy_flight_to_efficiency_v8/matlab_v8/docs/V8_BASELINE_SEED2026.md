# Mốc kết quả V8 — seed 2026

Người dùng cung cấp output MATLAB ngày 28/09/2026 sau khi chạy
`scripts/main/maincodev8nUser.m` với `useFixedSeed = true` và `mainSeed = 2026`.
Đây là mốc đối chiếu cho kiểm tra V9 tại `tau(t) = 0.5`; chưa phải kết quả
benchmark nhiều seed.

| Luồng | Fitness (bps) | Min của slot nội bộ (bps) | Global minRate (bps) | Mean pt (W) |
|---|---:|---:|---:|---:|
| Baseline đường thẳng | 4.731268419034e+03 | — | 2.579388411403e+03 | 2.3296e-07 |
| Joint PSO | 3.422405253824e+04 | 3.075456190647e+04 | 3.424075327447e+02 | 4.2326e-07 |
| Full PSO | 1.701696267803e+05 | 1.559652660958e+05 | 2.639580195844e+02 | 3.4217e-06 |
| Full IPSO | 1.304971360470e+05 | 1.170302195804e+05 | 3.146143064816e+02 | 3.1155e-06 |

Thiết lập: 5 users, 3 BS, `lambdaMean = 0.05`, `lambdaFair = 0.10`.
Output báo `penalty = 0` và `feasible = 1` cho Joint/Full PSO/Full IPSO.

Fitness của Joint và Full dùng các slot nội bộ. `global minRate` gồm cả hai
endpoint nên có thể giảm ngay cả khi fitness tăng; cần báo cáo hai chỉ số
riêng khi so sánh V8/V9.

Giá trị trên được chép từ output người dùng, chưa được chạy lại trong môi
trường Codex vì MATLAB không có trên PATH.
