import SwiftUI

/// Hàng biểu tượng liên hệ dưới mỗi địa điểm — chỉ hiện kênh nào có dữ liệu:
/// gọi/Zalo (khi có SĐT), Facebook, Website, Google Maps (luôn có toạ độ).
struct ContactIconRow: View {
    let place: Place
    @State private var showCallSheet = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 10) {
            if place.phone != nil {
                iconButton("phone.fill", color: .green) { showCallSheet = true }
                    .actionSheet(isPresented: $showCallSheet) {
                        ActionSheet(title: Text(place.phone ?? ""), buttons: callButtons)
                    }
            }
            if let fb = ContactLinks.facebookURL(place.facebook) {
                iconButton("f.circle.fill", color: Color(red: 0.09, green: 0.38, blue: 0.85)) { openURL(fb) }
            }
            if let web = ContactLinks.websiteURL(place.website) {
                iconButton("globe", color: .gray) { openURL(web) }
            }
            if let maps = ContactLinks.googleMapsURL(place: place) {
                iconButton("map.fill", color: .red) { openURL(maps) }
            }
            Spacer(minLength: 0)
        }
    }

    private var callButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if let tel = ContactLinks.telURL(place.phone) {
            buttons.append(.default(Text("Gọi điện")) { openURL(tel) })
        }
        if let zalo = ContactLinks.zaloURL(place.phone) {
            buttons.append(.default(Text("Chat Zalo")) { openURL(zalo) })
        }
        buttons.append(.cancel(Text("Huỷ")))
        return buttons
    }

    private func iconButton(_ symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Dòng trạng thái mở/đóng tính từ giờ mở cửa; nơi đã đóng hẳn thì chữ đỏ.
struct StatusLine: View {
    let place: Place

    var body: some View {
        if place.status == "closed_perm" {
            label("Đã đóng cửa", .red)
        } else if place.status == "closed_temp" {
            label("Đóng cửa tạm thời", .red)
        } else if let st = OpenHours.state(place: place) {
            label(st.isOpen ? "Đang mở · \(st.detail)" : "Đã đóng · \(st.detail)",
                  st.isOpen ? .green : .red)
        } else if place.status == "open" {
            label("Đang hoạt động", .green)
        } else {
            label("Chưa rõ giờ mở cửa", .secondary)
        }
    }

    private func label(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundColor(color)
        }
    }

    var isClosedNow: Bool {
        if place.status == "closed_perm" || place.status == "closed_temp" { return true }
        if let st = OpenHours.state(place: place) { return !st.isOpen }
        return false
    }
}

struct TrustPill: View {
    let place: Place

    var body: some View {
        if place.trust > 0 {
            Text("Tin cậy \(place.trust)/100")
                .font(.caption2).fontWeight(.medium)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(place.trust >= 70 ? Color.green.opacity(0.15) : Color(.systemGray5))
                .foregroundColor(place.trust >= 70 ? .green : .secondary)
                .clipShape(Capsule())
        }
    }
}

/// Thẻ địa điểm dạng hàng ngang — dùng trong các danh sách.
struct PlaceCardRow: View {
    let place: Place
    @ObservedObject private var loc = LocationManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlacePhoto(place: place, height: 104)
                .frame(width: 104)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .saturation(StatusLine(place: place).isClosedNow ? 0.1 : 1.0)
                .opacity(StatusLine(place: place).isClosedNow ? 0.75 : 1.0)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 6) {
                    Text(place.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    TrustPill(place: place)
                }
                Text(metaLine)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1)
                StatusLine(place: place)
                if let basis = place.hotBasis {
                    Text(basis)
                        .font(.caption2).foregroundColor(.orange)
                        .lineLimit(1)
                }
                ContactIconRow(place: place)
            }
        }
        .padding(.vertical, 6)
    }

    private var metaLine: String {
        var parts = [place.categoryName]
        if let price = place.priceText { parts.append(price) }
        if let d = loc.distanceText(to: place) { parts.append(d) }
        return parts.joined(separator: " · ")
    }
}

/// Thẻ dọc cho băng cuộn ngang ở trang chủ (Hot / Nổi bật).
struct PlaceCardTile: View {
    let place: Place
    var width: CGFloat = 230

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PlacePhoto(place: place, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(place.name)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(2)
                .frame(height: 36, alignment: .topLeading)
            Text(place.categoryName + (place.priceText.map { " · \($0)" } ?? ""))
                .font(.caption).foregroundColor(.secondary)
                .lineLimit(1)
            StatusLine(place: place)
            if let basis = place.hotBasis {
                Text(basis).font(.caption2).foregroundColor(.orange).lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}
