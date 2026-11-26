import Foundation

struct YearMonth: Hashable, Comparable, Codable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.year = components.year ?? 0
        self.month = components.month ?? 0
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    var key: String { String(format: "%04d-%02d", year, month) }

    func title(calendar: Calendar = .current, locale: Locale = .current) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components) else { return key }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }
}

struct MonthBucket<Item> {
    /// `nil` means the items have no date.
    let month: YearMonth?
    var items: [Item]

    var id: String { month?.key ?? "undated" }
}

enum MonthGrouping {
    /// Groups items by calendar month, newest month first, undated items last.
    /// Items keep their relative input order within each bucket.
    static func group<Item>(
        _ items: [Item],
        calendar: Calendar = .current,
        date: (Item) -> Date?
    ) -> [MonthBucket<Item>] {
        var buckets: [YearMonth: [Item]] = [:]
        var undated: [Item] = []

        for item in items {
            if let itemDate = date(item) {
                buckets[YearMonth(date: itemDate, calendar: calendar), default: []].append(item)
            } else {
                undated.append(item)
            }
        }

        var result = buckets
            .sorted { $0.key > $1.key }
            .map { MonthBucket(month: $0.key, items: $0.value) }
        if !undated.isEmpty {
            result.append(MonthBucket(month: nil, items: undated))
        }
        return result
    }
}
