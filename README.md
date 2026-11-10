# MoneyMate

MoneyMate là ứng dụng quản lý thu chi cá nhân và hộ gia đình, gồm frontend
Flutter và backend ASP.NET Core Web API (.NET 8). Ứng dụng xác thực bằng
Firebase Authentication và lưu dữ liệu nghiệp vụ trên SQL Server. Tài khoản
ngân hàng/ví điện tử trong ứng dụng chỉ dùng để mô phỏng, không kết nối dịch vụ
tài chính thật.

## Cấu trúc dự án

- `app_frontend/`: mã nguồn Flutter.
- `app_backend/app_backend.Api/`: Web API, xác thực, nghiệp vụ và EF Core.
- `app_doc/SQLQuery1.sql`: script schema cũ; chỉ dùng cho database đã khởi tạo
  theo phương án này.
- `app_doc/SQLQuery2_HouseholdNotifications.sql`: bổ sung bảng thông báo cho
  database cũ.

## Yêu cầu môi trường

- SQL Server (Developer hoặc Express) đang hoạt động.
- .NET 8 SDK.
- Flutter SDK và Dart `3.9.2` trở lên.
- Firebase project đã bật các phương thức đăng nhập Email/Password và Google
  được ứng dụng sử dụng.

## 1. Cài đặt Database

1. Cài SQL Server, khởi động dịch vụ database và xác định tên server/instance
   (ví dụ `localhost` hoặc `.\SQLEXPRESS`).
2. Với database mới, không cần chạy script SQL cũ bằng tay. EF Core sẽ tạo
   database `FINANCE_MANAGER` và các bảng khi chạy lệnh cập nhật migration ở
   mục **2. Cài đặt backend**.
3. Nếu đang dùng database đã tạo bằng `app_doc\SQLQuery1.sql`, **không** chạy
   migration `InitialCreate` trực tiếp lên database đó. Cần baseline migration
   phù hợp trước khi cập nhật schema. Để bổ sung bảng thông báo cho database
   cũ, chạy `app_doc\SQLQuery2_HouseholdNotifications.sql` một lần trên database
   đó.

## 2. Cài đặt backend

Mở PowerShell tại thư mục gốc repository. Cấu hình chuỗi kết nối và Firebase
project ID bằng User Secrets để không lưu thông tin theo máy trong source code:

```powershell
dotnet restore app_backend\app_backend.Api\app_backend.csproj
dotnet tool restore
dotnet user-secrets set "ConnectionStrings:MoneyMate" "Server=localhost;Database=FINANCE_MANAGER;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true" --project app_backend\app_backend.Api\app_backend.csproj
dotnet user-secrets set "Firebase:ProjectId" "<firebase-project-id>" --project app_backend\app_backend.Api\app_backend.csproj
```

Thay `Server=localhost` và `<firebase-project-id>` theo môi trường của bạn. Sau
khi SQL Server đã chạy và cấu hình kết nối hợp lệ, tạo/cập nhật database:

```powershell
dotnet ef database update --project app_backend\app_backend.Api\app_backend.csproj
```

Project dùng migration EF Core tại
`app_backend\app_backend.Api\Data\Migrations\`. Khi thay đổi entity/schema,
tạo migration và cập nhật database bằng:

```powershell
dotnet ef migrations add <MigrationName> --project app_backend\app_backend.Api\app_backend.csproj
dotnet ef database update --project app_backend\app_backend.Api\app_backend.csproj
```

## 3. Cài đặt frontend

1. Cấu hình `app_frontend\lib\firebase_options.dart` cho Firebase project của
   bạn (có thể tạo lại cấu hình bằng FlutterFire CLI).
2. Trong Firebase Console, bật đăng nhập Email/Password và Google.
3. Cài các package Flutter:

   ```powershell
   Set-Location app_frontend
   flutter pub get
   ```

Frontend Web mặc định gọi API tại `http://localhost:5265`. Android emulator
dùng host `10.0.2.2`; thiết bị thật cần URL API có thể truy cập qua mạng và
backend phải lắng nghe trên giao diện mạng phù hợp.

Có thể đổi cổng API khi chạy Flutter:

```powershell
flutter run -d chrome --dart-define=API_PORT=6000
```

Hoặc cấu hình URL đầy đủ (ưu tiên hơn `API_PORT`):

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://localhost:7149
```

Backend Development cho phép các origin loopback như `localhost` và
`127.0.0.1`. Với frontend chạy trên domain hoặc địa chỉ LAN, khai báo origin
chính xác trong cấu hình backend `Cors:AllowedOrigins`; không dùng wildcard.
Khi frontend dùng HTTPS, API cũng cần HTTPS để tránh lỗi mixed content.

## 4. Kiểm tra

Chạy từ thư mục `app_frontend`:

```powershell
flutter analyze
flutter test
```

Chạy từ thư mục gốc repository để build backend:

```powershell
dotnet build app_backend\app_backend.Api\app_backend.csproj
```

Widget test hiện là smoke test cho giao diện đăng nhập và tổng quan; chưa thay
thế cho kiểm thử end-to-end với Firebase và SQL Server thật.

## 5. Chạy và vận hành

1. Mở PowerShell thứ nhất tại thư mục gốc repository và chạy backend:

   ```powershell
   dotnet run --project app_backend\app_backend.Api\app_backend.csproj --launch-profile http
   ```

   API chạy tại `http://localhost:5265`; Swagger dùng trong môi trường
   Development có tại `http://localhost:5265/swagger`.
2. Mở PowerShell thứ hai tại `app_frontend` và chạy ứng dụng Web:

   ```powershell
   flutter run -d chrome
   ```

   Có thể thay `chrome` bằng thiết bị Flutter đang kết nối, ví dụ Android
   emulator.
3. Đăng ký/đăng nhập bằng Firebase. Sau khi xác thực, ứng dụng đồng bộ hồ sơ,
   giao dịch và ngân sách với backend. Các API cần xác thực dùng Firebase ID
   token; gọi trực tiếp khi chưa đăng nhập có thể nhận `401`.
4. Các thao tác chính:
   - **Tổng quan:** xem số dư tính từ giao dịch, tổng thu/chi, cảnh báo ngân
     sách và giao dịch gần đây.
   - **Giao dịch:** thêm, sửa hoặc xóa giao dịch thu/chi; nhập tiêu đề, số
     tiền, danh mục, ngày và ghi chú.
   - **Ngân sách:** tạo, chỉnh sửa và xóa hạn mức; theo dõi ngân sách dự định
     hoặc đang thực hiện.
   - **Thống kê:** chọn tháng/năm để xem tổng thu, chi, chênh lệch và phân bổ
     chi theo danh mục.
   - **Ngân hàng & ví điện tử:** tạo tài khoản và giao dịch mẫu. Dữ liệu được
     lưu để minh họa nhưng không phải giao dịch với ngân hàng/ví thật.
   - **Cá nhân / Gia đình:** cập nhật hồ sơ và quản lý nhóm/thành viên. Lời mời
     thành viên qua email hiện chỉ là giao diện mô phỏng, không gửi email và
     không lưu lời mời vào backend.

Nếu frontend báo không kết nối được API, kiểm tra backend đã chạy đúng cổng,
URL API có thể truy cập và cấu hình CORS trước khi chẩn đoán vấn đề xác thực.
