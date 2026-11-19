import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Lớp truy cập SQLite (C API trực tiếp, không phụ thuộc ngoài).
/// Gói dữ liệu đóng kèm app được sao sang Documents khi mở lần đầu (hoặc khi
/// gói kèm theo đổi) để app ghi được phần người dùng: đã lưu + hộp thư đi
/// (báo sai). Dữ liệu người dùng được giữ lại khi thay gói mới.
final class PlaceDatabase {
    private var db: OpaquePointer?

    init?(path: String) {
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            return nil
        }
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    /// Mở gói toàn quốc: sao bản đóng kèm sang Documents nếu cần, giữ lại
    /// địa điểm đã lưu và báo cáo chưa gửi của bản cũ.
    static func openBundledPack() -> PlaceDatabase? {
        guard let bundlePath = Bundle.main.path(forResource: "vietnam", ofType: "sqlite") else {
            return nil
        }
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let target = docs.appendingPathComponent("vietnam.sqlite")
        let bundleSize = (try? fm.attributesOfItem(atPath: bundlePath))?[.size] as? Int ?? 0
        let copiedSize = UserDefaults.standard.integer(forKey: "vg_pack_size")
        if !fm.fileExists(atPath: target.path) || copiedSize != bundleSize {
            var savedRows: [[String: String]] = []
            var outboxRows: [[String: String]] = []
            if fm.fileExists(atPath: target.path), let old = PlaceDatabase(path: target.path) {
                savedRows = old.query("SELECT place_id, saved_at FROM saved_places")
                outboxRows = old.query("SELECT id, kind, payload, created_at FROM outbox")
            }
            try? fm.removeItem(at: target)
            try? fm.removeItem(atPath: target.path + "-wal")
            try? fm.removeItem(atPath: target.path + "-shm")
            do {
                try fm.copyItem(atPath: bundlePath, toPath: target.path)
            } catch {
                return PlaceDatabase(path: bundlePath)
            }
            UserDefaults.standard.set(bundleSize, forKey: "vg_pack_size")
            if let fresh = PlaceDatabase(path: target.path) {
                for r in savedRows {
                    fresh.exec("INSERT OR IGNORE INTO saved_places (place_id, saved_at) VALUES (?, ?)",
                               bind: [r["place_id"] ?? "", r["saved_at"] ?? ""])
                }
                for r in outboxRows {
                    fresh.exec("INSERT OR IGNORE INTO outbox (id, kind, payload, created_at) VALUES (?, ?, ?, ?)",
                               bind: [r["id"] ?? "", r["kind"] ?? "", r["payload"] ?? "", r["created_at"] ?? ""])
                }
                return fresh
            }
        }
        return PlaceDatabase(path: target.path)
    }

    // MARK: - Hạ tầng truy vấn

