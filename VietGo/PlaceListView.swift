import SwiftUI

/// Danh sách địa điểm dùng chung: thẻ ảnh + hàng biểu tượng liên hệ,
/// chip lọc (Tất cả / Gần nhất / Đang mở cửa), nút xem bản đồ, tải thêm trang.
struct PlaceListView: View {
    let title: String
    let db: PlaceDatabase
    /// Trả về trang kết quả tại offset; nil = danh sách tĩnh đã nạp sẵn.
    let fetchPage: ((Int) -> [Place])?

    @State private var places: [Place] = []
    @State private var canLoadMore = false
    @State private var filter: Filter = .all
    @ObservedObject private var loc = LocationManager.shared

    enum Filter: String, CaseIterable {
        case all = "Tất cả"
        case nearest = "Gần nhất"
        case openNow = "Đang mở cửa"
    }

    init(title: String, db: PlaceDatabase, places: [Place]) {
        self.title = title
        self.db = db
        self.fetchPage = nil
        _places = State(initialValue: places)
        _canLoadMore = State(initialValue: false)
    }

    init(title: String, db: PlaceDatabase, fetchPage: @escaping (Int) -> [Place]) {
        self.title = title
        self.db = db
        self.fetchPage = fetchPage
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if visible.isEmpty {
                Spacer()
                Text(emptyText)
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                List {
                    ForEach(visible) { place in
                        NavigationLink(destination: PlaceDetailView(place: place, db: db)) {
                            PlaceCardRow(place: place)
                        }
                    }
                    if canLoadMore && filter == .all {
                        Button("Xem thêm địa điểm") { loadMore() }
                            .frame(maxWidth: .infinity)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationBarTitle(title, displayMode: .inline)
        .navigationBarItems(trailing:
            NavigationLink(destination: MapView(places: Array(visible.prefix(300)), db: db)) {
                Image(systemName: "map")
            })
        .onAppear {
            if places.isEmpty { loadMore() }
            loc.requestIfNeeded()
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases, id: \.self) { f in
                    Button(action: { filter = f }) {
                        Text(f.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(filter == f ? Color.green : Color(.systemGray6))
                            .foregroundColor(filter == f ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
                if filter == .nearest && loc.location == nil {
                    Text("Cần cấp quyền vị trí để sắp xếp theo khoảng cách")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var visible: [Place] {
        switch filter {
        case .all:
            return places
        case .openNow:
            return places.filter { place in
                if place.status == "closed_perm" || place.status == "closed_temp" { return false }
                return OpenHours.state(place: place)?.isOpen ?? false
            }
        case .nearest:
            guard loc.location != nil else { return places }
            return places.sorted { (loc.distanceMeters(to: $0) ?? 1e12) < (loc.distanceMeters(to: $1) ?? 1e12) }
        }
    }

    private var emptyText: String {
        switch filter {
        case .openNow:
            return "Không có địa điểm nào đang mở trong số đã tải, hoặc giờ mở cửa chưa có dữ liệu.\nHãy thử xem thêm hoặc bỏ lọc."
        default:
            return "Chưa có địa điểm nào."
        }
    }

    private func loadMore() {
        guard let fetchPage = fetchPage else { return }
        let page = fetchPage(places.count)
        places.append(contentsOf: page)
        canLoadMore = page.count >= 100
    }
}
