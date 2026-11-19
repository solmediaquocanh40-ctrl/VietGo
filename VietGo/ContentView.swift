import SwiftUI

/// Gốc điều hướng 0.3.0: 4 thẻ — Trang chủ, Tỉnh thành, Đã lưu, Giới thiệu.
struct ContentView: View {
    @StateObject private var store = PackStore()

    var body: some View {
        Group {
            if let db = store.database {
                TabView {
                    NavigationView { HomeView(db: db) }
                        .tabItem { Label("Trang chủ", systemImage: "house.fill") }
                    NavigationView { ProvinceListView(db: db) }
                        .tabItem { Label("Tỉnh thành", systemImage: "map.fill") }
                    NavigationView { SavedView(db: db) }
                        .tabItem { Label("Đã lưu", systemImage: "bookmark.fill") }
                    NavigationView { AboutView(db: db) }
                        .tabItem { Label("Giới thiệu", systemImage: "info.circle.fill") }
                }
                .accentColor(.green)
            } else {
                Text("Không đọc được gói dữ liệu.")
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Danh sách 34 tỉnh theo 3 miền (thẻ Tỉnh thành).
struct ProvinceListView: View {
    let db: PlaceDatabase
    private let regionOrder = ["bac", "trung", "nam"]

    var body: some View {
        let provinces = db.provinces()
        List {
            ForEach(regionOrder, id: \.self) { region in
                let inRegion = provinces.filter { $0.region == region }
                if !inRegion.isEmpty {
                    Section(header: Text(inRegion[0].regionText)) {
                        ForEach(inRegion) { province in
                            NavigationLink(destination: ProvinceView(province: province, db: db)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(province.name).font(.headline)
                                    if let old = province.nameOld {
                                        Text("Gồm: \(old)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    if province.placeCount > 0 {
                                        Text("\(province.placeCount) địa điểm · Gói v\(province.packVersion)")
                                            .font(.subheadline).foregroundColor(.secondary)
                                    } else {
                                        Text("Chưa có dữ liệu địa điểm — sắp bổ sung")
                                            .font(.subheadline).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle("Tỉnh thành", displayMode: .large)
    }
}

/// Giới thiệu: nguồn dữ liệu, giấy phép và những giới hạn nói thẳng.
struct AboutView: View {
    let db: PlaceDatabase

    var body: some View {
        List {
            Section(header: Text("VIETGO 0.3.0")) {
                Text("Bản thử nghiệm nội bộ (cài qua TrollStore). Dữ liệu địa điểm thật của tỉnh Lâm Đồng (gồm Đà Lạt, Phan Thiết – Mũi Né, Tà Đùng sau sáp nhập); 33 tỉnh còn lại sẽ nạp dần.")
                    .font(.subheadline)
            }
            Section(header: Text("Nguồn dữ liệu & giấy phép")) {
                Text("OpenStreetMap — © những người đóng góp OpenStreetMap, giấy phép ODbL.")
                    .font(.subheadline)
                Text("Overture Maps Foundation — dữ liệu địa điểm, giấy phép CDLA Permissive 2.0 / ODbL tuỳ nguồn.")
                    .font(.subheadline)
                Text("Ảnh địa điểm nổi tiếng: Wikimedia Commons, giấy phép ghi ngay dưới mỗi ảnh.")
                    .font(.subheadline)
                Text("Tín hiệu \"Hot tháng này\": biên tập từ nội dung công khai trên TikTok/Facebook/YouTube — chỉ ghi sự thật bằng lời của VIETGO kèm căn cứ, không sao chép nội dung của nhà sáng tạo.")
                    .font(.subheadline)
            }
            Section(header: Text("Nói thẳng về giới hạn")) {
                Text("Phần lớn địa điểm chưa được kiểm chứng thực địa: độ tin cậy hiển thị theo từng trường thông tin, giá và giờ mở cửa còn thiếu nhiều và sẽ bổ sung qua kiểm chứng + đóng góp của người dùng.")
                    .font(.subheadline)
                Text("Nền bản đồ trong mục Bản đồ do Apple cung cấp nên cần mạng; dữ liệu địa điểm thì nằm sẵn trong máy, không cần mạng.")
                    .font(.subheadline)
                Text("Thông báo đẩy sự kiện khẩn (đóng đường, thiên tai) chưa hoạt động ở bản cài qua TrollStore.")
                    .font(.subheadline)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle("Giới thiệu", displayMode: .large)
    }
}

/// Mở gói SQLite toàn quốc (sao sang Documents để ghi được phần người dùng).
final class PackStore: ObservableObject {
    @Published var database: PlaceDatabase?

    init() {
        database = PlaceDatabase.openBundledPack()
    }
}
