#if os(macOS)
import AppKit
#endif
import Foundation
import Combine
import SwiftUI
import Swifter

// MARK: - OAuth Token Model
struct StravaOAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval // UNIX timestamp
}

// MARK: - Activity Models
struct StravaActivitySummary: Codable, Identifiable {
    let id: Int
    let name: String?
    let startDateLocal: Date?
    let distance: Double?
    let movingTime: Int?
    let averageWatts: Double?
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let tss: Double?

    enum CodingKeys: String, CodingKey {
        case id, name
        case startDateLocal = "start_date_local"
        case distance, movingTime = "moving_time"
        case averageWatts = "average_watts"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case tss
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        if let ds = try? c.decode(String.self, forKey: .startDateLocal) {
            if let d = ISO8601DateFormatter().date(from: ds) {
                startDateLocal = d
            } else {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                startDateLocal = f.date(from: ds)
            }
        } else {
            startDateLocal = nil
        }
        distance = try? c.decodeIfPresent(Double.self, forKey: .distance)
        movingTime = try? c.decodeIfPresent(Int.self, forKey: .movingTime)
        averageWatts = try? c.decodeIfPresent(Double.self, forKey: .averageWatts)
        averageHeartrate = try? c.decodeIfPresent(Double.self, forKey: .averageHeartrate)
        maxHeartrate = try? c.decodeIfPresent(Double.self, forKey: .maxHeartrate)
        tss = try? c.decodeIfPresent(Double.self, forKey: .tss)
    }
}

// MARK: - StravaService
@MainActor
final class StravaService: ObservableObject {
    static let shared = StravaService()

    private let clientID     = "156540" // TODO: move to .xcconfig
    private let clientSecret = "44a03f92d978c830b493f5f4218eb48b8e7b2dbe" // TODO: move to .xcconfig
    private let redirectURI  = "http://localhost:8080/callback"

    @Published var tokens: StravaOAuthTokens? {
        didSet {
            if let t = tokens {
                KeychainHelper.stravaAccessToken  = t.accessToken
                KeychainHelper.stravaRefreshToken = t.refreshToken
                KeychainHelper.stravaExpiresAt    = t.expiresAt
            } else {
                KeychainHelper.clearStravaTokens()
            }
        }
    }
    private var oauthServer: HttpServer?

    let coreData = CoreDataModel.shared

    // MARK: - FTP
    @Published var ftp: Double = 218.0 // default, can be loaded from Core Data or UserDefaults
    private let ftpKey = "ftp"

    // MARK: - OAuth Flow
    init() {
        // Load tokens from Keychain if available
        if let access = KeychainHelper.stravaAccessToken,
           let refresh = KeychainHelper.stravaRefreshToken,
           let expires = KeychainHelper.stravaExpiresAt {
            self.tokens = StravaOAuthTokens(accessToken: access, refreshToken: refresh, expiresAt: expires)
        }
        loadFTP() // Load FTP from UserDefaults at startup
    }

    func startOAuth(completion: @escaping (Bool) -> Void) {
        let server = HttpServer()
        server["/callback"] = { [weak self] req in
            guard let self = self,
                  let code = req.queryParams.first(where: { $0.0 == "code" })?.1
            else { return .badRequest(nil) }
            Task {
                do {
                    let t = try await self.exchangeCodeForToken(code: code)
                    self.tokens = t
                    completion(true)
                } catch {
                    print("[StravaService] token exchange failed:", error)
                    completion(false)
                }
            }
            return .ok(.html("<h2>Strava authorization complete. You may close this window.</h2>"))
        }
        do {
            try server.start(8080, forceIPv4: true)
            oauthServer = server
            if let url = authorizeURL(scopes: ["activity:read_all", "profile:read_all"]) {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }
        } catch {
            print("[StravaService] couldn’t start callback server:", error)
            completion(false)
        }
    }

    func stopOAuthServer() { oauthServer?.stop(); oauthServer = nil }

