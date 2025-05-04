import Foundation

func testAtlasFetch() {
    let now  = Date()
    let from = Calendar.current.date(byAdding: .day, value: -3, to: now)!
    Task {
        do {
           let list = try await TPConnector.shared
                         .fetchWorkoutsAtlas(start: from, end: now)
           print("🟢 OK – got", list.count, "workouts")
        } catch {
           print("🔴 Atlas error", error)
        }
    }
}
