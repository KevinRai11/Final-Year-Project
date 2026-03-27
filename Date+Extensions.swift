import Foundation

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortDate: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    var shortTime: String {
        formatted(date: .omitted, time: .shortened)
    }

    var monthYearKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: self)
    }
}
