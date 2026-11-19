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

struct Place: Identifiable {
    let id: String
    let name: String
    let categoryName: String
    let description: String?
    let address: String?
    let addressOld: String?
    let phone: String?
    let lat: Double
    let lon: Double
    let openingHoursJSON: String?
    let priceMin: Int?
    let priceMax: Int?
    let priceUnit: String?
    let priceNote: String?
    let status: String
    let tier: String

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
