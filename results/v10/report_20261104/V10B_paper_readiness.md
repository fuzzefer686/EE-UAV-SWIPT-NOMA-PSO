# V10B — Đánh giá mức độ sẵn sàng cho paper journal

Ngày: 04/11/2026. Phạm vi: chỉ V10B. V10C được giữ riêng làm follow-up/so sánh.

## 1. Kết luận thẳng

**V10B hiện chưa đủ để viết một paper journal chính.**

Nó đủ cho:

- báo cáo kỹ thuật nội bộ,
- baseline/ablation trong paper lớn hơn,
- workshop/short paper nếu đóng khung là “empirical study / reference solver”,
- nền để chạy một campaign sạch hơn.

Nó **chưa đủ** nếu V10B là đóng góp trung tâm, vì:

1. Dataset hiện tại là **27 run không cân bằng**, chỉ 15 cấu hình duy nhất, 12 run lặp.
2. Nghiệm tốt nhất 16,901.9 bit/J đạt được ở **hover 3 s**, không so được với paper gốc 0.1 s.
3. Quỹ đạo vẫn là **1 m corridor + vài cú nhảy dài**, không phải 20 điểm phục vụ thực tế.
4. Objective EE dồn **70.8% bit cho User 4**; EE hữu ích (cap tại $L$) đảo ngược thứ hạng.
5. Alpha tốt nhất sau polishing là **0.2 đều**, nên đóng góp “alpha optimization” không hiện rõ.
6. Thiếu baseline ngoài, thiếu thống kê nhiều seed, thiếu $D_{\max}$, thiếu fairness, thiếu hình publication-quality.

---

## 2. Dataset V10B hiện có

Nguồn:

```text
results/v10/V10B/
27 run folders
27 results.mat
27 summary.txt
```

Mỗi run có 4 block: baseline, Joint PSO, Full PSO, Full IPSO.

| Thuộc tính | Giá trị |
|---|---|
| Số run | 27 |
| Số dòng kết quả | 108 (27 × 4) |
| Seed | 2026, 608060, 3486784401 |
| $L$ | 1, 2, 3 Mbit/user |
| Hover | 1, 2, 3 s |
| Cấu hình (seed, $L$, hover) duy nhất | **15** |
| Run lặp | **12** (chủ yếu $L=3$, hover=1, 5 run/seed) |
| Thuật toán | Joint PSO, Full PSO, Full IPSO + alpha polishing |
| Figure trong folder run | **0** |
| Campaign CSV/manifest | **Không có** |

### Ma trận cấu hình

- $L=1,2$ chỉ có hover = 1 s.
- $L=3$ có hover = 1, 2, 3 s.
- Không có full factorial $3 \times 3 \times 3$.
- Một số run lặp cho cùng EE (ví dụ 8,984.3; 5,865.7; 7,820.2), không phải replicate độc lập.

### Feasibility

| Phương pháp | Feasible |
|---|---:|
| Baseline thẳng | 1/27 |
| Joint PSO (BS cố định) | 16/27 |
| Full PSO | 27/27 |
| Full IPSO | 27/27 |

Điều này tốt cho Full PSO/IPSO, nhưng nghĩa là **baseline gần như luôn infeasible**; không thể so EE của baseline như một nghiệm hợp lệ.

---

## 3. V10B đang có gì tốt?

### 3.1. Pipeline hoàn chỉnh

- Entry point: `scripts/maincodeV10B_EE.m`.
- Config: `src/config/v10Config.m`.
- Simulator: `buildV10Simulation`.
- Evaluator: `evaluateTrajectoryV10` + `addV10EnergyMetrics`.
- Optimizer: Joint PSO, Full PSO, Full IPSO, `polishAlphaV10`.
- Lưu `results.mat` + `summary.txt`; code đã commit.

### 3.2. Mô hình năng lượng có cơ sở

- Drones Eq. (11), quad-rotor, $z$ cố định, bay ngang.
- Có **hover propulsion** tường minh.
- Có RF energy và energy budget 17 kJ.
- Đã có báo cáo đối chiếu `DRONES_ENERGY_CODE_REVIEW_2026-10-28.md`.

### 3.3. Kết quả định lượng

