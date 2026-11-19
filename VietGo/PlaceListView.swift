import SwiftUI

struct PlaceListView: View {
    let province: Province
    let db: PlaceDatabase

    @State private var keyword: String = ""
    @State private var results: [Place] = []

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Tìm địa điểm (gõ không dấu cũng được)", text: $keyword)
                    .onChange(of: keyword) { _ in reload() }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                Section {
                    if results.isEmpty {
                        Text(keyword.isEmpty
                             ? "Tỉnh này chưa có dữ liệu địa điểm. Gói dữ liệu đang được xây dựng — mục An toàn bên dưới vẫn dùng được."
                             : "Không tìm thấy địa điểm nào khớp.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(results) { place in
                        NavigationLink(destination: PlaceDetailView(place: place, db: db)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name).font(.headline)
                                Text("\(place.categoryName) · \(place.statusText)")
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Section {
                    NavigationLink(destination: SafetyView(province: province, db: db)) {
                        Label("An toàn & khẩn cấp trong tỉnh", systemImage: "cross.case")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationBarTitle(province.name, displayMode: .inline)
        .onAppear { reload() }
    }

    private func reload() {
        let folded = SearchFold.fold(keyword)
        results = db.search(provinceID: province.id, foldedQuery: folded)
    }
}

struct SafetyView: View {
    let province: Province
    let db: PlaceDatabase

    var body: some View {
        List(db.safetyPoints(provinceID: province.id)) { point in
            VStack(alignment: .leading, spacing: 3) {
                Text("\(point.typeText) — \(point.name)").font(.headline)
                if let phone = point.phone {
                    Text(phone).font(.title3).foregroundColor(.blue)
                }
                if let note = point.note {
                    Text(note).font(.subheadline).foregroundColor(.secondary)
                }
            }
        }
        .navigationBarTitle("An toàn", displayMode: .inline)
    }
}
