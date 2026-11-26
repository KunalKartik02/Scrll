import XCTest
@testable import Scrll

final class MonthGroupingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testGroupsByMonthNewestFirstWithUndatedLast() {
        let items: [(String, Date?)] = [
            ("jan-a", date(2024, 1, 3)),
            ("mar", date(2024, 3, 9)),
            ("none", nil),
            ("jan-b", date(2024, 1, 28)),
            ("dec", date(2023, 12, 31)),
        ]
        let buckets = MonthGrouping.group(items, calendar: calendar) { $0.1 }

        XCTAssertEqual(buckets.map(\.id), ["2024-03", "2024-01", "2023-12", "undated"])
        XCTAssertEqual(buckets[1].items.map { $0.0 }, ["jan-a", "jan-b"])
        XCTAssertNil(buckets.last?.month)
    }

    func testEmptyInput() {
        let buckets = MonthGrouping.group([Date?](), calendar: calendar) { $0 }
        XCTAssertTrue(buckets.isEmpty)
    }

    func testYearMonthOrdering() {
        XCTAssertLessThan(YearMonth(year: 2023, month: 12), YearMonth(year: 2024, month: 1))
        XCTAssertLessThan(YearMonth(year: 2024, month: 1), YearMonth(year: 2024, month: 2))
        XCTAssertEqual(YearMonth(year: 2024, month: 5).key, "2024-05")
    }

    func testTitleIsLocalized() {
        let title = YearMonth(year: 2024, month: 3)
            .title(calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(title, "March 2024")
    }
}