- Best V10B: **16,901.9 bit/J** (seed 2026, $L=3$, hover 3 s, Full PSO).
- Hover 1 s: best **11,250.4 bit/J**.
- Hover 2 s: best **14,092.4 bit/J**.
- Hover 3 s: best **16,901.9 bit/J**.

### 3.4. Tài liệu và test

- `V10_AB_GUIDE.md`, `V10_SLOT_QOS_AND_FIXES_2026-10-28.md`, `V10_FIGURE_AUDIT_2026-10-29.md`.
- `tests/testV10Models.m` đã được chạy pass trong log V11 verification (MATLAB R2025a).
- `tests/check_v10_static.py`: 12/12 pass.
- Có sẵn `runV10Campaign` để chạy matrix có kiểm soát (L/slot/hover), dù dataset hiện tại chưa dùng.

### 3.5. Insight đáng giá

- EE tăng theo hover time: 11.25k → 14.09k → 16.90k.
- Alpha polishing ở nghiệm tốt nhất chọn **0.2 đều**.
- Quỹ đạo là corridor 1 m + vài cú nhảy dài.
- Fairness kém: User 4 nhận 70.8% bit.

Đây có thể là **nội dung paper**, nếu được phân tích nghiêm túc.

---

## 4. V10B thiếu gì?

### 4.1. Thiết kế thực nghiệm

- 27 run nhưng chỉ 15 cấu hình; 12 run lặp.
- Không full factorial; thiếu $L=1,2$ ở hover 2/3.
- Không có replicate độc lập; không median/IQR.
- Không có campaign CSV/manifest thống nhất.
- Không có figure publication-quality trong folder run.

**Cần:** campaign sạch, 5–10 seed, full factorial, báo median/IQR và feasible rate.

### 4.2. Baseline và so sánh

- Chỉ có baseline thẳng, Joint PSO, Full PSO, Full IPSO.
- Không có SCA/Dinkelbach, TSP/GA, convex relaxation, exhaustive cho case nhỏ.
- Không có lower/upper bound, không có optimality gap.
- Joint PSO không được polishing, còn Full PSO/IPSO có 1,250 mẫu polishing → **so sánh không cùng ngân sách**.

**Cần:** baseline ngoài, cùng budget, báo số evaluation/runtime.

### 4.3. Mô hình bay và ràng buộc

- $Y$ đơn điệu; `minYProgress=1` m.
- Không có stay, không có $d_{\min}$.
- Không có stop cost/turn cost/acceleration.
- Không có $D_{\max}$; có run tới **1,155 m**, best 467.6 m.
- Hover cố định 1/2/3 s; UL/DL cố định 50/50.
- Không có PA/circuit; RF gần như bằng 0.

**Cần:** $d_{\min}$/stop cost, $D_{\max}$, biện luận hover time, sensitivity.

### 4.4. Artifact quỹ đạo

Best hover 3 s:

- 15/20 đoạn xấp xỉ **1 m**.
- 4 đoạn dài; max **202.3 m**.
- Không có đoạn <0.5 m, nhưng vẫn là **1 m crawl**.
- Tổng $D=467.6$ m.

Best hover 1 s:

- 16/20 đoạn xấp xỉ 1 m.
- 3 đoạn dài; max 196.0 m.
- $D=431.8$ m.

Đây là corridor sweep, không phải 20 điểm khác nhau. Cần $d_{\min}$ hoặc stop cost để kiểm tra độ bền.

### 4.5. Objective và fairness

Best hover 3 s:

| Chỉ số | Giá trị |
|---|---:|
| Total bits | 230.30 Mbit |
| $E_{\rm total}$ | 13,625.6 J |
| Hover energy | 10,343.3 J (75.9%) |
| Flight energy | 3,282.3 J (24.1%) |
| User 4 share | 70.8% |
| Jain index | 0.380 |
| EE hữu ích (cap $L$) | **1,101 bit/J** |

Best hover 1 s:

| Chỉ số | Giá trị |
|---|---:|
| Total bits | 72.89 Mbit |
| $E_{\rm total}$ | 6,478.9 J |
| Hover energy | 3,447.8 J (53.2%) |
| Flight energy | 3,031.1 J (46.8%) |
| User 4 share | 62.8% |
| Jain index | 0.456 |
| EE hữu ích (cap $L$) | **2,315 bit/J** |

