import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    let db: PlaceDatabase

    var body: some View {
        List {
            Section {
                Text(place.name).font(.title2).bold()
                Text("\(place.categoryName) · \(place.statusText)")
                    .foregroundColor(.secondary)
                if let desc = place.description {
                    Text(desc)
                }
            }

            Section(header: Text("Thông tin")) {
                if let address = place.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                }
                if let addressOld = place.addressOld {
                    Label("Địa chỉ cũ: \(addressOld)", systemImage: "mappin")
                        .foregroundColor(.secondary)
                }
                if let phone = place.phone, !phone.isEmpty {
                    if let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                        Link(destination: url) {
                            Label(phone, systemImage: "phone")
                        }
                    } else {
                        Label(phone, systemImage: "phone")
                    }
                }
                Label(String(format: "%.5f, %.5f", place.lat, place.lon),
                      systemImage: "location")
                if let hours = todayHours {
                    Label("Hôm nay: \(hours)", systemImage: "clock")
                } else {
                    Label("Giờ mở cửa: chưa rõ", systemImage: "clock")
                        .foregroundColor(.secondary)
                }
                if let price = place.priceText {
                    Label(price + (place.priceUnit.map { " / \($0)" } ?? ""),
                          systemImage: "tag")
                    if let note = place.priceNote {
                        Text(note).font(.footnote).foregroundColor(.secondary)
                    }
                } else {
                    Label("Giá: chưa có dữ liệu", systemImage: "tag")
                        .foregroundColor(.secondary)
                }
            }

            let metas = db.fieldMeta(placeID: place.id)
            if !metas.isEmpty {
                Section(header: Text("Nguồn & độ tin cậy")) {
                    ForEach(metas) { meta in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(meta.fieldText): \(meta.confidence)/100")
                            Text("Nguồn: \(meta.sourceName ?? meta.sourceType)"
                                 + (meta.verifiedAt.map { " · Xác minh: \($0.prefix(10))" } ?? ""))
                                .font(.footnote).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitle("Địa điểm", displayMode: .inline)
    }

    /// Đọc giờ hôm nay từ JSON opening_hours (schema v1, Mục 3).
    private var todayHours: String? {
        guard let json = place.openingHoursJSON,
              let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let keys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        let weekday = cal.component(.weekday, from: Date()) // 1 = Chủ nhật
        guard let ranges = obj[keys[weekday - 1]] as? [[String]] else { return nil }
        return ranges.map { "\($0[0])–\($0[1])" }.joined(separator: ", ")
    }
}
