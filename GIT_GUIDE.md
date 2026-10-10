# Commit baseline và tạo nhánh EE

Repo local đã được khởi tạo tại:

```text
/Users/fuzzefer/Documents/MATLAB/UAV/EE-UAV-SWIPT-NOMA-PSO
```

Nhánh khởi đầu là `main`. Chưa có commit và chưa đặt remote GitHub.
Các lệnh dưới đây chạy trong Terminal. Repo mới độc lập nên việc commit ở
đây không đưa các thay đổi chưa commit của `raw2` vào cùng commit.

## 1. Kiểm tra và commit baseline

```bash
cd /Users/fuzzefer/Documents/MATLAB/UAV/EE-UAV-SWIPT-NOMA-PSO
git status --short --branch
shasum -a 256 -c legacy_flight_to_efficiency_v8/provenance/SHA256SUMS.txt
git add README.md GIT_GUIDE.md .gitignore docs legacy_flight_to_efficiency_v8
git diff --cached --stat
git commit -m "chore: preserve Flight to Efficiency and legacy code through V8"
git tag baseline-flight-to-efficiency-v8
```

Lệnh `git add` đưa file vào danh sách chuẩn bị commit; `git commit` ghi lại
một mốc local. Tag là tên cố định cho mốc baseline, giúp quay lại đối chiếu
sau khi đã phát triển EE.

Nếu Git báo chưa có danh tính tác giả, đặt tên và email cho riêng repo rồi
chạy lại lệnh commit:

```bash
git config user.name "TEN_CUA_BAN"
git config user.email "EMAIL_GITHUB_CUA_BAN"
```

Thay hai giá trị trên bằng thông tin của bạn; có thể dùng email noreply
GitHub nếu tài khoản đang cấu hình email đó.

## 2. Tạo repo trên GitHub và push baseline

Trên [trang tạo repository của GitHub](https://github.com/new):

1. Chọn tài khoản sở hữu và nhập tên `EE-UAV-SWIPT-NOMA-PSO`.
2. Chọn **Private** để giữ repo nghiên cứu ở chế độ riêng tư.
3. Để repo trống: không chọn tạo README, .gitignore hoặc license, vì local
   đã có các file tương ứng.
4. Bấm **Create repository** và sao chép URL HTTPS GitHub cung cấp.

Nếu dùng tài khoản `fuzzefer686` như các repo hiện tại, chạy:

```bash
git remote add origin https://github.com/fuzzefer686/EE-UAV-SWIPT-NOMA-PSO.git
git remote -v
git push -u origin main
git push origin baseline-flight-to-efficiency-v8
```

Nếu chọn tài khoản khác, thay URL bằng URL thực tế của repo vừa tạo.
`git push` tải các commit lên GitHub. Hoàn tất bước này thì baseline đã
được lưu cả ở máy và trên GitHub.

## 3. Tạo nhánh để phát triển EE

```bash
git switch -c feature/ee-optimization
git push -u origin feature/ee-optimization
```

`main` giữ mốc baseline ban đầu; các thay đổi EE tiếp theo được làm trên
`feature/ee-optimization`, ngoài thư mục legacy. Lần đầu push nhánh này nó
trỏ cùng commit với `main`; đây là trạng thái đúng khi chưa viết mã EE.

## 4. Kiểm tra kết quả

```bash
git status --short --branch
git log -1 --oneline
git branch -vv
git tag --list
```

Sau các bước trên, branch hiện tại phải là `feature/ee-optimization`, có
tracking remote tương ứng và có tag `baseline-flight-to-efficiency-v8`.

Không chạy `git init` bên trong thư mục legacy hoặc các thư mục con;
một repo `.git` ở gốc `EE-UAV-SWIPT-NOMA-PSO` là đủ.
