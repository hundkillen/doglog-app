import UIKit

/// Builds a shareable PDF summary of a dog's logged month for a vet visit.
enum VetReportPDFExporter {

    private static let pageSize = CGSize(width: 595, height: 842) // A4 at 72 DPI
    private static let margin: CGFloat = 32

    struct Narrative {
        enum Source {
            case aiProfessional
            case localPatterns
        }

        let source: Source
        let paragraphs: [String]
        let bulletPoints: [String]
    }

    /// Resolves the opening analysis: ChatGPT when an API key is available (cached or fresh),
    /// otherwise a local pattern summary for the selected month.
    static func prepareNarrative(dog: Dog, month: Date) async -> Narrative {
        let timeRange = AIPatternAnalyzer.AnalysisTimeRange.thisMonth(month)
        let localInsights = AIPatternAnalyzer().analyzeDog(dog, timeRange: timeRange)
        let service = ChatGPTService.shared

        if service.hasValidAPIKey {
            do {
                let analysis = try await service.analyzeWithChatGPT(
                    dog: dog, timeRange: timeRange, localInsights: localInsights
                )
                return narrative(from: analysis)
            } catch {
                return narrative(from: localInsights)
            }
        }
        return narrative(from: localInsights)
    }

    static func export(dog: Dog, month: Date, narrative: Narrative) throws -> URL {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            throw ExportError.invalidMonth
        }

        let monthStart = calendar.startOfDay(for: interval.start)
        guard let monthEnd = calendar.date(byAdding: DateComponents(day: -1), to: interval.end) else {
            throw ExportError.invalidMonth
        }

        let days = daysInMonth(from: monthStart, through: monthEnd, calendar: calendar)
        let dayData = buildDayData(for: dog, days: days, calendar: calendar)
        guard dayData.contains(where: { $0.hasContent }) else {
            throw ExportError.noData
        }

        let patterns = LaggedPatternAnalyzer().analyze(dog: dog)
        let summary = summarize(ratings: dayData.compactMap(\.rating))

