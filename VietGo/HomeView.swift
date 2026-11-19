import SwiftUI

/// Trang chủ theo demo 0.3.0 đã duyệt: ô tìm kiếm toàn quốc, hàng danh mục,
/// băng "Hot tháng này" (ghi rõ căn cứ) và "Địa điểm nổi bật".
/// (34 tỉnh thành đã chuyển sang thẻ Khám phá từ 0.3.1 theo yêu cầu của Quoc.)
struct HomeView: View {
    let db: PlaceDatabase
    @State private var categories: [Category] = []
    @State private var hot: [Place] = []
    @State private var featured: [Place] = []

    private let dataProvinceID = "lam-dong"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                searchEntry
                if !categories.isEmpty { categorySection }
                if !hot.isEmpty { hotSection }
                if !featured.isEmpty { featuredSection }
            }
            .padding(.vertical, 16)
        }
        .navigationBarTitle("VIETGO", displayMode: .large)
        .onAppear {
            categories = db.categories(provinceID: dataProvinceID)
            hot = db.hotPlaces()
            featured = db.featuredPlaces(limit: 20)
            LocationManager.shared.requestIfNeeded()
        }
    }

    private var searchEntry: some View {
        NavigationLink(destination: SearchView(db: db)) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                Text("Tìm quán ăn, cà phê, địa điểm, số điện thoại…")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Danh mục tại Lâm Đồng")
                .font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(categories.filter { $0.count > 0 }) { cat in
                        NavigationLink(destination:
                            PlaceListView(title: cat.nameVi, db: db,
                                          fetchPage: { offset in
                                              db.browse(provinceID: dataProvinceID,
                                                        categoryID: cat.id, offset: offset)
                                          })) {
                            VStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 54, height: 54)
                                    .background(LinearGradient(
                                        gradient: Gradient(colors: [CategoryStyle.color(for: cat.id).opacity(0.75),
                                                                    CategoryStyle.color(for: cat.id)]),
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                Text(cat.nameVi)
                                    .font(.caption).foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(cat.count)")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            .frame(width: 72)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var hotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hot tháng này").font(.headline)
                Spacer()
                NavigationLink("Xem tất cả",
                               destination: PlaceListView(title: "Hot tháng này", db: db, places: hot))
                    .font(.subheadline)
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(hot) { place in
                        NavigationLink(destination: PlaceDetailView(place: place, db: db)) {
                            PlaceCardTile(place: place)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Địa điểm nổi bật").font(.headline)
                Spacer()
                NavigationLink("Xem tất cả",
                               destination: PlaceListView(title: "Địa điểm nổi bật", db: db, places: featured))
                    .font(.subheadline)
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(featured) { place in
                        NavigationLink(destination: PlaceDetailView(place: place, db: db)) {
                            PlaceCardTile(place: place)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

}

/// Tìm kiếm toàn quốc: theo tên (không dấu), số điện thoại, địa chỉ.
struct SearchView: View {
    let db: PlaceDatabase
    var provinceID: String? = nil
    @State private var text = ""
    @State private var results: [Place] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Gõ tên, món, địa chỉ hoặc số điện thoại…", text: $text,
                          onCommit: runSearch)
                    .onChange(of: text) { _ in runSearch() }
                if !text.isEmpty {
                    Button(action: { text = ""; results = [] }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()

            if text.isEmpty {
                Text("Tìm được cả khi gõ không dấu, ví dụ: \"ca phe\", \"thac datanla\", hoặc dán số điện thoại của quán.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal)
                Spacer()
            } else if results.isEmpty {
                Text("Không thấy kết quả cho \"\(text)\".")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal)
                Spacer()
            } else {
                List(results) { place in
                    NavigationLink(destination: PlaceDetailView(place: place, db: db)) {
                        PlaceCardRow(place: place)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationBarTitle(provinceID == nil ? "Tìm kiếm" : "Tìm trong tỉnh", displayMode: .inline)
    }

    private func runSearch() {
        guard text.count >= 2 else { results = []; return }
        results = db.searchGlobal(rawQuery: text, provinceID: provinceID)
    }
}
