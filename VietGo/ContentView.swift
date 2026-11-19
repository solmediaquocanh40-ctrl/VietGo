import SwiftUI

/// Gốc điều hướng: 4 thẻ — Trang chủ, Khám phá (Danh mục | Tỉnh thành), Đã lưu, Giới thiệu.
struct ContentView: View {
    @StateObject private var store = PackStore()

    var body: some View {
        Group {
            if let db = store.database {
                TabView {
                    NavigationView { HomeView(db: db) }
                        .tabItem { Label("Trang chủ", systemImage: "house.fill") }
                    NavigationView { ExploreView(db: db) }
                        .tabItem { Label("Khám phá", systemImage: "safari.fill") }
                    NavigationView { SavedView(db: db) }
                        .tabItem { Label("Đã lưu", systemImage: "bookmark.fill") }
                    NavigationView { AboutView(db: db) }
                        .tabItem { Label("Giới thiệu", systemImage: "info.circle.fill") }
                }
                .accentColor(.green)
                .preferredColorScheme(.light) // 0.3.1: khoá giao diện sáng như demo đã duyệt (máy để chế độ tối app vẫn sáng)
            } else {
                Text("Không đọc được gói dữ liệu.")
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Thẻ Khám phá (0.3.1): thanh chuyển Danh mục | Tỉnh thành ngay trong thẻ,
/// thay cho danh sách 34 tỉnh trải dài ở trang chủ trước đây.
struct ExploreView: View {
    let db: PlaceDatabase
    @State private var segment = 0
    @State private var categories: [Category] = []
    private let dataProvinceID = "lam-dong"

    var body: some View {
        VStack(spacing: 0) {
            Picker("Khám phá", selection: $segment) {
                Text("Danh mục").tag(0)
                Text("Tỉnh thành").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            if segment == 0 {
                categoryList
            } else {
                ProvinceListView(db: db)
            }
        }
        .navigationBarTitle("Khám phá", displayMode: .large)
        .onAppear { categories = db.categories(provinceID: dataProvinceID) }
    }

    private var categoryList: some View {
        List {
            Section(header: Text("Danh mục tại Lâm Đồng — tỉnh đang có dữ liệu"),
                    footer: Text("Các tỉnh khác đang được nạp dữ liệu dần; xem danh sách đầy đủ ở mục Tỉnh thành.")) {
                ForEach(categories.filter { $0.count > 0 }) { cat in
                    NavigationLink(destination:
                        PlaceListView(title: cat.nameVi, db: db,
                                      fetchPage: { offset in
                                          db.browse(provinceID: dataProvinceID,
                                                    categoryID: cat.id, offset: offset)
                                      })) {
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(CategoryStyle.color(for: cat.id))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            Text(cat.nameVi)
                            Spacer()
                            Text("\(cat.count)").foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

/// Danh sách 34 tỉnh theo 3 miền (mục Tỉnh thành trong thẻ Khám phá).
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
    }
}

/// Giới thiệu: nguồn dữ liệu, giấy phép và những giới hạn nói thẳng.
struct AboutView: View {
    let db: PlaceDatabase

    var body: some View {
        List {
            Section(header: Text("VIETGO 0.3.2")) {
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
