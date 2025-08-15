import SwiftUI

struct CalendarView: View {
    let dog: Dog
    @Binding var selectedDate: Date
    @Binding var showingDailyActivity: Bool
    @Binding var currentMonth: Date
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: currentMonth))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Days of week header
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(getDaysInMonth(), id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            dayRating: getDayRating(for: date),
                            activities: getActivitiesForDate(date)
                        )
                        .onTapGesture {
                            selectedDate = date
                            showingDailyActivity = true
                        }
                    } else {
                        Text("")
                            .frame(height: 40)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
    
    private func getDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let lastOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth)!
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let numberOfDaysInMonth = calendar.component(.day, from: lastOfMonth)
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days of the month
        for day in 1...numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func getDayRating(for date: Date) -> DayRating {
        let dateString = DateFormatter.dayFormatter.string(from: date)
        
        // Check for daily rating first (from DailyRating model)
        let dailyRatingEntry = dog.dailyRatings.first { rating in
            return DateFormatter.dayFormatter.string(from: rating.date) == dateString
        }
        
        if let dailyRating = dailyRatingEntry {
            switch dailyRating.rating {
            case "good":
                return .good
            case "okay":
                return .okay
            case "bad":
                return .bad
            default:
                break
            }
        }
        
        // Fallback to activity outcomes
        let dayActivities = dog.activities.filter { activity in
            return DateFormatter.dayFormatter.string(from: activity.date) == dateString
        }
        
        if dayActivities.isEmpty {
            return .none
        }
        
        let outcomes = dayActivities.map { $0.outcome }
        let goodCount = outcomes.filter { $0 == "good" }.count
        let okayCount = outcomes.filter { $0 == "okay" }.count
        let badCount = outcomes.filter { $0 == "bad" }.count
        
        let totalCount = outcomes.count
        
        if totalCount == 0 {
            return .none
        }
        
        let goodRatio = Double(goodCount) / Double(totalCount)
        let badRatio = Double(badCount) / Double(totalCount)
        
        if goodRatio >= 0.7 {
            return .good
        } else if badRatio >= 0.5 {
            return .bad
        } else {
            return .okay
        }
    }
    
    private func getActivitiesForDate(_ date: Date) -> [Activity] {
        let dateString = DateFormatter.dayFormatter.string(from: date)
        return dog.activities.filter { activity in
            return DateFormatter.dayFormatter.string(from: activity.date) == dateString
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let dayRating: DayRating
    let activities: [Activity]
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayFormatter.string(from: date))
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
            
            // Activity indicators
            if !activities.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(activities.prefix(3).enumerated()), id: \.offset) { index, activity in
                        Circle()
                            .fill(getActivityColor(activity.outcome))
                            .frame(width: 4, height: 4)
                    }
                    if activities.count > 3 {
                        Text("+\(activities.count - 3)")
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(width: 40, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        )
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        }
        
        switch dayRating {
        case .good:
            return Color.green.opacity(0.3)
        case .okay:
            return Color.orange.opacity(0.3)
        case .bad:
            return Color.red.opacity(0.3)
        case .none:
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .blue
        }
        
        switch dayRating {
        case .good:
            return .green
        case .okay:
            return .orange
        case .bad:
            return .red
        case .none:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch dayRating {
        case .none:
            return 0
        default:
            return 2
        }
    }
    
    private func getActivityColor(_ outcome: String) -> Color {
        switch outcome {
        case "good":
            return .green
        case "okay":
            return .orange
        case "bad":
            return .red
        default:
            return .gray
        }
    }
}

enum DayRating {
    case good, okay, bad, none
}

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "Buddy")
        
        return CalendarView(
            dog: sampleDog,
            selectedDate: .constant(Date()),
            showingDailyActivity: .constant(false),
            currentMonth: .constant(Date())
        )
    }
}