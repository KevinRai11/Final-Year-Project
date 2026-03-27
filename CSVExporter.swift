import Foundation

struct CSVExporter {

    static func export(csvString: String, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func buildCSV(headers: [String], rows: [[String]]) -> String {
        var lines = [headers.joined(separator: ",")]
        for row in rows {
            let escaped = row.map { field -> String in
                let cleaned = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(cleaned)\""
            }
            lines.append(escaped.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
