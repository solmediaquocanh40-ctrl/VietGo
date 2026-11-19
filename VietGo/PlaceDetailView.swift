import SwiftUI

/// Trang chi tiết địa điểm theo demo 0.3.0: ảnh bìa, 4 nút hành động
/// (Liên hệ → chọn Gọi điện/Zalo, Chỉ đường → chọn Apple/Google Maps,
/// Chia sẻ, Lưu), thông tin đầy đủ, nguồn & độ tin cậy, báo sai thông tin.
struct PlaceDetailView: View {
    let place: Place
    let db: PlaceDatabase

    @State private var images: [PlaceImage] = []
    @State private var metas: [FieldMeta] = []
    @State private var isSaved = false
    @State private var showCallSheet = false
    @State private var showDirectionsSheet = false
    @State private var showShare = false
    @State private var showReport = false
    @State private var showReportDone = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PlacePhoto(place: place, height: 230)
                VStack(alignment: .leading, spacing: 14) {
                    titleBlock
                    actionRow
                    ContactIconRow(place: place)
                    Divider()
                    infoSection
                    if !images.isEmpty { gallerySection }
                    if !metas.isEmpty { metaSection }
                    reportRow
                    Text("Dữ liệu từ OpenStreetMap (ODbL) và Overture Maps; ảnh (nếu có) từ Wikimedia theo giấy phép ghi kèm. Phần lớn địa điểm chưa được kiểm chứng thực địa — hãy kiểm tra lại giờ mở cửa trước khi đi xa.")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitle("Địa điểm", displayMode: .inline)
        .onAppear {
            images = db.images(placeID: place.id)
            metas = db.fieldMeta(placeID: place.id)
            isSaved = db.savedIDs().contains(place.id)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(place: place, db: db) { showReportDone = true }
        }
        .alert(isPresented: $showReportDone) {
            Alert(title: Text("Đã ghi nhận"),
                  message: Text("Báo cáo được lưu trên máy của anh/chị và sẽ gửi đi khi VIETGO có máy chủ đồng bộ. Cảm ơn bạn đã giúp dữ liệu đúng hơn."),
                  dismissButton: .default(Text("Đóng")))
        }
    }

