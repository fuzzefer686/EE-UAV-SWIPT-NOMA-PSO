# Bộ lưu trữ Flight to Efficiency và mã đến V8

Đóng băng ngày 10/10/2026 để làm baseline cho hướng tối ưu EE.
Các file được sao chép hoặc lấy trực tiếp từ Git, giữ nguyên nội dung.
Nguồn và SHA-256 của từng file nằm trong `provenance/SOURCES.json`.

## Các thư mục

| Thư mục | Nội dung và nguồn |
|---|---|
| `paper/` | Bản PDF Flight to Efficiency đã có ở máy, nguyên vẹn 7 trang. |
| `paper/Raw0/` | Bản mã gốc local sạch, từ repo tác giả `dinithprimal/TrajectoryOptimization_UAV_SWIPT_NOMA`. |
| `paper/raw1_corrected/` | Bản workflow đã sửa ở máy, gồm `paperParameters.m`, phân bổ công suất và mô phỏng quỹ đạo. |
| `earlier_work/Joint_PSO_Mod/` | Các script cũ, PSO/DE/FA và tài liệu tham khảo đang lưu cạnh mã. |
| `matlab_v8/` | Pipeline V4–V8 và các phụ thuộc trước khi thêm hook mission V10; có CCPSO mở rộng của V8. |
| `history/` | Năm cây mã Git nguyên vẹn trước V9: `ddfb513`, `1fede0b`, `cd4007b`, `9f28c1d`, `c30c121`. |
| `python_ccpso/` | Bản chuyển sang Python của thí nghiệm V8 CCPSO. |
| `result_v8_ccpso/` | 20 log V8 CCPSO Python đã có. |
| `results_v8_from_comparisons/` | 105 file V8 có tên riêng: checkpoint MAT và hình FIG/PNG từ các thí nghiệm so sánh sau này. |
| `provenance/` | Nguồn, checksum, README trước chuyển hướng và bản diff các file V8 hiện tại so với trước V10. |

Các thuật toán giữ lại gồm PSO từng bước, Joint PSO, BS-only PSO, Full PSO,
Full IPSO, GA, FA, DE và CCPSO. GA/FA/DE/CCPSO là các mở rộng hoặc thử
nghiệm về sau, không phải tất cả đều thuộc thuật toán của bài báo gốc.

`matlab_v8/result_v9/` giữ 20 log V8, bản ZIP log cũ và tài liệu đổi thang
rate. Tên thư mục `result_v9` được giữ để truy vết nguồn; không chứa log V9.

## Cách chọn đúng baseline

- `paper/Raw0/`: giữ code gốc như đang lưu ở máy, kể cả khác biệt với PDF.
- `paper/raw1_corrected/`: bản workflow đã hiệu chỉnh; không đồng nhất với
  bản code gốc. Dùng `paperParameters.m` để xem tham số theo Table I.
- `matlab_v8/`: nền V8 mở rộng, không phải cấu hình mô phỏng nguyên gốc của
  bài báo. Các file mô hình/optimizer cũ lấy từ commit `7ef97e8`, trước V10.
  CCPSO và các script benchmark V8 được bổ sung từ cây mã đang có.
- `history/c30c121/`: mốc nhánh `old` chứa đồng thời V4, V5, V6, V7 và V8,
  với đầy đủ file của commit đó.

Không tìm thấy entry point có tên V1, V2 hoặc V3 trong lịch sử Git local.
Các bản mã nền trước V4 vẫn được giữ qua Raw0, raw1 và Joint_PSO_Mod;
không tự gán lại số phiên bản cho chúng.

`SourceCode_V4` nằm ở thư mục UAV là một mô hình AP/UE khác có hàm EE,
không phải `maincodeV4` thuộc dòng Flight to Efficiency; vì vậy không được
gộp vào baseline này. V4 của dòng UAV được giữ trong history và matlab_v8.

## Chạy trong MATLAB

Mở một phiên MATLAB mới để tránh chọn nhầm các hàm trùng tên.
Để chạy V8, chuyển Current Folder đến `matlab_v8` rồi chạy:

```matlab
setup_project;
run('scripts/main/maincodev8nUser.m');
```

V8 CCPSO:

```matlab
setup_project;
run('scripts/main/maincodeV8_CCPSO.m');
```

V4–V7 dùng các entry point tương ứng trong `matlab_v8/scripts/main/`.
Để chạy một mốc lịch sử nguyên vẹn, mở phiên MATLAB riêng ở
`history/<commit>/` rồi gọi tên script trong thư mục đó.

Để chạy workflow bài báo đã hiệu chỉnh, dùng phiên MATLAB riêng với
Current Folder là `paper/raw1_corrected/` và chạy `mainCode`.
Để xem/chạy bản mã gốc, dùng Current Folder `paper/Raw0/` và `main_code`.

Không dùng `addpath(genpath(...))` cho toàn bộ thư mục lưu trữ. Các file
`archive/incomplete/` là mã chưa hoàn chỉnh và không nằm trong path do
`setup_project` tạo. Các hàm như `db2pow`/`pow2db` và script BER có yêu cầu
toolbox tương ứng. Cấu hình benchmark đầy đủ có thể chạy lâu.

## Những gì được giữ nguyên

Mô hình, công thức, tham số, thuật toán, seed và log được lưu nguyên trạng.
Một số mã gốc và các bản hiệu chỉnh có tham số/cách triển khai khác PDF;
xem [`MODEL_AND_ALGORITHMS.md`](MODEL_AND_ALGORITHMS.md) để phân biệt.
Không có evaluator EE mới trong thư mục này.

Các hook tương thích mission V10 được thêm vào file V8 hiện tại không
được dùng cho pipeline đóng băng. Nội dung thay đổi vẫn được giữ tại
`provenance/V8_CURRENT_COMPATIBILITY.patch` để truy vết. Kết quả V8 lấy từ
thí nghiệm so sánh là bằng chứng của các run đó; không khẳng định chúng
được sinh lại bằng pipeline trước V10.

Chỉ metadata `.git`, `.DS_Store` và cache Python bị loại khỏi bản sao.
Không sao chép repo lồng nhau vào repo mới.

## Kiểm tra bản lưu

Tại gốc repo `EE-UAV-SWIPT-NOMA-PSO`, chạy:

```bash
shasum -a 256 -c legacy_flight_to_efficiency_v8/provenance/SHA256SUMS.txt
```

Kiểm tra bản sao và phụ thuộc tĩnh đã được thực hiện. Chưa chạy lại các mô
phỏng MATLAB trong đợt lưu trữ; xem `provenance/VERIFICATION.md`.
