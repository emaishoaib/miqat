import SwiftUI

struct CalendarView: View {
    static let width: CGFloat = 280

    @State private var gregorianOffset = 0
    @State private var hijriOffset = 0
    @State private var selected: Date?

    var body: some View {
        let today = Date.now

        VStack(spacing: 24) {
            ControlGroup {
                Button {
                    gregorianOffset -= 1
                    hijriOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")
                Button("Today") {
                    gregorianOffset = 0
                    hijriOffset = 0
                    selected = nil
                }
                .disabled(gregorianOffset == 0 && hijriOffset == 0 && selected == nil)
                Button {
                    gregorianOffset += 1
                    hijriOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next month")
            }
            .fixedSize()

            MonthView(month: MonthGrid(calendar: .gregorian, offset: gregorianOffset, today: today, selected: selected)) { date in
                select(date, today: today)
            }
            MonthView(month: MonthGrid(calendar: .islamicUmmAlQura, offset: hijriOffset, today: today, selected: selected)) { date in
                select(date, today: today)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    private func select(_ date: Date, today: Date) {
        selected = Calendar.current.isDate(date, inSameDayAs: today) ? nil : date
        gregorianOffset = MonthGrid.offset(of: date, from: today, in: .gregorian)
        hijriOffset = MonthGrid.offset(of: date, from: today, in: .islamicUmmAlQura)
    }
}

private struct MonthView: View {
    let month: MonthGrid
    let select: (Date) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(month.title)
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(month.weekdaySymbols.indices, id: \.self) { index in
                    Text(month.weekdaySymbols[index])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
                ForEach(month.cells, id: \.date) { day in
                    Button {
                        select(day.date)
                    } label: {
                        Text("\(day.number)")
                            .monospacedDigit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(day.isToday ? Palette.night : Palette.ink.opacity(day.isInMonth ? 1 : 0.35))
                            .background {
                                if day.isToday {
                                    Circle().fill(Palette.gold)
                                } else if day.isSelected {
                                    Circle().strokeBorder(Palette.gold, lineWidth: 1.5)
                                }
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MonthGrid {
    struct Day {
        let date: Date
        let number: Int
        let isInMonth: Bool
        let isToday: Bool
        let isSelected: Bool
    }

    let title: String
    let weekdaySymbols: [String]
    let cells: [Day]

    init(calendar identifier: Calendar.Identifier, offset: Int, today: Date, selected: Date?) {
        let calendar = Self.calendar(identifier)

        let thisMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let start = calendar.date(byAdding: .month, value: offset, to: thisMonth) ?? thisMonth

        var style = Date.FormatStyle()
        style.calendar = calendar
        title = start.formatted(style.month(.wide).year())

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        weekdaySymbols = Array(symbols[shift...] + symbols[..<shift])

        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let length = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let weeks = (leading + length + 6) / 7
        cells = (0..<weeks * 7).map { index in
            let date = calendar.date(byAdding: .day, value: index - leading, to: start) ?? start
            let isInMonth = calendar.isDate(date, equalTo: start, toGranularity: .month)
            return Day(
                date: date,
                number: calendar.component(.day, from: date),
                isInMonth: isInMonth,
                isToday: isInMonth && calendar.isDate(date, inSameDayAs: today),
                isSelected: isInMonth && selected.map { calendar.isDate(date, inSameDayAs: $0) } == true
            )
        }
    }

    static func offset(of date: Date, from today: Date, in identifier: Calendar.Identifier) -> Int {
        let calendar = Self.calendar(identifier)
        let thisMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let dateMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        return calendar.dateComponents([.month], from: thisMonth, to: dateMonth).month ?? 0
    }

    private static func calendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.locale = .current
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }
}