    private var shareText: String {
        var parts = [place.name]
        if let address = place.address { parts.append(address) }
        if let phone = place.phone { parts.append("SĐT: \(phone)") }
        parts.append("https://www.google.com/maps/search/?api=1&query=\(place.lat),\(place.lon)")
        return parts.joined(separator: "\n")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(place.name)
                    .font(.title3.weight(.bold))
                Spacer(minLength: 0)
                TrustPill(place: place)
            }
            Text(place.categoryName)
                .font(.subheadline).foregroundColor(.secondary)
            StatusLine(place: place)
            if let basis = place.hotBasis {
                Label(basis, systemImage: "flame.fill")
                    .font(.caption).foregroundColor(.orange)
            }
            if let desc = place.description {
                Text(desc).font(.body)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            actionButton("phone.fill", "Liên hệ", enabled: place.phone != nil) { showCallSheet = true }
                .actionSheet(isPresented: $showCallSheet) {
                    ActionSheet(title: Text(place.phone ?? ""), buttons: callButtons)
                }
            actionButton("arrow.triangle.turn.up.right.diamond.fill", "Chỉ đường", enabled: true) {
                showDirectionsSheet = true
            }
            .actionSheet(isPresented: $showDirectionsSheet) {
                ActionSheet(title: Text("Mở chỉ đường bằng"), buttons: [
                    .default(Text("Apple Maps")) {
                        if let u = ContactLinks.appleMapsURL(place: place) { openURL(u) }
                    },
                    .default(Text("Google Maps")) {
                        if let u = ContactLinks.googleMapsURL(place: place) { openURL(u) }
                    },
                    .cancel(Text("Huỷ")),
                ])
            }
            actionButton("square.and.arrow.up", "Chia sẻ", enabled: true) { showShare = true }
            actionButton(isSaved ? "bookmark.fill" : "bookmark", "Đã lưu", enabled: true) {
                isSaved.toggle()
                db.setSaved(placeID: place.id, saved: isSaved)
            }
        }
    }

    private func actionButton(_ symbol: String, _ label: String, enabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18))
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .foregroundColor(enabled ? .green : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!enabled)
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

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let address = place.address {
                infoRow("mappin.and.ellipse", "Địa chỉ", address)
            }
            if let old = place.addressOld {
                infoRow("mappin", "Địa chỉ cũ (trước sáp nhập)", old)
            }
            if let phone = place.phone {
                infoRow("phone", "Điện thoại", phone)
            }
            let lines = OpenHours.weekLines(place: place)
            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Giờ mở cửa", systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                    ForEach(lines, id: \.0) { line in
                        HStack {
                            Text(line.0).font(.subheadline).foregroundColor(.secondary)
                                .frame(width: 76, alignment: .leading)
                            Text(line.1).font(.subheadline)
                        }
                    }
                }
            } else {
                infoRow("clock", "Giờ mở cửa", "Chưa có dữ liệu")
            }
            if let price = place.priceText {
                infoRow("tag", "Giá tham khảo",
                        price + (place.priceUnit.map { " / \($0)" } ?? "")
                            + (place.priceNote.map { " · \($0)" } ?? ""))
            }
            if !place.facilityLabels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Tiện ích", systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                    Text(place.facilityLabels.joined(separator: " · "))
                        .font(.subheadline).foregroundColor(.secondary)
                }
            }
            infoRow("location", "Tọa độ", String(format: "%.5f, %.5f", place.lat, place.lon))
        }
    }

    private func infoRow(_ symbol: String, _ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
            Text(value).font(.subheadline).foregroundColor(.secondary)
        }
    }

    private var gallerySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Ảnh").font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(images) { img in
                        VStack(alignment: .leading, spacing: 4) {
                            RemoteImage(urlString: img.urlFull)
                                .frame(width: 240, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            if let caption = img.caption {
                                Text(caption).font(.caption2).foregroundColor(.secondary)
                                    .lineLimit(1).frame(width: 240, alignment: .leading)
                            }
                            if let lic = img.license {
                                Text(lic).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Nguồn & độ tin cậy").font(.subheadline.weight(.semibold))
            ForEach(metas) { meta in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(meta.fieldText): \(meta.confidence)/100").font(.subheadline)
                        Text("Nguồn: \(meta.sourceName ?? meta.sourceType)"
                             + (meta.verifiedAt.map { " · Xác minh: \($0.prefix(10))" }
                                ?? " · Chưa xác minh thực địa"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private var reportRow: some View {
        HStack {
            Spacer()
            Button(action: { showReport = true }) {
                Label("Báo sai thông tin", systemImage: "flag")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.75, green: 0.35, blue: 0.3))
            }
        }
    }
}

/// Phiếu báo sai: chọn trường sai + ghi chú, ghi vào hộp thư đi trên máy.
struct ReportSheet: View {
    let place: Place
    let db: PlaceDatabase
    let onDone: () -> Void
    @Environment(\.presentationMode) private var presentation
    @State private var field = "opening_hours"
    @State private var note = ""

    private let fields: [(String, String)] = [
        ("opening_hours", "Giờ mở cửa"), ("price", "Giá"), ("address", "Địa chỉ"),
        ("phone", "Số điện thoại"), ("status", "Đã đóng cửa / không còn tồn tại"),
        ("name", "Tên địa điểm"), ("other", "Khác"),
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Địa điểm")) {
                    Text(place.name)
                }
                Section(header: Text("Thông tin nào chưa đúng?")) {
                    Picker("Trường thông tin", selection: $field) {
                        ForEach(fields, id: \.0) { f in
                            Text(f.1).tag(f.0)
                        }
                    }
                }
                Section(header: Text("Ghi chú (không bắt buộc)")) {
                    TextField("Thông tin đúng là…", text: $note)
                }
                Section {
                    Button("Gửi báo cáo") {
                        db.addReport(placeID: place.id, field: field, note: note)
                        presentation.wrappedValue.dismiss()
                        onDone()
                    }
                }
            }
            .navigationBarTitle("Báo sai thông tin", displayMode: .inline)
            .navigationBarItems(trailing: Button("Huỷ") {
                presentation.wrappedValue.dismiss()
            })
        }
    }
}
