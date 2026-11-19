import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Lớp đọc SQLite mỏng (C API trực tiếp, không phụ thuộc ngoài) —
/// đọc gói tỉnh đóng kèm app theo schema v1.
/// Mọi truy vấn chỉ đọc (SQLITE_OPEN_READONLY).
final class PlaceDatabase {
    private var db: OpaquePointer?

    init?(path: String) {
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    // MARK: - Truy vấn dùng chung

    private func query(_ sql: String, bind: [String] = []) -> [[String: String]] {
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

    // MARK: - Dữ liệu

    func provinces() -> [Province] {
        query("SELECT id, name, name_old, region, pack_version, place_count FROM provinces ORDER BY name")
            .map { Province(id: $0["id"] ?? "",
                            name: $0["name"] ?? "",
                            nameOld: $0["name_old"],
                            region: $0["region"] ?? "",
                            packVersion: Int($0["pack_version"] ?? "") ?? 0,
                            placeCount: Int($0["place_count"] ?? "") ?? 0) }
    }

    func places(provinceID: String) -> [Place] {
        let sql = """
        SELECT p.id, p.name, c.name_vi AS cat, p.description, p.address, p.address_old, p.phone,
               p.lat, p.lon,
               p.opening_hours, p.price_min, p.price_max, p.price_unit, p.price_note,
               p.status, p.tier
        FROM places p JOIN categories c ON c.id = p.category_id
        WHERE p.province_id = ? AND p.deleted_at IS NULL
        ORDER BY p.tier, p.name
        """
        return query(sql, bind: [provinceID]).map(makePlace)
    }

    /// Tìm bằng FTS5 trên trường đã bỏ dấu. `foldedQuery` phải đã qua SearchFold.
    func search(provinceID: String, foldedQuery: String) -> [Place] {
        guard !foldedQuery.isEmpty else { return places(provinceID: provinceID) }
        let sql = """
        SELECT p.id, p.name, c.name_vi AS cat, p.description, p.address, p.address_old, p.phone,
               p.lat, p.lon,
               p.opening_hours, p.price_min, p.price_max, p.price_unit, p.price_note,
               p.status, p.tier
        FROM places_fts f
        JOIN places p ON p.id = f.place_id
        JOIN categories c ON c.id = p.category_id
        WHERE places_fts MATCH ? AND p.province_id = ? AND p.deleted_at IS NULL
        ORDER BY p.tier, p.name
        """
        return query(sql, bind: [foldedQuery, provinceID]).map(makePlace)
    }

    func fieldMeta(placeID: String) -> [FieldMeta] {
        query("SELECT field, source_type, source_name, confidence, verified_at FROM field_meta WHERE place_id = ? ORDER BY field",
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

    private func makePlace(_ r: [String: String]) -> Place {
        Place(id: r["id"] ?? "",
              name: r["name"] ?? "",
              categoryName: r["cat"] ?? "",
              description: r["description"],
              address: r["address"],
              addressOld: r["address_old"],
              phone: r["phone"],
              lat: Double(r["lat"] ?? "") ?? 0,
              lon: Double(r["lon"] ?? "") ?? 0,
              openingHoursJSON: r["opening_hours"],
              priceMin: r["price_min"].flatMap { Int($0) },
              priceMax: r["price_max"].flatMap { Int($0) },
              priceUnit: r["price_unit"],
              priceNote: r["price_note"],
              status: r["status"] ?? "unknown",
              tier: r["tier"] ?? "C")
    }
}
