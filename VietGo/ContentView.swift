import SwiftUI

struct ContentView: View {
    @StateObject private var store = PackStore()

    private let regionOrder = ["bac", "trung", "nam"]

    var body: some View {
        NavigationView {
            Group {
                if let db = store.database {
                    let provinces = db.provinces()
                    List {
                        ForEach(regionOrder, id: \.self) { region in
                            let inRegion = provinces.filter { $0.region == region }
                            if !inRegion.isEmpty {
                                Section(header: Text(inRegion[0].regionText)) {
                                    ForEach(inRegion) { province in
                                        NavigationLink(destination: PlaceListView(province: province, db: db)) {
                                            VStack(alignment: .leading, spacing: 4) {
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
                } else {
                    Text("Không đọc được gói dữ liệu.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationBarTitle("VIETGO", displayMode: .large)
        }
    }
}

/// Mở gói SQLite toàn quốc đóng kèm app (34 tỉnh; dữ liệu địa điểm nạp dần theo tỉnh).
final class PackStore: ObservableObject {
    @Published var database: PlaceDatabase?

    init() {
        if let path = Bundle.main.path(forResource: "vietnam", ofType: "sqlite") {
            database = PlaceDatabase(path: path)
        }
    }
}