    private func authorizeURL(scopes: [String]) -> URL? {
        var c = URLComponents(string: "https://www.strava.com/oauth/authorize")
        c?.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scopes.joined(separator: ","))
        ]
        return c?.url
    }

    private func exchangeCodeForToken(code: String) async throws -> StravaOAuthTokens {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        req.httpBody = body.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "Strava", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "token exchange failed"])
        }
        struct R: Codable { let access_token, refresh_token: String; let expires_at: TimeInterval }
        let r = try JSONDecoder().decode(R.self, from: data)
        return StravaOAuthTokens(accessToken: r.access_token, refreshToken: r.refresh_token, expiresAt: r.expires_at)
    }

    // MARK: - Token Expiry & Refresh
    private func isTokenExpired() -> Bool {
        guard let expiresAt = tokens?.expiresAt else { return true }
        return Date() >= Date(timeIntervalSince1970: expiresAt)
    }

    private func refreshAccessTokenIfNeeded(completion: @escaping (Bool) -> Void) {
        if !isTokenExpired() {
            completion(true)
            return
        }
        guard let refreshToken = tokens?.refreshToken else {
            print("[StravaService] No refresh token available"); completion(false); return
        }
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = params.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { completion(false); return }
            if let error = error { print("[StravaService] Token refresh error: \(error)"); completion(false); return }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let accessToken = json["access_token"] as? String,
                let refreshToken = json["refresh_token"] as? String,
                let expiresAt = json["expires_at"] as? TimeInterval else {
                print("[StravaService] Token refresh: invalid response"); completion(false); return
            }
            DispatchQueue.main.async {
                self.tokens = StravaOAuthTokens(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
                print("[StravaService] Token refreshed, expires at \(expiresAt)")
                completion(true)
            }
        }.resume()
    }

    // Async/await version for use with async closures
    func withFreshToken<T>(_ block: @escaping () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            refreshAccessTokenIfNeeded { success in
                if success {
                    Task {
                        do {
                            let result = try await block()
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "Strava", code: 401, userInfo: [NSLocalizedDescriptionKey: "Could not refresh token"]))
                }
            }
        }
    }

    // MARK: - Sync Methods (now use Core Data)
    func syncRecentActivities() async throws {
        print("[StravaService] syncRecentActivities() called")
        guard let tokens = tokens else { throw NSError(domain: "Strava", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) }
        let context = coreData.container.viewContext
        var page = 1
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        var fetched = 0
        repeat {
            let activities = try await withFreshToken { [self] in
                try await fetchActivities(after: sevenDaysAgo, perPage: 50, page: page)
            }
            for summary in activities {
                _ = try await upsertActivity(summary, context: context)
            }
            fetched = activities.count
            page += 1
        } while fetched > 0
        // Pre-save logging
        let workouts = try? context.fetch(NSFetchRequest<Workout>(entityName: "Workout"))
        let streams = try? context.fetch(NSFetchRequest<Stream>(entityName: "Stream"))
        print("[StravaService] About to save. Workouts: \(workouts?.map { $0.workoutId ?? -1 } ?? [])")
        print("[StravaService] Streams: \(streams?.map { $0.workoutId ?? -1 } ?? [])")
        do {
            try context.save()
        } catch {
            print("[StravaService] ERROR: Core Data save failed: \(error.localizedDescription)")
            let nserror = error as NSError
            print("[StravaService] Core Data error userInfo: \(nserror.userInfo)")
            throw error
        }
        print("[StravaService] syncRecentActivities() finished")
    }

    func syncHistory() async throws {
        print("[StravaService] syncHistory() called")
        guard let tokens = tokens else { throw NSError(domain: "Strava", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) }
        let context = coreData.container.viewContext
        var page = 1
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        var fetched = 0
        repeat {
            let activities = try await withFreshToken { [self] in
                try await fetchActivities(after: sevenDaysAgo, perPage: 50, page: page)
            }
            for summary in activities {
                _ = try await upsertActivity(summary, context: context)
            }
            fetched = activities.count
            page += 1
        } while fetched > 0
        // Pre-save logging
        let workouts = try? context.fetch(NSFetchRequest<Workout>(entityName: "Workout"))
        let streams = try? context.fetch(NSFetchRequest<Stream>(entityName: "Stream"))
        print("[StravaService] About to save. Workouts: \(workouts?.map { $0.workoutId ?? -1 } ?? [])")
        print("[StravaService] Streams: \(streams?.map { $0.workoutId ?? -1 } ?? [])")
        do {
            try context.save()
        } catch {
            print("[StravaService] ERROR: Core Data save failed: \(error.localizedDescription)")
            let nserror = error as NSError
            print("[StravaService] Core Data error userInfo: \(nserror.userInfo)")
            throw error
        }
        print("[StravaService] syncHistory() finished")
    }

    func syncSixMonthsHistory() async throws {
        print("[StravaService] syncSixMonthsHistory() called")
        guard let tokens = tokens else { throw NSError(domain: "Strava", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) }
        let context = coreData.container.viewContext
        var page = 1
        let now = Date()
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: now) ?? now
        var fetched = 0
        repeat {
            let activities = try await withFreshToken { [self] in
                try await fetchActivities(after: sixMonthsAgo, perPage: 50, page: page)
            }
            for summary in activities {
                _ = try await upsertActivity(summary, context: context)
            }
            fetched = activities.count
            page += 1
        } while fetched > 0
        let workouts = try? context.fetch(NSFetchRequest<Workout>(entityName: "Workout"))
        let streams = try? context.fetch(NSFetchRequest<Stream>(entityName: "Stream"))
        print("[StravaService] About to save. Workouts: \(workouts?.map { $0.workoutId ?? -1 } ?? [])")
        print("[StravaService] Streams: \(streams?.map { $0.workoutId ?? -1 } ?? [])")
        do {
            try context.save()
        } catch {
            print("[StravaService] ERROR: Core Data save failed: \(error.localizedDescription)")
            let nserror = error as NSError
            print("[StravaService] Core Data error userInfo: \(nserror.userInfo)")
            throw error
        }
        print("[StravaService] syncSixMonthsHistory() finished")
    }

    // MARK: - FTP
    func saveFTP(_ ftpValue: Double) {
        self.ftp = ftpValue
        UserDefaults.standard.set(ftpValue, forKey: ftpKey)
        print("[StravaService] FTP saved: \(ftpValue)")
    }

    func loadFTP() {
        if let value = UserDefaults.standard.value(forKey: ftpKey) as? Double {
            self.ftp = value
            print("[StravaService] FTP loaded from UserDefaults: \(value)")
        } else {
            print("[StravaService] No FTP found in UserDefaults, using default: \(ftp)")
        }
    }

    // MARK: - Fetch Activities
    func fetchActivities(after: Date? = nil, perPage: Int = 50, page: Int = 1) async throws -> [StravaActivitySummary] {
        guard let t = tokens else { throw NSError(domain: "Strava", code: 401, userInfo: nil) }
        var c = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
        c.queryItems = [
            .init(name: "per_page", value: "\(perPage)"),
            .init(name: "page", value: "\(page)")
        ]
        if let after = after {
            c.queryItems?.append(.init(name: "after", value: "\(Int(after.timeIntervalSince1970))"))
        }
        var req = URLRequest(url: c.url!)
        req.setValue("Bearer \(t.accessToken)", forHTTPHeaderField: "Authorization")
        let (d, r) = try await URLSession.shared.data(for: req)
        if let httpResp = r as? HTTPURLResponse, httpResp.statusCode != 200 {
            let body = String(data: d, encoding: .utf8) ?? ""
            print("[StravaService] HTTP error: \(httpResp.statusCode), body: \(body)")
            throw NSError(domain: "Strava", code: 2, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResp.statusCode): \(body)"])
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode([StravaActivitySummary].self, from: d)
    }

    // --- Fetch Streams Helper ---
    func fetchStreams(for activityID: Int) async throws -> [String: [Double]] {
        guard let t = tokens else { throw NSError(domain: "Strava", code: 401, userInfo: nil) }
        var c = URLComponents(string: "https://www.strava.com/api/v3/activities/\(activityID)/streams")!
        c.queryItems = [
            .init(name: "keys", value: "watts,heartrate"),
            .init(name: "key_by_type", value: "true")
        ]
        var req = URLRequest(url: c.url!)
        req.setValue("Bearer \(t.accessToken)", forHTTPHeaderField: "Authorization")
        let (d, r) = try await URLSession.shared.data(for: req)
        guard (r as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "Strava", code: 2, userInfo: nil)
        }
        let raw = try JSONSerialization.jsonObject(with: d, options: []) as? [String: Any]
        var result: [String: [Double]] = [:]
        for key in ["watts", "heartrate"] {
            if let arr = (raw?[key] as? [String: Any])?["data"] as? [Double] {
                result[key] = arr
            }
        }
        return result
    }

    // Upsert (insert or update) a Strava activity into Core Data
    private func upsertActivity(_ activity: StravaActivitySummary, context: NSManagedObjectContext) async throws -> Workout? {
        // Defensive: fail fast if id is missing or zero
        guard activity.id != 0 else {
            print("[StravaService] Skipping activity with missing or zero id: \(activity)")
            return nil
        }
        let request = NSFetchRequest<Workout>(entityName: "Workout")
        request.predicate = NSPredicate(format: "workoutId == %lld", activity.id)
        let existing = try? context.fetch(request)
        let w = existing?.first ?? CoreDataModel.makeWorkout(context: context)
        // Defensive: always set required fields with fallback values
        w.workoutId = NSNumber(value: activity.id)
        w.name = (activity.name?.isEmpty == false ? activity.name : "Unnamed Workout") ?? "Unnamed Workout"
        w.sport = "cycling" // TODO: map from Strava, fallback to cycling
        w.startDate = activity.startDateLocal ?? Date()
        w.distance = NSNumber(value: activity.distance ?? 0)
        w.movingTime = NSNumber(value: activity.movingTime ?? 0)
        w.avgPower = NSNumber(value: activity.averageWatts ?? 0)
        w.avgHR = NSNumber(value: activity.averageHeartrate ?? 0)
        // Defensive: clear metrics if not computable
        w.np = nil
        w.intensityFactor = nil
        w.tss = nil
        w.ftpUsed = 0.0
        do {
            if let streams = try? await fetchStreams(for: activity.id) {
                for (type, values) in streams {
                    let stream = Stream(context: context)
                    stream.id = UUID() // Set required UUID id for Stream
                    stream.workoutId = NSNumber(value: activity.id)
                    stream.type = type
                    stream.values = try JSONEncoder().encode(values)
                    stream.workout = w // FIX: set the relationship if required by Core Data
                }
                // Compute metrics
                let ftp = FTPHistoryManager.shared.ftp(for: w.startDate ?? Date(), context: context) ?? self.ftp
                let power: [Double]? = streams["watts"]
                let hr: [Double]? = streams["heartrate"]
                let np = MetricsEngine.normalizedPower(from: power) ?? 0.0
                let ifv = MetricsEngine.intensityFactor(np: np, ftp: ftp) ?? 0.0
                let tss = MetricsEngine.tss(np: np, ifv: ifv, seconds: Double(activity.movingTime ?? 0), ftp: ftp) ?? 0.0
                w.np = NSNumber(value: np)
                w.intensityFactor = NSNumber(value: ifv)
                w.tss = NSNumber(value: tss)
                w.ftpUsed = ftp
                print("[StravaService] Saved metrics for activity \(activity.id): np=\(np), if=\(ifv), tss=\(tss), ftp=\(ftp)")
            }
        } catch {
            print("[StravaService] Warning: Failed to fetch streams or compute metrics for activity \(activity.id): \(error.localizedDescription)")
        }
        return w
    }
}

// MARK: - Example usage
func exampleUsage() {
    let w = Workout()
    let avgPower = w.avgPower?.doubleValue ?? 0
    let avgHR = w.avgHR?.doubleValue ?? 0
    let np = w.np?.doubleValue ?? 0
    let intensity = w.intensityFactor?.doubleValue ?? 0
    let tss = w.tss?.doubleValue ?? 0
    print("Avg Power: \(avgPower), HR: \(avgHR), NP: \(np), IF: \(intensity), TSS: \(tss)")
}
