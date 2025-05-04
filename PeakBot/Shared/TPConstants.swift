// TPConstants.swift
// Centralized TrainingPeaks API constants and helpers
import Foundation

enum TP {
    static let host = "https://app.trainingpeaks.com"
    static let atlasContext = URL(string: host + "/atlas/v1/context")!
    static func workoutsURL(id: Int, start: Date, end: Date, fields: String) -> URL {
        var comps = URLComponents(string: host + "/atlas/v1/athletes/\(id)/workouts")!
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        comps.queryItems = [
            .init(name: "startDate", value: df.string(from: start)),
            .init(name: "endDate",   value: df.string(from: end)),
            .init(name: "fields",    value: fields),
            .init(name: "tz",        value: "0")
        ]
        return comps.url!
    }
}
