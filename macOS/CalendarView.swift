import SwiftUI

struct CalendarView: View {
    static let width: CGFloat = 280

    @AppStorage(MenuBarDate.calendarKey) private var menuBarCalendar = MenuBarDate.gregorian
    @State private var kind: MenuBarDate?
    @State private var monthOffset = 0

    var body: some View {
        let shown = kind ?? menuBarCalendar
        let month = MonthGrid(kind: shown, offset: monthOffset, today: .now)

        VStack(spacing: 16) {
            Picker("Calendar", selection: Binding(get: { shown }, set: { kind = $0; monthOffset = 0 })) {
                ForEach(MenuBarDate.allCases, id: \.self) { option in
                    Text(option.name)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Button {
                    monthOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")
                Spacer()
                VStack(spacing: 2) {
                    Text(month.title)
                        .font(.headline)
                    Text(month.otherCalendarRange)
                        .font(.caption)
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
                Spacer()
                Button {
                    monthOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next month")
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(month.weekdaySymbols.indices, id: \.self) { index in
                    Text(month.weekdaySymbols[index])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
                ForEach(month.cells.indices, id: \.self) { index in
                    if let day = month.cells[index] {
                        Text("\(day.number)")
                            .monospacedDigit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(day.isToday ? Palette.night : Palette.ink)
                            .background {
                                if day.isToday {
                                    Circle().fill(Palette.gold)
                                }
                            }
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }

            if monthOffset != 0 {
                Button("Back to today") {
                    monthOffset = 0
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Palette.gold)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

private struct MonthGrid {
    struct Day {
        let number: Int
        let isToday: Bool
    }

    let title: String
    let otherCalendarRange: String
    let weekdaySymbols: [String]
    let cells: [Day?]

    init(kind: MenuBarDate, offset: Int, today: Date) {
        var calendar = Calendar(identifier: kind == .hijri ? .islamicUmmAlQura : .gregorian)
        calendar.locale = .current
        calendar.firstWeekday = Calendar.current.firstWeekday
        var other = Calendar(identifier: kind == .hijri ? .gregorian : .islamicUmmAlQura)
        other.locale = .current

        let thisMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let start = calendar.date(byAdding: .month, value: offset, to: thisMonth) ?? thisMonth
        let length = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let end = calendar.date(byAdding: .day, value: length - 1, to: start) ?? start

        var style = Date.FormatStyle()
        style.calendar = calendar
        title = start.formatted(style.month(.wide).year())

        var otherStyle = Date.FormatStyle()
        otherStyle.calendar = other
        let first = start.formatted(otherStyle.month(.wide).year())
        let last = end.formatted(otherStyle.month(.wide).year())
        otherCalendarRange = first == last ? first : "\(first) – \(last)"

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        weekdaySymbols = Array(symbols[shift...] + symbols[..<shift])

        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        cells = Array(repeating: nil, count: leading) + (1...length).map { number in
            let date = calendar.date(byAdding: .day, value: number - 1, to: start) ?? start
            return Day(number: number, isToday: calendar.isDate(date, inSameDayAs: today))
        }
    }
}
