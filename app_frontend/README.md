# Flutter frontend

Ứng dụng Flutter cho web và thiết bị di động. Hướng dẫn khởi chạy đầy đủ (bao
gồm SQL Server, Firebase, backend, CORS và cấu hình URL API) nằm tại
[README dự án](../README.md).

## Chạy nhanh

Từ thư mục này:

```powershell
flutter pub get
flutter run -d chrome
```

Backend phải đang chạy tại `http://localhost:5265` và Firebase phải được cấu
hình để đăng nhập và lấy dữ liệu từ API.

Để đổi cổng API:

```powershell
flutter run -d chrome --dart-define=API_PORT=6000
```

Để đặt đầy đủ URL API (ưu tiên hơn `API_PORT`):

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://localhost:7149
```

## Kiểm tra

```powershell
flutter analyze
flutter test
```