        let title = String(format: "vet.report.title".localized, dog.name)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DogLog_VetReport_\(dog.name.replacingOccurrences(of: " ", with: "_"))_\(UUID().uuidString).pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title] as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        try renderer.writePDF(to: tempURL) { context in
            var drawer = PDFDrawer(context: context, pageSize: pageSize)
            drawer.beginPage()

            drawer.drawText(title, font: .preferredFont(forTextStyle: .title1))
            drawer.drawText(
                formattedPeriod(from: monthStart, to: monthEnd),
                font: .preferredFont(forTextStyle: .subheadline),
                color: .secondaryLabel
            )
            drawer.drawText(dogInfoLine(for: dog), font: .preferredFont(forTextStyle: .body))
            if let ageLine = ageLine(for: dog) {
                drawer.drawText(ageLine, font: .preferredFont(forTextStyle: .body), color: .secondaryLabel)
            }
            drawer.spacer(12)

            drawer.drawText("vet.report.analysis".localized, font: .preferredFont(forTextStyle: .title2).bold())
            let sourceKey = narrative.source == .aiProfessional
                ? "vet.report.analysis_ai"
                : "vet.report.analysis_local"
            drawer.drawText(sourceKey.localized, font: .preferredFont(forTextStyle: .subheadline), color: .secondaryLabel)
            drawer.spacer(4)

            for paragraph in narrative.paragraphs where !paragraph.isEmpty {
                drawer.drawText(paragraph, font: .preferredFont(forTextStyle: .body))
            }
            for bullet in narrative.bulletPoints where !bullet.isEmpty {
                drawer.drawText("• \(bullet)", font: .preferredFont(forTextStyle: .body))
            }
            drawer.spacer(12)

            drawer.drawText("vet.report.summary".localized, font: .preferredFont(forTextStyle: .headline))
            drawer.drawText(
                String(
                    format: "vet.report.summary_line".localized,
                    summary.good, summary.okay, summary.bad, summary.logged
                ),
                font: .preferredFont(forTextStyle: .body)
            )
            drawer.spacer(12)

            drawer.drawText("vet.report.lagged_patterns".localized, font: .preferredFont(forTextStyle: .headline))
            if patterns.isEmpty {
                drawer.drawText(
                    "vet.report.no_patterns".localized,
                    font: .preferredFont(forTextStyle: .body),
                    color: .secondaryLabel
                )
            } else {
                for pattern in patterns {
                    drawer.drawText(
                        "• \(pattern.localizedDescription)",
                        font: .preferredFont(forTextStyle: .body)
                    )
                    drawer.drawText(
                        String(format: "lagged.sample_caption".localized, pattern.sampleCount),
                        font: .preferredFont(forTextStyle: .footnote),
                        color: .secondaryLabel
                    )
                }
            }
            drawer.spacer(12)

            drawer.drawText("vet.report.daily_log".localized, font: .preferredFont(forTextStyle: .headline))
            drawer.drawText(
                "vet.report.daily_log_subtitle".localized,
                font: .preferredFont(forTextStyle: .footnote),
                color: .secondaryLabel
            )
            drawer.spacer(4)

            for entry in dayData where entry.hasContent {
                drawer.ensureSpace(72)
                drawer.drawText(entry.dateLabel, font: .preferredFont(forTextStyle: .subheadline).bold(), color: .label)

                if let rating = entry.rating {
                    drawer.drawText(
                        String(format: "vet.report.day_rating".localized, rating),
                        font: .preferredFont(forTextStyle: .body)
                    )
                }
                if !entry.activityLine.isEmpty {
                    drawer.drawText(
                        String(format: "vet.report.activities".localized, entry.activityLine),
                        font: .preferredFont(forTextStyle: .body)
                    )
                }
                if !entry.contextLine.isEmpty {
                    drawer.drawText(
                        String(format: "vet.report.context_tags".localized, entry.contextLine),
                        font: .preferredFont(forTextStyle: .body),
                        color: .secondaryLabel
                    )
                }
                if let notes = entry.notes, !notes.isEmpty {
                    drawer.drawText(
                        String(format: "vet.report.notes".localized, notes),
                        font: .preferredFont(forTextStyle: .footnote),
                        color: .secondaryLabel
                    )
                }
                drawer.spacer(6)
            }

            drawer.ensureSpace(40)
            drawer.drawText(
                String(format: "vet.report.footer".localized, formattedGeneratedDate()),
                font: .preferredFont(forTextStyle: .caption1),
                color: .tertiaryLabel
            )
        }

        return tempURL
    }

    // MARK: - Narrative builders

    private static func narrative(from analysis: ChatGPTAnalysis) -> Narrative {
        var paragraphs = [analysis.summary]
        if !analysis.behaviorAssessment.progressTrend.isEmpty {
            paragraphs.append(analysis.behaviorAssessment.progressTrend)
        }

        var bullets: [String] = analysis.keyInsights
        if !analysis.behaviorAssessment.strengths.isEmpty {
            bullets.append(String(
                format: "vet.report.strengths".localized,
                analysis.behaviorAssessment.strengths.joined(separator: "; ")
            ))
        }
        if !analysis.behaviorAssessment.concerns.isEmpty {
            bullets.append(String(
                format: "vet.report.concerns".localized,
                analysis.behaviorAssessment.concerns.joined(separator: "; ")
            ))
        }
        for dto in analysis.laggedPatterns ?? [] {
            bullets.append(String(
                format: "vet.report.ai_lagged_item".localized,
                dto.cause, dto.effect, dto.evidence
            ))
        }
        let topRecs = analysis.trainingRecommendations.prefix(2)
        for rec in topRecs {
            bullets.append(String(format: "vet.report.ai_recommendation".localized, rec.issue, rec.technique))
        }

        return Narrative(source: .aiProfessional, paragraphs: paragraphs, bulletPoints: bullets)
    }

    private static func narrative(from insights: AIPatternAnalyzer.DogInsights) -> Narrative {
        var paragraphs: [String] = []

        let moodLabel = displayRating(insights.overallMood.current)
        let trendLabel = trendText(insights.overallMood.direction)
        let improvement = Int(insights.overallMood.improvement.isFinite ? insights.overallMood.improvement : 0)
        paragraphs.append(String(
            format: "vet.report.mood_line".localized,
            moodLabel, trendLabel, improvement
        ))

        if !insights.weeklyTrends.bestDays.isEmpty {
            paragraphs.append(String(
                format: "vet.report.best_days".localized,
                insights.weeklyTrends.bestDays.joined(separator: ", ")
            ))
        }
        if !insights.weeklyTrends.worstDays.isEmpty {
            paragraphs.append(String(
                format: "vet.report.challenging_days".localized,
                insights.weeklyTrends.worstDays.joined(separator: ", ")
            ))
        }

        var bullets: [String] = []
        for insight in insights.behaviorInsights.prefix(3) {
            bullets.append("\(insight.title): \(insight.description)")
        }
        for pattern in insights.activityPatterns.prefix(3) {
            let name = ActivityCatalog.shared.displayName(forStoredType: pattern.activityType)
            let rate = Int((pattern.successRate * 100).rounded())
            bullets.append(String(
                format: "vet.report.activity_pattern".localized,
                name, rate, pattern.frequency
            ))
        }
        let sortedRecs = insights.recommendations.sorted { lhs, rhs in
            priorityRank(lhs.priority) < priorityRank(rhs.priority)
        }
        for rec in sortedRecs.prefix(3) {
            bullets.append("\(rec.title): \(rec.description)")
        }
        for tip in insights.noteRecommendations.prefix(2) {
            bullets.append(tip)
        }

        if bullets.isEmpty {
            bullets.append("vet.report.local_fallback".localized)
        }

        return Narrative(source: .localPatterns, paragraphs: paragraphs, bulletPoints: bullets)
    }

    private static func trendText(_ direction: AIPatternAnalyzer.TrendDirection) -> String {
        switch direction {
        case .up: return "ai.improving_trend".localized
        case .down: return "ai.declining_trend".localized
        case .stable: return "ai.stable_trend".localized
        }
    }

    private static func priorityRank(_ priority: AIPatternAnalyzer.RecommendationPriority) -> Int {
        switch priority {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    // MARK: - Data assembly

    private struct DayEntry {
        let dateLabel: String
        let rating: String?
        let activityLine: String
        let contextLine: String
        let notes: String?
        var hasContent: Bool {
            rating != nil || !activityLine.isEmpty || !contextLine.isEmpty || !(notes?.isEmpty ?? true)
        }
    }

    private struct SummaryCounts {
        let good: Int
        let okay: Int
        let bad: Int
        let logged: Int
    }

    private static func daysInMonth(from start: Date, through end: Date, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private static func buildDayData(for dog: Dog, days: [Date], calendar: Calendar) -> [DayEntry] {
        days.map { day in
            let dayKey = DateFormatter.dayFormatter.string(from: day)
            let activities = dog.activities.filter {
                DateFormatter.dayFormatter.string(from: $0.date) == dayKey
            }
            let rating = dog.dailyRatings.first {
                DateFormatter.dayFormatter.string(from: $0.date) == dayKey
            }

            let activityLine = activities.map { activity in
                let name = ActivityCatalog.shared.displayName(forStoredType: activity.activityType)
                let outcome = "outcome.\(activity.outcome)".localized
                return "\(name) (\(outcome))"
            }.joined(separator: ", ")

            let contextLine = (rating?.contextTags ?? []).map { ContextTag.displayName(for: $0) }.joined(separator: ", ")

            return DayEntry(
                dateLabel: formattedDay(day),
                rating: rating.map { displayRating($0.rating) },
                activityLine: activityLine,
                contextLine: contextLine,
                notes: rating?.notes
            )
        }
    }

    private static func summarize(ratings: [String]) -> SummaryCounts {
        SummaryCounts(
            good: ratings.filter { $0 == "good" }.count,
            okay: ratings.filter { $0 == "okay" }.count,
            bad: ratings.filter { $0 == "bad" }.count,
            logged: ratings.count
        )
    }

    private static func displayRating(_ code: String) -> String {
        switch code {
        case "good": return "rating.good_day".localized
        case "okay": return "rating.okay_day".localized
        case "bad": return "rating.bad_day".localized
        default: return code
        }
    }

    private static func dogInfoLine(for dog: Dog) -> String {
        let breed = dog.breed?.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedText = (breed?.isEmpty == false) ? breed! : "dog.unknown_breed".localized
        return String(format: "vet.report.dog_info".localized, dog.name, breedText)
    }

    private static func ageLine(for dog: Dog) -> String? {
        guard let dob = dog.dateOfBirth else { return nil }
        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        guard years >= 0 else { return nil }
        return String(format: "vet.report.age".localized, "\(years)")
    }

    private static func formattedPeriod(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.getLocale()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return String(format: "vet.report.period".localized, formatter.string(from: start), formatter.string(from: end))
    }

    private static func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.getLocale()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private static func formattedGeneratedDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.getLocale()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    enum ExportError: Error {
        case invalidMonth
        case noData
    }

    // MARK: - PDF drawing

    private struct PDFDrawer {
        let context: UIGraphicsPDFRendererContext
        let pageSize: CGSize
        var y: CGFloat = margin

        mutating func beginPage() {
            context.beginPage()
            y = margin
        }

        mutating func ensureSpace(_ needed: CGFloat) {
            if y + needed > pageSize.height - margin {
                beginPage()
            }
        }

        mutating func spacer(_ amount: CGFloat) {
            y += amount
        }

        mutating func drawText(_ text: String, font: UIFont, color: UIColor = .label) {
            ensureSpace(24)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let width = pageSize.width - 2 * margin
            let height = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: attrs,
                context: nil
            ).height
            ensureSpace(height + 8)
            (text as NSString).draw(
                with: CGRect(x: margin, y: y, width: width, height: height),
                options: .usesLineFragmentOrigin,
                attributes: attrs,
                context: nil
            )
            y += height + 8
        }
    }
}

private extension UIFont {
    func bold() -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
