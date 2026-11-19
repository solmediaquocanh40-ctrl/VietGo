import SwiftUI
import CoreLocation

// MARK: - Giờ mở cửa

/// Đọc JSON giờ theo tuần {"mon":[["07:00","22:00"]], ...} và tính trạng thái
/// mở/đóng tại thời điểm hiện tại.
enum OpenHours {
    struct State {
        let isOpen: Bool
        /// "đến 22:00" khi đang mở, "Mở lúc 07:00" / "Mở lúc 07:00 mai" khi đang đóng.
        let detail: String
    }

    static let dayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"] // Calendar.weekday: 1 = Chủ nhật
    static let dayNames: [(key: String, name: String)] = [
        ("mon", "Thứ 2"), ("tue", "Thứ 3"), ("wed", "Thứ 4"), ("thu", "Thứ 5"),
        ("fri", "Thứ 6"), ("sat", "Thứ 7"), ("sun", "Chủ nhật"),
    ]

    static func parse(_ json: String?) -> [String: [(Int, Int)]]? {
        guard let json = json, let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var out: [String: [(Int, Int)]] = [:]
        for (day, value) in obj {
            guard let ranges = value as? [[String]] else { continue }
            out[day] = ranges.compactMap { r in
                guard r.count == 2, let o = minutes(r[0]), let c = minutes(r[1]) else { return nil }
                return (o, c)
            }
        }
        return out.isEmpty ? nil : out
    }

    static func minutes(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    static func text(_ mins: Int) -> String {
        String(format: "%d:%02d", mins / 60 % 24, mins % 60)
    }

    static func state(place: Place, now: Date = Date()) -> State? {
        guard let week = parse(place.openingHoursJSON) else { return nil }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now) // 1..7, 1 = CN
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let todayKey = dayKeys[weekday - 1]
        let yesterdayKey = dayKeys[(weekday + 5) % 7]

        // Ca qua đêm bắt đầu từ hôm qua (đóng < mở)
        if let ranges = week[yesterdayKey] {
            for (o, c) in ranges where c <= o && nowMin < c {
                return State(isOpen: true, detail: "đến \(text(c))")
            }
        }
        if let ranges = week[todayKey] {
            for (o, c) in ranges {
                if c > o && nowMin >= o && nowMin < c {
                    return State(isOpen: true, detail: "đến \(text(c))")
                }
                if c <= o && nowMin >= o {
                    return State(isOpen: true, detail: "đến \(text(c))")
                }
            }
            // Sắp mở hôm nay
            let upcoming = ranges.map { $0.0 }.filter { $0 > nowMin }.min()
            if let up = upcoming {
                return State(isOpen: false, detail: "Mở lúc \(text(up))")
            }
        }
        // Tìm ngày mở tiếp theo trong tuần
        for offset in 1...7 {
            let key = dayKeys[(weekday - 1 + offset) % 7]
            if let ranges = week[key], let first = ranges.map({ $0.0 }).min() {
                let when = offset == 1 ? "mai" : (dayNames.first { $0.key == key }?.name ?? "")
                return State(isOpen: false, detail: "Mở lúc \(text(first)) \(when)")
            }
        }
        return State(isOpen: false, detail: "Đóng cửa cả tuần")
    }

    /// Các dòng giờ theo tuần để hiển thị ở trang chi tiết.
    static func weekLines(place: Place) -> [(String, String)] {
        guard let week = parse(place.openingHoursJSON) else { return [] }
        return dayNames.map { (key, name) in
            guard let ranges = week[key], !ranges.isEmpty else { return (name, "Đóng cửa") }
            let txt = ranges.map { "\(text($0.0)) – \(text($0.1))" }.joined(separator: ", ")
            return (name, txt)
        }
    }
}

// MARK: - Liên hệ

