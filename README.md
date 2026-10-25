# MoneyMate

Ứng dụng quản lý thu chi cá nhân và hộ gia đình. Frontend được xây dựng bằng
Flutter; backend là ASP.NET Core Web API (.NET 8), xác thực người dùng bằng
Firebase Authentication và lưu dữ liệu trong SQL Server.

## Cấu trúc dự án

- `app_frontend/`: ứng dụng Flutter cho web và thiết bị di động.
- `app_backend/app_backend.Api/`: REST API, xác thực Firebase và truy cập SQL Server.
- `app_doc/SQLQuery1.sql`: script tạo database và các bảng SQL Server.
- `app_doc/THONG_TIN_UNG_DUNG.txt`: ghi chú dự án cũ; một số mô tả trong tài liệu
  này có thể không phản ánh trạng thái tích hợp hiện tại.

## Yêu cầu

- Flutter SDK với Dart `3.9.2` trở lên.
- .NET 8 SDK.
- SQL Server và quyền tạo database/bảng.
- Firebase project đã bật các phương thức đăng nhập mà ứng dụng sử dụng.

## Khởi tạo database và cấu hình backend

1. Cấu hình connection string `ConnectionStrings:MoneyMate` và Firebase project
   ID bằng .NET User Secrets:

   ```powershell
   dotnet user-secrets set "ConnectionStrings:MoneyMate" "Server=localhost;Database=FINANCE_MANAGER;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true" --project app_backend\app_backend.Api\app_backend.csproj
   dotnet user-secrets set "Firebase:ProjectId" "<firebase-project-id>" --project app_backend\app_backend.Api\app_backend.csproj
   ```

   Thay các giá trị ví dụ bằng cấu hình môi trường của bạn. Không commit
   connection string hoặc thông tin bí mật.
2. Tạo schema mới/cập nhật schema bằng EF Core migrations:

   ```powershell
   dotnet tool restore
   dotnet ef database update --project app_backend\app_backend.Api\app_backend.csproj
   ```

   SQL Server phải đang chạy và connection string phải hợp lệ. Nếu database đã
   được tạo bằng script cũ `app_doc/SQLQuery1.sql`, không áp dụng migration
   `InitialCreate` trực tiếp; cần baseline migration phù hợp trước.

   Nếu database cũ đã được tạo bằng `app_doc/SQLQuery1.sql`, chạy riêng script
   `app_doc/SQLQuery2_HouseholdNotifications.sql` để bổ sung thông báo hủy nhóm.
   Không chạy `InitialCreate` lên database cũ.

## Giao dịch mẫu và nhóm gia đình

- Ở màn hình **Ngân hàng & ví điện tử**, chọn **Tạo giao dịch mẫu** để nhập tên
  ngân hàng/ví, loại nguồn và một danh sách nhiều giao dịch thu/chi. Tên, số
  tiền, danh mục và ngày được nhập/chọn trong biểu mẫu; mỗi dòng có mã ổn định
  để tránh lưu trùng khi gửi lại sau lỗi một phần. Không cần thông tin đăng
  nhập, mật khẩu hoặc OTP thật.
- Owner có thể hủy nhóm tại màn hình Gia đình & thành viên. Nhóm được hủy mềm,
  thành viên được rời nhóm, còn giao dịch/ngân sách lịch sử được giữ lại.
  Thành viên khác nhận thông báo trong ứng dụng và có thể đánh dấu đã đọc.
- Database mới nhận bảng thông báo qua EF Core migrations. Database cũ tạo bằng
  `SQLQuery1.sql` cần chạy `SQLQuery2_HouseholdNotifications.sql` trước khi dùng
  tính năng nhóm mới.

Chạy backend trong PowerShell từ thư mục gốc repository:

```powershell
dotnet run --project app_backend\app_backend.Api\app_backend.csproj --launch-profile http
```

Profile `http` chạy API tại `http://localhost:5265`. Trong Development, Swagger
có tại `http://localhost:5265/swagger`.

## Cấu hình và chạy Flutter

1. Cài dependency:

   ```powershell
   cd app_frontend
   flutter pub get
   ```

2. Kiểm tra `lib/firebase_options.dart` được tạo cho Firebase project của bạn.
   Nếu cần tạo lại cấu hình nền tảng, dùng FlutterFire CLI theo hướng dẫn của
   Firebase.
3. Trong terminal thứ hai, từ thư mục `app_frontend`, chạy:

   ```powershell
   flutter run -d chrome
   ```

Frontend Web mặc định gọi API trên cùng hostname với trang Flutter và cổng
`5265`. Vì vậy frontend có thể chạy ở cổng localhost ngẫu nhiên. CORS của backend
Development cho phép origin loopback (`localhost`, `127.0.0.1` và các địa chỉ
loopback khác) trên mọi cổng.

Nếu API dùng cổng khác, đặt cổng khi chạy Flutter:

```powershell
flutter run -d chrome --dart-define=API_PORT=6000
```

Nếu API dùng hostname hoặc scheme khác, cấu hình toàn bộ base URL; giá trị này
được ưu tiên hơn `API_PORT`:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://localhost:7149
```

Origin frontend không thuộc loopback (ví dụ domain triển khai hoặc địa chỉ LAN)
cần được khai báo chính xác trong cấu hình backend `Cors:AllowedOrigins`. Không
dùng wildcard origin. Khi mở frontend qua HTTPS, API cũng phải dùng HTTPS để
tránh trình duyệt chặn mixed content.

Android emulator dùng địa chỉ backend `10.0.2.2`; thiết bị thật cần một URL API
có thể truy cập được, chẳng hạn địa chỉ LAN của máy chạy backend. Backend cũng
phải lắng nghe trên giao diện mạng phù hợp.

## Kiểm tra

Từ thư mục `app_frontend`:

```powershell
flutter analyze
flutter test
```

Build backend:

```powershell
dotnet build app_backend\app_backend.Api\app_backend.csproj
```

Tạo migration tiếp theo sau khi thay đổi entity/model:

```powershell
dotnet tool restore
dotnet ef migrations add <MigrationName> --project app_backend\app_backend.Api\app_backend.csproj
dotnet ef database update --project app_backend\app_backend.Api\app_backend.csproj
```

Các endpoint API cần đăng nhập dùng Firebase ID token; nhận `401` khi gọi trực
tiếp mà không có token là bình thường. `Failed to fetch` trên web thường chỉ ra
API không truy cập được, sai scheme/cổng hoặc CORS; kiểm tra backend đã khởi động
và cấu hình URL/CORS trước khi chẩn đoán xác thực.
