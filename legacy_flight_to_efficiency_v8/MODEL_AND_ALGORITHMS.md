# Mô hình và thuật toán được bảo toàn

Nguồn chính: bản PDF Flight to Efficiency trong `paper/`, các mục II–III,
Algorithm 1–2, công thức (1)–(8), Table I và các hình 1–7.
Tài liệu này là bản chỉ dẫn đối chiếu; PDF giữ đầy đủ nội dung và hình gốc.

## Phần của bài báo gốc

| Thành phần | Nội dung giữ lại | Mã đối chiếu |
|---|---|---|
| Hình học | Một UAV làm relay từ BS đến GU, vị trí 3D và điểm đầu/cuối cố định | `Raw0/main_code.m`, `raw1_corrected/runTrajectorySimulation.m` |
| Kênh | Suy hao theo khoảng cách; fading Rician phụ thuộc góc nâng | `raw1_corrected/computeUAVChannels.m`, `RicianFadingChannel.m` |
| SWIPT | Thu năng lượng từ tổng công suất nhận của BS; power splitting | `Raw0/findAchievableRate_SWIPT.m`, `raw1_corrected/evaluateUAVRates.m` |
| NOMA | Uplink BS→UAV, downlink UAV→GU và SIC | `findAchievableRate_BS.m`, `findAchievableRate_SWIPT.m`, các script NOMA |
| Phân bổ công suất | Fractional allocation (Algorithm 1), channel-based allocation (Algorithm 2), fixed allocation để so sánh | `findPowCoeff.m`, `raw1_corrected/runPowerAllocationSimulation.m` |
| Tối ưu vị trí | PSO tối đa hóa min-rate với/không SWIPT, giới hạn dịch chuyển và độ cao | `positionUpdate_PSO.m`, `positionUpdate_PSO_SWIPT.m`, các objective tương ứng |
| Đối chứng | Quỹ đạo thẳng so với quỹ đạo tối ưu, rate từng GU, min-rate và các hình quỹ đạo | PDF hình 2–7; các script mô phỏng nền |

Mô hình năng lượng gốc dùng:

```text
Pr = PBS × tổng_m |h_BS,m|²
EH = η × φ × Pr × T_uplink
Pt = EH / T_downlink
```

Bài báo giả định hai pha có thời lượng bằng nhau, nên `Pt = η × φ × Pr`.
Bài báo giả định UAV đủ pin cho nhiệm vụ; không đưa mô hình công suất
động cơ/quỹ đạo vào một mẫu số EE được tối ưu trong công thức (6)–(7).
Mục tiêu tối ưu được nêu ở đó là min-rate.

## Tham số Table I của bài báo

| Tham số | Giá trị |
|---|---|
| Vùng mô phỏng | 2000 × 2000 × 320 m |
| GU / BS / UAV | 3 / 3 / 1 |
| Số mũ suy hao | 2.5 |
| Gain tham chiếu | −50 dB |
| Rician K min/max | 4 / 12 dB |
| Hiệu suất EH η / power splitting φ | 0.7 / 0.7 |
| Công suất BS / UAV không SWIPT | 46 / 20 dBm |
| Hệ số fractional ban đầu δ | 0.8 |
| Điểm đầu / cuối UAV | (1000, 2000, 200) / (1000, 0, 200) m |
| Độ cao tối thiểu / tối đa | 100 / 300 m |
| Dịch chuyển x tối đa / bước y | 500 / 100 m |

`raw1_corrected/paperParameters.m` ghi các giá trị này. Tham số không nằm
trong Table I, như bandwidth, noise, thời lượng pha và hệ số fixed để vẽ
so sánh, cần xem nguồn cụ thể của từng script; không gán tất cả chúng là
tham số do Table I quy định.

## Phần phát triển đến V8

V8 đang dùng scenario 300 × 300 × 60 m, 5 GU, 3 BS và 21 vị trí UAV,
có các tham số khác bài báo như gain tham chiếu −30 dB và η/φ = 0.9/0.9.
Các bản này được giữ riêng để tránh coi kết quả V8 là tái hiện nguyên vẹn
Table I của bài báo.

V8 có Joint PSO (quỹ đạo + alpha), Full PSO/Full IPSO (thêm vị trí BS),
alpha polishing và mở rộng CCPSO. Với 5 users và 21 vị trí, Full particle
có 38 biến quỹ đạo, 105 biến alpha và 6 biến BS, tổng cộng 149 biến.
Các mốc trước V8 còn giữ BS-only PSO, GA và các thử nghiệm FA/DE.

Fitness Full V8 có cấu trúc:

```text
minFit + lambdaMean × meanFit
       − lambdaSmooth × roughNorm
       − lambdaFair × meanFit × mean(1 − Jain)
       − penalty
```

Đây là fitness dựa trên rate. Nó không phải EE đo bằng bit/J.
`fitnessStepMode = 'internal'` dùng các vị trí nội bộ, còn global min-rate
có thể bao gồm điểm đầu/cuối. Khi đánh giá EE mới phải báo rõ khoảng thời
gian và tập vị trí dùng để tính từng chỉ số.
