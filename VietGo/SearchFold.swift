import Foundation

/// Gấp dấu tiếng Việt về dạng tìm kiếm — cùng quy tắc với trường
/// `name_search` phía server (schema-du-lieu-v1.md Mục 4):
/// chuyển thường, bỏ dấu, ký tự lạ thành khoảng trắng, gộp khoảng trắng.
enum SearchFold {
    private static let map: [Character: Character] = {
        var m: [Character: Character] = [:]
        let groups: [(Character, String)] = [
            ("a", "àáảãạăắằẳẵặâấầẩẫậ"),
            ("e", "èéẻẽẹêếềểễệ"),
            ("i", "ìíỉĩị"),
            ("o", "òóỏõọôốồổỗộơớờởỡợ"),
            ("u", "ùúủũụưứừửữự"),
            ("y", "ỳýỷỹỵ"),
            ("d", "đ")
        ]
        for (base, chars) in groups {
            for c in chars { m[c] = base }
        }
        return m
    }()

    static func fold(_ input: String) -> String {
        var out = ""
        out.reserveCapacity(input.count)
        for raw in input.lowercased() {
            if let base = map[raw] {
                out.append(base)
            } else if raw.isLetter || raw.isNumber {
                out.append(raw)
            } else {
                out.append(" ")
            }
        }
        // Gộp khoảng trắng + cắt đầu/cuối
        return out.split(separator: " ").joined(separator: " ")
    }
}
