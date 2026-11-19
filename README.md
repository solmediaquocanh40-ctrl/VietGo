# VIETGO — Khung app iOS (Giai đoạn 0) · v0.2.0

Khung app tối thiểu để test trên máy thật bằng **TrollStore**: mở app → chọn tỉnh trong danh sách **34 tỉnh/thành chia 3 miền** → xem danh sách địa điểm đọc từ gói SQLite toàn quốc đóng kèm → tìm kiếm không dấu (FTS5) → xem chi tiết (giờ hôm nay, khoảng giá, nguồn & độ tin cậy theo trường) → mục An toàn & khẩn cấp.

## Cách build trên GitHub

1. Đẩy toàn bộ cây source này lên repo (nhớ kèm `.github/workflows/build.yml` — file workflow cũng được gửi riêng với tên `build-0.2.0.yml` khi giao source).
2. Vào tab **Actions** → chạy workflow **Build VIETGO (TrollStore IPA)** (tự chạy khi push lên `main`, hoặc bấm Run workflow).
3. Build xong, tải artifact **VietGo-TrollStore-ipa** → được file `VietGo-TrollStore.ipa`.
4. Mở file `.ipa` bằng **TrollStore** trên iPhone để cài.

Runner dùng `macos-latest` + Xcode mới nhất trên runner. Build ở chế độ **không ký** (`CODE_SIGNING_ALLOWED=NO`) — TrollStore tự ký khi cài, không cần tài khoản Apple Developer.

> Lưu ý: sửa workflow xong phải **commit mới**; nút Re-run trên GitHub chạy lại workflow của commit cũ.

## Công nghệ

- Swift + SwiftUI, **iOS tối thiểu 14.0** (chỉ dùng tập API iOS 14: NavigationView, StateObject, onChange).
- Dữ liệu: SQLite đọc trực tiếp qua C API (`import SQLite3`, link `libsqlite3.tbd`) — bản khung chủ động **không thêm phụ thuộc ngoài** (kể cả GRDB) để build CI chắc chắn nhất; việc có chuyển sang GRDB hay không sẽ quyết ở Giai đoạn 1.
- Gói toàn quốc `VietGo/Resources/vietnam.sqlite` sinh từ `schema-v1.sql` (xem thư mục tài liệu VIETGO): đủ 34 tỉnh/thành chia 3 miền (Bắc 15, Trung 11, Nam 8), tỉnh hợp nhất ghi rõ các đơn vị cũ hợp thành; mọi tỉnh đều có sẵn 3 số khẩn cấp 112/113/115 ở mục An toàn. **Dữ liệu địa điểm hiện mới có 14 điểm mẫu của Lâm Đồng** (Đà Lạt) — 33 tỉnh còn lại đang trống địa điểm, nạp thật ở Bước 5 (OSM + Overture) và các đợt triển khai trong tài liệu tổng hợp toàn quốc.
- Màn chi tiết địa điểm đã có dòng **số điện thoại bấm để gọi** và dòng địa chỉ cũ (sau sáp nhập) khi dữ liệu có — gói mẫu hiện chưa có số điện thoại thật nào, trường sẽ có số khi nạp dữ liệu thật.

## Dữ liệu mẫu — CHƯA kiểm chứng

Toàn bộ dữ liệu địa điểm trong gói hiện tại chỉ để **test khung hiển thị và tìm kiếm**: tọa độ gần đúng theo trí nhớ bản đồ, **giá và giờ mở cửa là số minh họa**, có một homestay giả lập ghi rõ "Mẫu". Không dùng dữ liệu này cho người dùng thật; dữ liệu thật sẽ nạp bằng pipeline OSM + Overture ở Bước 5 của Giai đoạn 0.

## Cấu trúc

```
VietGo.xcodeproj          Project Xcode (scheme: VietGo)
VietGo/
  VietGoApp.swift          Điểm vào app
  ContentView.swift        Danh sách tỉnh + PackStore (mở gói SQLite)
  PlaceListView.swift      Danh sách địa điểm + ô tìm + mục An toàn
  PlaceDetailView.swift    Chi tiết: giờ hôm nay, giá, nguồn & tin cậy
  Models.swift             Province / Place / FieldMeta / SafetyPoint
  Database.swift           Lớp đọc SQLite (C API, chỉ đọc)
  SearchFold.swift         Gấp dấu tiếng Việt (cùng quy tắc name_search)
  Assets.xcassets          AppIcon (chưa có hình) + AccentColor
  Base.lproj/              LaunchScreen.storyboard
  Resources/vietnam.sqlite  Gói dữ liệu toàn quốc (34 tỉnh)
.github/workflows/build.yml  Workflow build IPA TrollStore
```

## Hạn chế của bản khung (biết trước)

- Chưa có bản đồ (spike PMTiles là Bước 3), chưa tải gói từ server (gói đóng sẵn trong app), chưa đồng bộ delta (Bước 6), chưa tài khoản/đánh giá/báo sai (Giai đoạn 2).
- AppIcon đang trống (chưa có hình) — TrollStore vẫn cài và chạy bình thường.
- Bundle ID tạm: `com.vietgo.app` (đổi được trong project settings, không ảnh hưởng test TrollStore).