enum ContactLinks {
    /// Rút dãy số đầu tiên đủ dài từ chuỗi SĐT thô (nguồn mở đôi khi gộp 2 số).
    static func primaryDigits(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let groups = raw.components(separatedBy: CharacterSet(charactersIn: "0123456789+").inverted)
        let candidates = groups.map { $0.filter { $0.isNumber } }.filter { $0.count >= 8 }
        return candidates.max(by: { $0.count < $1.count })
    }

    static func telURL(_ raw: String?) -> URL? {
        guard let d = primaryDigits(raw) else { return nil }
        return URL(string: "tel://" + d)
    }

    /// Zalo dùng số dạng 0xxxxxxxxx.
    static func zaloURL(_ raw: String?) -> URL? {
        guard var d = primaryDigits(raw) else { return nil }
        if d.hasPrefix("84") { d = "0" + String(d.dropFirst(2)) }
        return URL(string: "https://zalo.me/" + d)
    }

    static func facebookURL(_ raw: String?) -> URL? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http") { return URL(string: raw) }
        return URL(string: "https://facebook.com/" + raw)
    }

    static func websiteURL(_ raw: String?) -> URL? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http") { return URL(string: raw) }
        return URL(string: "https://" + raw)
    }

    static func googleMapsURL(place: Place) -> URL? {
        URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(place.lat),\(place.lon)")
    }

    static func appleMapsURL(place: Place) -> URL? {
        URL(string: "http://maps.apple.com/?daddr=\(place.lat),\(place.lon)&q=\(place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
}

// MARK: - Ảnh từ xa (tải + cache trong RAM; iOS 14 chưa có AsyncImage)

final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private static let cache = NSCache<NSString, UIImage>()

    func load(_ urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        if let cached = Self.cache.object(forKey: urlString as NSString) {
            image = cached
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            Self.cache.setObject(img, forKey: urlString as NSString)
            DispatchQueue.main.async { self.image = img }
        }.resume()
    }
}

struct RemoteImage: View {
    let urlString: String?
    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(.systemGray5)
            }
        }
        .onAppear { loader.load(urlString) }
    }
}

/// Ảnh bìa của thẻ địa điểm: có ảnh thật thì hiện ảnh, không thì nền màu theo
/// danh mục + biểu tượng (không bao giờ lấy ảnh của quán khác minh hoạ).
struct PlacePhoto: View {
    let place: Place
    var height: CGFloat = 150

    var body: some View {
        ZStack {
            if place.imageThumb != nil {
                RemoteImage(urlString: place.imageThumb)
            } else {
                LinearGradient(gradient: Gradient(colors: [color.opacity(0.85), color]),
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: icon)
                    .font(.system(size: height * 0.32))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(height: height)
        .clipped()
    }

    private var color: Color {
        switch place.categoryId {
        case "an-uong": return Color.orange
        case "ca-phe": return Color(red: 0.6, green: 0.4, blue: 0.2) // nâu (Color.brown là iOS 15+)
        case "luu-tru": return Color.blue
        case "tham-quan": return Color.green
        case "mua-sam": return Color.purple
        case "giai-tri": return Color.pink
        case "dich-vu": return Color.gray
        default: return Color(red: 0.19, green: 0.69, blue: 0.78) // teal (Color.teal là iOS 15+)
        }
    }

    private var icon: String {
        Category(id: place.categoryId, nameVi: place.categoryName, count: 0).icon
    }
}

// MARK: - Chia sẻ

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Vị trí người dùng (cho sắp xếp "Gần nhất")

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    @Published var location: CLLocation?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func distanceText(to place: Place) -> String? {
        guard let loc = location else { return nil }
        let d = loc.distance(from: CLLocation(latitude: place.lat, longitude: place.lon))
        if d < 1000 { return "\(Int(d)) m" }
        return String(format: "%.1f km", d / 1000)
    }

    func distanceMeters(to place: Place) -> Double? {
        location?.distance(from: CLLocation(latitude: place.lat, longitude: place.lon))
    }
}
