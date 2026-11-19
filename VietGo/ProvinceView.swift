import SwiftUI

/// Trang của một tỉnh: tìm trong tỉnh, danh mục kèm số lượng, điểm nổi bật,
/// toàn bộ địa điểm và mục An toàn & khẩn cấp.
struct ProvinceView: View {
    let province: Province
    let db: PlaceDatabase
    @State private var categories: [Category] = []
    @State private var featured: [Place] = []

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if let old = province.nameOld {
                        Text("Gồm: \(old)")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    if province.placeCount > 0 {
                        Text("\(province.placeCount) địa điểm · Gói dữ liệu v\(province.packVersion)")
                            .font(.subheadline).foregroundColor(.secondary)
                    } else {
                        Text("Tỉnh này chưa có dữ liệu địa điểm — đang xây dựng, sẽ bổ sung ở các bản sau. Mục An toàn bên dưới vẫn dùng được.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }

            if province.placeCount > 0 {
                Section {
                    NavigationLink(destination: SearchView(db: db, provinceID: province.id)) {
                        Label("Tìm trong tỉnh này", systemImage: "magnifyingglass")
                    }
                    NavigationLink(destination:
                        PlaceListView(title: "Tất cả địa điểm", db: db,
                                      fetchPage: { offset in
                                          db.browse(provinceID: province.id, offset: offset)
                                      })) {
                        Label("Tất cả địa điểm", systemImage: "list.bullet")
                    }
                }

                if !featured.isEmpty {
                    Section(header: Text("Nổi bật trong tỉnh")) {
                        ForEach(featured) { place in
                            NavigationLink(destination: PlaceDetailView(place: place, db: db)) {
                                PlaceCardRow(place: place)
                            }
                        }
                    }
                }

                Section(header: Text("Danh mục")) {
                    ForEach(categories.filter { $0.count > 0 }) { cat in
                        NavigationLink(destination:
                            PlaceListView(title: cat.nameVi, db: db,
                                          fetchPage: { offset in
                                              db.browse(provinceID: province.id,
                                                        categoryID: cat.id, offset: offset)
                                          })) {
                            HStack(spacing: 12) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(CategoryStyle.color(for: cat.id))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(cat.nameVi).foregroundColor(.primary)
                                Spacer()
                                Text("\(cat.count)").foregroundColor(.secondary)
                            }
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
        .navigationBarTitle(province.name, displayMode: .inline)
        .onAppear {
            categories = db.categories(provinceID: province.id)
            featured = db.featuredPlaces(provinceID: province.id, limit: 10)
        }
    }
}

struct SafetyView: View {
    let province: Province
    let db: PlaceDatabase
    @Environment(\.openURL) private var openURL

    var body: some View {
        List(db.safetyPoints(provinceID: province.id)) { point in
            VStack(alignment: .leading, spacing: 3) {
                Text("\(point.typeText) — \(point.name)").font(.headline)
                if let phone = point.phone {
                    Button(action: {
                        if let url = ContactLinks.telURL(phone) { openURL(url) }
                    }) {
                        Text(phone).font(.title3)
                    }
                }
                if let note = point.note {
                    Text(note).font(.subheadline).foregroundColor(.secondary)
                }
            }
        }
        .navigationBarTitle("An toàn", displayMode: .inline)
    }
}
