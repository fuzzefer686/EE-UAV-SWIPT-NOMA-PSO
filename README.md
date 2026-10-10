# EE-UAV-SWIPT-NOMA-PSO

Baseline V8 của UAV-SWIPT-NOMA, dùng làm nền để phát triển tối ưu Energy
Efficiency (EE). Baseline vẫn dùng fitness dựa trên rate; chưa có evaluator EE.

## Cấu trúc

```text
scripts/             Entry point V8
src/models/          NOMA, SWIPT và phân bổ công suất
src/evaluators/      Fitness quỹ đạo, Joint và Joint+BS
src/optimizers/      Joint PSO, Full PSO, Full IPSO và alpha polishing
reference/           Bài báo Flight to Efficiency và mã gốc Raw0
results/baseline_v8/  20 log V8 đã có
docs/               Định hướng EE, mốc seed 2026, nguồn và checksum
setup_project.m      Cấu hình MATLAB path
```

Mã gốc được giữ nguyên ở `reference/original_code`; V8 có các tham số khác
bài báo. `docs/BASELINE_PROVENANCE.json` ghi nguồn và SHA-256 từng file.
Log là kết quả đã có, chưa được chạy lại sau khi dọn repo.

## Chạy baseline

Mở MATLAB tại gốc repo, rồi chạy:

```matlab
setup_project;
run('scripts/maincodev8nUser.m');
```

Script chạy đường bay thẳng, Joint PSO, Full PSO, Full IPSO và alpha
polishing. Cấu hình đầy đủ có thể chạy lâu. Mã gốc được chạy riêng trong
phiên MATLAB khác, với Current Folder là `reference/original_code`.
Không thêm toàn bộ repo bằng `addpath(genpath(pwd))`, vì mã tham khảo có
hàm trùng tên với pipeline V8.

## Nhánh Git

- `main`: baseline đã rút gọn.
- `feature/ee-optimization`: bắt đầu từ đúng commit của main; dùng viết EE
  và merge lại main khi hoàn tất.
- Tag `baseline-v8-clean`: mốc baseline rút gọn cố định để đối chiếu sau
  khi main đã nhận các thay đổi EE.
- Tag `baseline-flight-to-efficiency-v8`: bộ lưu trữ đầy đủ ban đầu, có
  V4–V7 và các thí nghiệm cũ. Không giữ các bản sao này trong cây thư mục.

Không có CCPSO trong pipeline baseline. Nếu cần thử lại, thực hiện trên
nhánh thí nghiệm riêng. Báo cáo phụ, snapshot trùng lặp, checkpoint,
autosave, mã GA/FA/DE và Python thử nghiệm đã bỏ khỏi cây thư mục baseline.

Xem [hướng dẫn Git](GIT_GUIDE.md) và [định hướng EE](docs/RESEARCH_DIRECTION_EE.md).
