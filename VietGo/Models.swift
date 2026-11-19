import Foundation

struct Province: Identifiable {
    let id: String
    let name: String
    let nameOld: String?
    let region: String
    let packVersion: Int
    let placeCount: Int

    var regionText: String {
        switch region {
        case "bac": return "Miền Bắc"
        case "trung": return "Miền Trung"
        case "nam": return "Miền Nam"
        default: return region
        }
    }
}

struct Category: Identifiable {
    let id: String
    let nameVi: String
    let count: Int

    /// SF Symbol đại diện — khớp 7 danh mục của schema v1.
    var icon: String {
        switch id {
        case "an-uong": return "flame.fill"
        case "ca-phe": return "cup.and.saucer.fill"
        case "luu-tru": return "bed.double.fill"
        case "tham-quan": return "camera.fill"
        case "mua-sam": return "bag.fill"
        case "giai-tri": return "gamecontroller.fill"
        case "dich-vu": return "wrench.and.screwdriver.fill"
        default: return "mappin.circle.fill"
        }
    }
}

struct Place: Identifiable {
    let id: String
    let name: String
    let categoryId: String
    let categoryName: String
    let description: String?
    let address: String?
    let addressOld: String?
    let phone: String?
    let website: String?
    let facebook: String?
    let lat: Double
    let lon: Double
    let openingHoursJSON: String?
    let priceMin: Int?
    let priceMax: Int?
    let priceUnit: String?
    let priceNote: String?
    let status: String
    let tier: String
    let facilitiesJSON: String?
    let hotBasis: String?
    let imageThumb: String?
    /// Độ tin cậy của toạ độ (field_meta 'coords') — hiển thị dạng "Tin cậy X/100".
    let trust: Int

    var isHot: Bool { hotBasis != nil }

    var statusText: String {
        switch status {
        case "open": return "Đang hoạt động"
        case "closed_temp": return "Đóng cửa tạm thời"
        case "closed_perm": return "Đã đóng cửa"
        default: return "Chưa rõ trạng thái"
        }
    }

    var priceText: String? {
        guard let lo = priceMin else { return nil }
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = "."
        let loText = fmt.string(from: NSNumber(value: lo)) ?? "\(lo)"
        if let hi = priceMax, hi != lo {
            let hiText = fmt.string(from: NSNumber(value: hi)) ?? "\(hi)"
            return "\(loText) – \(hiText) đ"
        }
        return "\(loText) đ"
    }

    var facilityLabels: [String] {
        guard let json = facilitiesJSON,
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        let map: [String: String] = [
            "wifi": "Wifi", "parking": "Có chỗ đậu xe", "outdoor_seating": "Chỗ ngồi ngoài trời",
            "air_conditioning": "Điều hoà", "delivery": "Giao hàng", "takeaway": "Mang về",
            "wheelchair": "Lối đi xe lăn", "kids": "Hợp trẻ em", "pets": "Cho mang thú cưng",
            "card": "Trả thẻ",
        ]
        return arr.map { map[$0] ?? $0 }
    }
}

struct PlaceImage: Identifiable {
    let id: String
    let urlThumb: String
    let urlFull: String
    let caption: String?
    let license: String?
}

struct FieldMeta: Identifiable {
    let field: String
    let sourceType: String
    let sourceName: String?
    let confidence: Int
    let verifiedAt: String?

    var id: String { field }

    var fieldText: String {
        switch field {
        case "opening_hours": return "Giờ mở cửa"
        case "price": return "Giá"
        case "status": return "Trạng thái"
        case "phone": return "Điện thoại"
        case "coords": return "Tọa độ"
        case "name": return "Tên địa điểm"
        case "address": return "Địa chỉ"
        case "website": return "Website"
        case "facebook": return "Facebook"
        default: return field
        }
    }
}

struct SafetyPoint: Identifiable {
    let id: String
    let type: String
    let name: String
    let phone: String?
    let note: String?

    var typeText: String {
        switch type {
        case "rescue": return "Cứu hộ"
        case "hospital": return "Cấp cứu / bệnh viện"
        case "police": return "Công an"
        case "repair": return "Sửa xe"
        case "pharmacy": return "Nhà thuốc"
        default: return type
        }
    }
}
