# Phát triển trên nhánh EE và merge vào main

Repo GitHub: `fuzzefer686/EE-UAV-SWIPT-NOMA-PSO`.
Sau khi dọn repo, main và feature/ee-optimization cùng trỏ đến commit
baseline rút gọn. Tag baseline-v8-clean giữ cố định mốc đó.

## Phát triển EE

```bash
cd /Users/fuzzefer/Documents/MATLAB/UAV/EE-UAV-SWIPT-NOMA-PSO
git switch feature/ee-optimization
git status --short --branch
```

Sau khi viết và kiểm tra mã EE, chọn file rồi commit/push:

```bash
git add scripts src docs README.md
git diff --cached --stat
git commit -m "feat: implement energy efficiency objective"
git push origin feature/ee-optimization
```

Chỉ chạy commit trên khi đã triển khai nội dung tương ứng.

## Merge vào main

Sau khi nghiệm thu thay đổi và working tree sạch:

```bash
git switch main
git pull --ff-only origin main
git merge --no-ff feature/ee-optimization
git push origin main
git switch feature/ee-optimization
git merge --ff-only main
```

Hoặc tạo Pull Request từ feature/ee-optimization vào main trên GitHub.
Sau khi merge bằng GitHub, pull main rồi cập nhật nhánh EE từ main.
Main sẽ nhận mã EE sau merge; baseline ban đầu vẫn được giữ bởi tag
baseline-v8-clean.

## Kiểm tra hai nhánh

```bash
git rev-parse main feature/ee-optimization
git diff main feature/ee-optimization --stat
```

Ngay sau lần dọn này, hai commit giống nhau và diff trống. Sau khi bắt đầu
viết EE, hai nhánh khác nhau là trạng thái bình thường.

## Lấy lại file lịch sử

```bash
git ls-tree -r --name-only baseline-flight-to-efficiency-v8
```

Tag này giữ nguyên bộ lưu trữ trước khi rút gọn. Nếu cần thuật toán đã
loại khỏi baseline, tạo nhánh thí nghiệm từ main và chỉ phục hồi file cần
thiết; không đưa toàn bộ cây lưu trữ cũ trở lại main.
