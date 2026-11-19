# VIETGO — App du lịch offline · v0.3.0

Bản đầu tiên có **giao diện đầy đủ + dữ liệu thật**: trang chủ (tìm kiếm toàn quốc, danh mục, "Hot tháng này", "Địa điểm nổi bật"), thẻ địa điểm có ảnh/dải biểu tượng liên hệ, trang chi tiết đầy đủ, bản đồ chấm điểm, lưu địa điểm và báo sai thông tin. Dữ liệu thật của **Lâm Đồng sau sáp nhập: 38.117 địa điểm** nạp từ OpenStreetMap + Overture Maps, phủ lớp tín hiệu hot từ TikTok/Facebook/YouTube.

## Cách build trên GitHub

1. Đẩy toàn bộ cây source này lên repo (nhớ kèm `.github/workflows/build.yml` — file workflow cũng được gửi riêng với tên `build-0.3.0.yml` khi giao source). Nếu đè lên bản cũ, **xoá file cũ trên repo nếu có tên khác**; gói dữ liệu vẫn là `VietGo/Resources/vietnam.sqlite` (bản mới ~55 MB).
2. Vào tab **Actions** → chạy workflow **Build VIETGO (TrollStore IPA)** (tự chạy khi push lên `main`, hoặc bấm Run workflow).
3. Build xong, tải artifact **VietGo-TrollStore-ipa** → được file `VietGo-TrollStore.ipa`.
4. Mở file `.ipa` bằng **TrollStore** trên iPhone để cài.

Runner dùng `macos-latest` + Xcode mới nhất trên runner. Build ở chế độ **không ký** (`CODE_SIGNING_ALLOWED=NO`) — TrollStore tự ký khi cài, không cần tài khoản Apple Developer.

> Lưu ý: sửa workflow xong phải **commit mới**; nút Re-run trên GitHub chạy lại workflow của commit cũ.

## Có gì trong bản 0.3.0

- **Trang chủ**: ô tìm kiếm toàn quốc (tìm theo tên không dấu, món, địa chỉ, **số điện thoại**), hàng 7 danh mục kèm số lượng, băng **Hot tháng này** (13 điểm, ghi rõ căn cứ "Nổi trên TikTok/Facebook · tháng 11/2026"), băng **Địa điểm nổi bật** (48 điểm hạng A), danh sách 34 tỉnh theo 3 miền.
- **Thẻ địa điểm**: ảnh thật của chính địa điểm khi có ảnh Wikimedia (30 điểm nổi tiếng); nơi chưa có ảnh hiện nền màu theo danh mục (không lấy ảnh quán khác minh hoạ). Dòng trạng thái mở/đóng tính từ giờ mở cửa; nơi đã đóng thì ảnh xám + chữ đỏ. Hàng biểu tượng: gọi (mở chọn **Gọi điện / Chat Zalo**), Facebook, Website, Google Maps — chỉ hiện kênh nào có dữ liệu.
- **Chi tiết**: 4 nút Liên hệ / Chỉ đường (Apple Maps hoặc Google Maps) / Chia sẻ / Đã lưu; địa chỉ, giờ cả tuần, tiện ích, nguồn & độ tin cậy từng trường; nút **Báo sai thông tin** (lưu trên máy theo cơ chế hộp thư đi).
- **Danh sách**: chip lọc Tất cả / Gần nhất (cần quyền vị trí) / Đang mở cửa, tải thêm theo trang, nút xem **bản đồ** chấm điểm (nền bản đồ Apple, cần mạng).
- **Dữ liệu Lâm Đồng (38.117 điểm)**: SĐT 77,5% · Facebook 87,2% · địa chỉ 92,1% (74,5% có số nhà/đường) · website 21,5% · giờ mở cửa mới 0,8% (điểm yếu đã biết — nguồn mở rất ít ghi giờ; bổ sung dần qua kiểm chứng và đóng góp người dùng). 33 tỉnh còn lại có khung + số khẩn cấp, địa điểm nạp ở các đợt sau.
- **Đã lưu** giữ lại cả khi cập nhật gói dữ liệu mới (app tự sao gói sang vùng ghi được và bảo toàn phần người dùng).

## Công nghệ

- Swift + SwiftUI, **iOS tối thiểu 14.0** (chỉ dùng tập API iOS 14: NavigationView, TabView, MapKit SwiftUI, StateObject, onChange; không AsyncImage — tự tải + cache ảnh).
- Dữ liệu: SQLite qua C API (`import SQLite3`) — chủ động **không thêm phụ thuộc ngoài** để build CI chắc chắn; chuyển GRDB hay không quyết ở Giai đoạn 1.
- Gói `VietGo/Resources/vietnam.sqlite` sinh từ `schema-v1.sql` + 2 cột tiến hoá cộng thêm (`places.facebook`, `places.hot_basis`). Pipeline nạp dữ liệu nằm ở thư mục `import/` trong bộ tài liệu VIETGO (OSM qua Geofabrik + Overpass lấy ranh giới tỉnh mới; Overture bản 2026-11-18.0 qua DuckDB; gộp/khử trùng; lớp biên tập hot/famous; ảnh Wikimedia kèm giấy phép).

## Hạn chế đã biết (nói thẳng)

- Chưa có bản đồ **offline** (spike PMTiles là Bước 3 của Giai đoạn 0) — bản đồ hiện tại dùng nền Apple nên cần mạng; dữ liệu địa điểm thì offline hoàn toàn.
- Chưa tải gói/delta từ server (Bước 6), chưa tài khoản/đánh giá (Giai đoạn 2), thông báo đẩy không chạy trên bản TrollStore.
- Giá vé/giá món: dữ liệu mở gần như không có → app để trống thay vì bịa số; bổ sung từ nguồn chính thức + kiểm chứng ở giai đoạn sau.
- AppIcon đang trống — TrollStore vẫn cài và chạy bình thường. Bundle ID: `com.vietgo.app`.

## Cấu trúc

```
VietGo.xcodeproj          Project Xcode (scheme: VietGo)
VietGo/
  VietGoApp.swift          Điểm vào app
  ContentView.swift        4 thẻ điều hướng + danh sách tỉnh + Giới thiệu
  HomeView.swift           Trang chủ + màn hình tìm kiếm
  PlaceListView.swift      Danh sách dùng chung (lọc, phân trang, bản đồ)
  PlaceCardView.swift      Thẻ địa điểm + hàng biểu tượng liên hệ + trạng thái
  PlaceDetailView.swift    Chi tiết + phiếu báo sai thông tin
  ProvinceView.swift       Trang tỉnh + An toàn & khẩn cấp
  MapView.swift            Bản đồ chấm điểm (MapKit)
  SavedView.swift          Địa điểm đã lưu
  Helpers.swift            Giờ mở cửa, liên kết liên hệ, tải ảnh, vị trí
  Models.swift             Province / Category / Place / FieldMeta / SafetyPoint
  Database.swift           Lớp SQLite (C API) + sao gói sang vùng ghi được
  SearchFold.swift         Gấp dấu tiếng Việt (cùng quy tắc name_search)
  Assets.xcassets          AppIcon (chưa có hình) + AccentColor
  Base.lproj/              LaunchScreen.storyboard
  Resources/vietnam.sqlite  Gói dữ liệu toàn quốc (34 tỉnh; Lâm Đồng đủ 38.117 điểm)
.github/workflows/build.yml  Workflow build IPA TrollStore
```