**Điểm rất quan trọng:** nếu chỉ cần đủ $L=3$ Mbit/user, hover 1 s có EE hữu ích **2,315 bit/J**, tốt hơn hover 3 s **1,101 bit/J** gấp 2.1 lần. Tức là “best EE 16.9k” của hover 3 s là kết quả của **over-serving**, không phải phục vụ hiệu quả hơn.

### 4.6. Alpha/NOMA

- Best hover 3 s: alpha sau polishing là **0.2 đều**.
- Raw alpha có phân bố, nhưng polishing chọn đều và tăng EE từ 16,306.5 → 16,901.9.
- Best hover 1 s: alpha vẫn biến thiên.

Vì vậy không thể nói “alpha optimization” là đóng góp chính ở nghiệm tốt nhất. Cần:

- chứng minh uniform alpha là tối ưu trong trường hợp nào,
- hoặc thêm QoS/fairness để alpha rời 0.2,
- hoặc bỏ alpha khỏi claim chính.

### 4.7. Thống kê và theory

- 3 seed; không median/IQR.
- PSO/IPSO heuristic; không global optimality.
- Không có convergence proof, complexity analysis, optimality gap.
- Không có sensitivity đầy đủ cho $L$, hover, $q$, $E_{\max}$, $D_{\max}$.

### 4.8. Hình và reproducibility

- Không có figure trong `results/v10/V10B/*/`.
- Code có thể vẽ `plotV10Diagnostics`, nhưng dataset chưa lưu hình.
- Không có campaign CSV/manifest; run names chỉ có seed/L/timestamp.
- Có 12 run lặp; không rõ độc lập hay chạy lại.

---

## 5. Reviewer sẽ hỏi gì?

| Câu hỏi | Hiện trạng | Cần |
|---|---|---|
| “Đây là trajectory optimization hay corridor sweep?” | 1 m steps + long jumps | $d_{\min}$/stop cost, free Y/order |
| “Fairness đâu?” | U4 70.8%, Jain 0.380 | Jain/max-min/cap-L, EE hữu ích |
| “Sao hover 3 s?” | 11.25k → 16.9k khi tăng hover | Biện luận, sensitivity 0.1/1/3 s |
| “Alpha optimization đóng góp gì?” | Best là 0.2 đều | Chứng minh/đổi objective |
| “So với SOTA?” | Chỉ baseline nội bộ | SCA/TSP/GA/exhaustive |
| “Sao chỉ 3 seed, nhiều run lặp?” | 15 cấu hình/27 run | Campaign full factorial, 5–10 seed |
| “Sao không có $D_{\max}$?” | Có run 1,155 m | Thêm constraint |
| “Sao baseline infeasible?” | 1/27 feasible | Báo feasible rate, không so EE baseline |
| “Reproducibility?” | Không CSV/manifest/figures | Package đầy đủ |

---

## 6. Ba hướng paper khả thi

### Hướng A — Empirical/insight paper (khả thi nhất)

**Tiêu đề gợi ý:**

> *Hover Time, Fairness, and Corridor Artifacts in PSO-based Energy-Efficiency Optimization for Fly–Hover UAV Networks*

Đóng góp:

1. Controlled study V10B (và có thể V10C) trên hover/L/seed.
2. Chỉ ra EE tăng theo hover nhưng EE hữu ích giảm.
3. Chỉ ra alpha polishing về 0.2 đều.
4. Chỉ ra corridor 1 m + long jumps.
5. Đề xuất metric fairness/effective locations và stop-cost regularization.

Cần: campaign sạch, 5–10 seed, baseline, phân tích.

### Hướng B — Algorithm paper

Cần:

- hybrid PSO + SCA/Dinkelbach,
- proof/complexity,
- so với PSO/IPSO/SCA thuần,
- benchmark.

V10B hiện chưa có.

### Hướng C — Benchmark/reference solver

Cần:

- controlled campaign,
- open code/results package,
- baselines,
- reproducible figures/CSV.

Có thể là workshop/short paper.

---

## 7. Minimum checklist trước khi viết

### P0 — bắt buộc