    func query(_ sql: String, bind: [String] = []) -> [[String: String]] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, value) in bind.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), value, -1, SQLITE_TRANSIENT)
        }
        var rows: [[String: String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: String] = [:]
            let cols = sqlite3_column_count(stmt)
            for c in 0..<cols {
                let name = String(cString: sqlite3_column_name(stmt, c))
                if let text = sqlite3_column_text(stmt, c) {
                    row[name] = String(cString: text)
                }
            }
            rows.append(row)
        }
        return rows
    }

    @discardableResult
    func exec(_ sql: String, bind: [String] = []) -> Bool {
        guard let db = db else { return false }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        for (i, value) in bind.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), value, -1, SQLITE_TRANSIENT)
        }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    // MARK: - Cột dùng chung cho Place

    private let placeColumns = """
    p.id, p.name, p.category_id, c.name_vi AS cat, p.description, p.address, p.address_old,
    p.phone, p.website, p.facebook, p.lat, p.lon, p.opening_hours,
    p.price_min, p.price_max, p.price_unit, p.price_note, p.status, p.tier,
    p.facilities, p.hot_basis,
    (SELECT url_thumb FROM place_images i WHERE i.place_id = p.id AND i.deleted_at IS NULL
     ORDER BY i.sort_order LIMIT 1) AS img,
    COALESCE((SELECT confidence FROM field_meta m WHERE m.place_id = p.id AND m.field = 'coords'), 0) AS trust
    """

    private func makePlace(_ r: [String: String]) -> Place {
        Place(id: r["id"] ?? "",
              name: r["name"] ?? "",
              categoryId: r["category_id"] ?? "",
              categoryName: r["cat"] ?? "",
              description: r["description"],
              address: r["address"],
              addressOld: r["address_old"],
              phone: r["phone"],
              website: r["website"],
              facebook: r["facebook"],
              lat: Double(r["lat"] ?? "") ?? 0,
              lon: Double(r["lon"] ?? "") ?? 0,
              openingHoursJSON: r["opening_hours"],
              priceMin: r["price_min"].flatMap { Int($0) },
              priceMax: r["price_max"].flatMap { Int($0) },
              priceUnit: r["price_unit"],
              priceNote: r["price_note"],
              status: r["status"] ?? "unknown",
              tier: r["tier"] ?? "C",
              facilitiesJSON: r["facilities"],
              hotBasis: r["hot_basis"],
              imageThumb: r["img"],
              trust: Int(r["trust"] ?? "") ?? 0)
    }

    // MARK: - Tỉnh & danh mục

    func provinces() -> [Province] {
        query("SELECT id, name, name_old, region, pack_version, place_count FROM provinces ORDER BY name")
            .map { Province(id: $0["id"] ?? "",
                            name: $0["name"] ?? "",
                            nameOld: $0["name_old"],
                            region: $0["region"] ?? "",
                            packVersion: Int($0["pack_version"] ?? "") ?? 0,
                            placeCount: Int($0["place_count"] ?? "") ?? 0) }
    }

    /// Danh mục kèm số địa điểm trong một tỉnh.
    func categories(provinceID: String) -> [Category] {
        let sql = """
        SELECT c.id, c.name_vi,
               (SELECT COUNT(*) FROM places p WHERE p.category_id = c.id
                AND p.province_id = ? AND p.deleted_at IS NULL) AS n
        FROM categories c ORDER BY c.sort_order
        """
        return query(sql, bind: [provinceID])
            .map { Category(id: $0["id"] ?? "", nameVi: $0["name_vi"] ?? "", count: Int($0["n"] ?? "") ?? 0) }
    }

    // MARK: - Danh sách địa điểm

    func hotPlaces(limit: Int = 20) -> [Place] {
        let sql = """
        SELECT \(placeColumns) FROM places p JOIN categories c ON c.id = p.category_id
        WHERE p.hot_basis IS NOT NULL AND p.deleted_at IS NULL
        ORDER BY p.tier, p.name LIMIT \(limit)
        """
        return query(sql).map(makePlace)
    }

    func featuredPlaces(provinceID: String? = nil, limit: Int = 30) -> [Place] {
        var sql = """
        SELECT \(placeColumns) FROM places p JOIN categories c ON c.id = p.category_id
        WHERE p.tier = 'A' AND p.deleted_at IS NULL
        """
        var bind: [String] = []
        if let provinceID = provinceID {
            sql += " AND p.province_id = ?"
            bind.append(provinceID)
        }
        sql += " ORDER BY (img IS NULL), p.name LIMIT \(limit)"
        return query(sql, bind: bind).map(makePlace)
    }

    /// Duyệt theo tỉnh (+ danh mục tuỳ chọn), phân trang bằng limit/offset.
    func browse(provinceID: String, categoryID: String? = nil, limit: Int = 100, offset: Int = 0) -> [Place] {
        var sql = """
        SELECT \(placeColumns) FROM places p JOIN categories c ON c.id = p.category_id
        WHERE p.province_id = ? AND p.deleted_at IS NULL
        """
        var bind: [String] = [provinceID]
        if let categoryID = categoryID {
            sql += " AND p.category_id = ?"
            bind.append(categoryID)
        }
        sql += " ORDER BY p.tier, p.name LIMIT \(limit) OFFSET \(offset)"
        return query(sql, bind: bind).map(makePlace)
    }

    func place(id: String) -> Place? {
        let sql = """
        SELECT \(placeColumns) FROM places p JOIN categories c ON c.id = p.category_id
        WHERE p.id = ?
        """
        return query(sql, bind: [id]).map(makePlace).first
    }

    func places(ids: [String]) -> [Place] {
        guard !ids.isEmpty else { return [] }
        let marks = ids.map { _ in "?" }.joined(separator: ",")
        let sql = """
        SELECT \(placeColumns) FROM places p JOIN categories c ON c.id = p.category_id
        WHERE p.id IN (\(marks)) AND p.deleted_at IS NULL ORDER BY p.name
        """
        return query(sql, bind: ids).map(makePlace)
    }

    /// Tìm kiếm: FTS trên tên đã gấp dấu (hỗ trợ tiền tố khi đang gõ),
    /// cộng khớp số điện thoại và địa chỉ. Có thể giới hạn trong một tỉnh.
    func searchGlobal(rawQuery: String, provinceID: String? = nil, limit: Int = 60) -> [Place] {
        let folded = SearchFold.fold(rawQuery)
        var found: [Place] = []
        var seen = Set<String>()
        func absorb(_ rows: [Place]) {
            for p in rows where !seen.contains(p.id) {
                seen.insert(p.id)
                found.append(p)
            }
        }
        let provinceClause = provinceID == nil ? "" : " AND p.province_id = ?"
        let provinceBind: [String] = provinceID.map { [$0] } ?? []
        if !folded.isEmpty {
            let fts = folded.split(separator: " ").map { "\($0)*" }.joined(separator: " ")
            let sql = """
            SELECT \(placeColumns)
            FROM places_fts f
            JOIN places p ON p.id = f.place_id
            JOIN categories c ON c.id = p.category_id
            WHERE places_fts MATCH ? AND p.deleted_at IS NULL\(provinceClause)
            ORDER BY p.tier, p.name LIMIT \(limit)
            """
            absorb(query(sql, bind: [fts] + provinceBind).map(makePlace))
        }
        let digits = rawQuery.filter { $0.isNumber }
        if digits.count >= 3 {
            let sql = """
            SELECT \(placeColumns) FROM places p JOIN categories c ON c.id = p.category_id
            WHERE p.phone LIKE ? AND p.deleted_at IS NULL\(provinceClause) ORDER BY p.tier, p.name LIMIT 20
            """
            absorb(query(sql, bind: ["%" + digits + "%"] + provinceBind).map(makePlace))
        }
        if rawQuery.count >= 3 {
            let sql = """
            SELECT \(placeColumns) FROM places p JOIN categories c ON c.id = p.category_id
            WHERE p.address LIKE ? AND p.deleted_at IS NULL\(provinceClause) ORDER BY p.tier, p.name LIMIT 20
            """
            absorb(query(sql, bind: ["%" + rawQuery + "%"] + provinceBind).map(makePlace))
        }
        return Array(found.prefix(limit))
    }

    // MARK: - Chi tiết

    func images(placeID: String) -> [PlaceImage] {
        query("SELECT id, url_thumb, url_full, caption, license FROM place_images WHERE place_id = ? AND deleted_at IS NULL ORDER BY sort_order",
              bind: [placeID])
            .map { PlaceImage(id: $0["id"] ?? "", urlThumb: $0["url_thumb"] ?? "",
                              urlFull: $0["url_full"] ?? "", caption: $0["caption"],
                              license: $0["license"]) }
    }

    func fieldMeta(placeID: String) -> [FieldMeta] {
        query("SELECT field, source_type, source_name, confidence, verified_at FROM field_meta WHERE place_id = ? ORDER BY confidence DESC",
              bind: [placeID])
            .map { FieldMeta(field: $0["field"] ?? "",
                             sourceType: $0["source_type"] ?? "",
                             sourceName: $0["source_name"],
                             confidence: Int($0["confidence"] ?? "") ?? 0,
                             verifiedAt: $0["verified_at"]) }
    }

    func safetyPoints(provinceID: String) -> [SafetyPoint] {
        query("SELECT id, type, name, phone, note FROM safety_points WHERE province_id = ? AND deleted_at IS NULL ORDER BY type",
              bind: [provinceID])
            .map { SafetyPoint(id: $0["id"] ?? "",
                               type: $0["type"] ?? "",
                               name: $0["name"] ?? "",
                               phone: $0["phone"],
                               note: $0["note"]) }
    }

    // MARK: - Người dùng: đã lưu + báo sai (ghi vào bản sao Documents)

    func savedIDs() -> Set<String> {
        Set(query("SELECT place_id FROM saved_places").compactMap { $0["place_id"] })
    }

    func setSaved(placeID: String, saved: Bool) {
        if saved {
            let now = ISO8601DateFormatter().string(from: Date())
            exec("INSERT OR IGNORE INTO saved_places (place_id, saved_at) VALUES (?, ?)",
                 bind: [placeID, now])
        } else {
            exec("DELETE FROM saved_places WHERE place_id = ?", bind: [placeID])
        }
    }

    /// Ghi báo cáo sai thông tin vào hộp thư đi (gửi lên máy chủ ở giai đoạn sau).
    func addReport(placeID: String, field: String, note: String) {
        let payload: [String: String] = ["place_id": placeID, "field": field, "note": note]
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let now = ISO8601DateFormatter().string(from: Date())
        exec("INSERT INTO outbox (id, kind, payload, created_at) VALUES (?, 'report', ?, ?)",
             bind: [UUID().uuidString, json, now])
    }
}