1. Chạy `runV10Campaign` với **full factorial**: 5–10 seed × $L\in\{1,2,3\}$ × hover $\in\{0.1,1,3\}$ × 3 algorithms.
2. Thêm **$D_{\max}$** và **$d_{\min}$/stop cost**; chạy lại.
3. Báo **feasible rate**, median/IQR, không chỉ best.
4. Thêm **fairness**: Jain, per-user bits, EE hữu ích cap tại $L$.
5. Baseline ngoài: SCA/Dinkelbach, TSP/GA, exhaustive cho case nhỏ.
6. Cân bằng budget: Joint cũng phải có polishing hoặc bỏ polishing khỏi so sánh.
7. Lưu campaign CSV/MAT + manifest seed/config/checksum.
8. Vẽ figure 300 dpi: trajectory, EE vs hover, fairness, energy breakdown, convergence.

### P1 — nên có

9. Giải thích/validate alpha uniform.
10. Sensitivity $q$, $E_{\max}$, $L$, hover.
11. Free 2D/order hoặc tuyên bố rõ corridor.
12. So sánh V10B vs V10C trên cùng hover budget.
13. Viết related work, system model, problem formulation, algorithm, complexity, limitations.

---

## 8. Khuyến nghị chiến lược

- **Không nên viết paper chỉ về V10B** ở trạng thái hiện tại.
- V10B nên là **baseline/ablation** trong paper lớn hơn, hoặc là **empirical study** về hover/fairness/corridor.
- V10C đã có campaign 54 run có kiểm soát hơn, có report và figures; V10B nên được dùng làm **baseline lịch sử** hoặc **ablation “fixed hover / monotone Y”**.
- Nếu vẫn muốn V10B làm trung tâm: cần **4–8 tuần** để làm campaign sạch + fairness + baseline + figures + viết.

### So sánh nhanh V10B vs V10C

| | V10B | V10C |
|---|---|---|
| Campaign | 27 run, 15 cấu hình, 12 lặp | 54 search, full C0–C5 × 3 seed × 3 algo |
| Hover | Cố định 1/2/3 s | Biến thiên 0.1–3 s, tổng ≤20 s |
| Stay | Không | Có |
| Best EE | 16,901.9 ở hover 3 s | 16,071.9 ở tổng hover 20 s |
| EE hữu ích | 1,101 (h3) / 2,315 (h1) | 2,572 |
| Fairness | U4 70.8%, Jain 0.380 | U4 73.4%, Jain 0.357 |
| Artifact | 1 m crawl | sub-0.5 m cluster |
| Figures/report | Không có | Có report + figures |
| Kết luận | Baseline/ablation | Platform tốt hơn cho paper |

Điểm quan trọng: V10B best 16.9k **không** tốt hơn V10C C4 16.07k, vì V10B dùng **60 s hover** còn V10C dùng **20 s tổng hover**. Ở cùng hover budget, V10C tốt hơn.

---

## 9. Nguồn dữ liệu

- `results/v10/V10B/*/results.mat`
- `results/v10/V10B/*/summary.txt`
- Code: `scripts/maincodeV10B_EE.m`, `scripts/runV10.m`, `src/config/v10Config.m`, `src/evaluators/evaluateTrajectoryV10.m`, `src/evaluators/addV10EnergyMetrics.m`
- Docs: `docs/V10_AB_GUIDE.md`, `docs/V10_SLOT_QOS_AND_FIXES_2026-10-28.md`, `docs/DRONES_ENERGY_CODE_REVIEW_2026-10-28.md`
- Test: `tests/testV10Models.m`, `tests/check_v10_static.py`

---

## 10. Kết luận cuối

V10B là một **prototype kỹ thuật tốt**, có mô hình năng lượng hợp lý, pipeline chạy được, và vài insight đáng giá. Nhưng dữ liệu hiện tại **chưa đủ chuẩn journal**:

- không full factorial,
- không đủ seed,
- không baseline ngoài,
- không fairness,
- không $D_{\max}$,
- không xử lý artifact 1 m,
- alpha tốt nhất là 0.2 đều,
- hover time làm đảo ngược kết luận EE hữu ích.

**Nếu viết ngay:** paper sẽ bị đánh là “PSO trên mô hình toy, corridor 1 m, unfair, thiếu baseline”.
**Nếu đầu tư thêm 4–8 tuần:** có thể thành một empirical/insight paper tốt, hoặc baseline/ablation trong paper V10C.
