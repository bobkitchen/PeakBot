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
    @Published var ftp: Double = 250.0 // default, can be loaded from Core Data or UserDefaults

    // MARK: - OAuth Flow
    init() {
        // Load tokens from Keychain if available
        if let access = KeychainHelper.stravaAccessToken,
           let refresh = KeychainHelper.stravaRefreshToken,
           let expires = KeychainHelper.stravaExpiresAt {
            self.tokens = StravaOAuthTokens(accessToken: access, refreshToken: refresh, expiresAt: expires)
        }
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

    // MARK: - Sync Methods (now use Core Data)
    func syncRecentActivities() async throws {
        print("[StravaService] syncRecentActivities() called")
        guard let tokens = tokens else { throw NSError(domain: "Strava", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) }
        let context = coreData.container.viewContext
        var page = 1
        var allActivities: [StravaActivitySummary] = []
        let perPage = 50
        var fetched: [StravaActivitySummary]
        repeat {
            print("[StravaService] Fetching activities page \(page)")
            fetched = try await fetchActivities(perPage: perPage, page: page)
            print("[StravaService] Got \(fetched.count) activities on page \(page)")
            allActivities.append(contentsOf: fetched)
            page += 1
        } while !fetched.isEmpty && fetched.count == perPage && page <= 4 // limit to 200 activities for demo
        print("[StravaService] Total activities fetched: \(allActivities.count)")
        for activity in allActivities {
            let request = NSFetchRequest<Workout>(entityName: "Workout")
            request.predicate = NSPredicate(format: "workoutId == %lld", activity.id)
            let existing = try? context.fetch(request)
            let w = existing?.first ?? CoreDataModel.makeWorkout(context: context)
            // Assign Int64 value to NSNumber? property
            w.workoutId = NSNumber(value: activity.id)
            w.name = activity.name ?? ""
            w.sport = "cycling" // TODO: map from Strava
            w.startDate = activity.startDateLocal ?? Date()
            // Assign Double value to NSNumber? property
            w.distance = NSNumber(value: activity.distance ?? 0)
            // Assign Int32 value to NSNumber? property
            w.movingTime = NSNumber(value: activity.movingTime ?? 0)
            // Assign Double value to NSNumber? property
            w.avgPower = NSNumber(value: activity.averageWatts ?? 0)
            // Assign Double value to NSNumber? property
            w.avgHR = NSNumber(value: activity.averageHeartrate ?? 0)
            // --- Fetch streams ---
            let streams = try? await fetchStreams(for: activity.id)
            if let streams = streams {
                for (type, values) in streams {
                    let stream = Stream(context: context)
                    // Assign Int64 value to NSNumber? property
                    stream.workoutId = NSNumber(value: activity.id)
                    stream.type = type
                    stream.values = try JSONEncoder().encode(values)
                }
                // --- Compute metrics ---
                let ftp = self.ftp
                let power: [Double]? = streams["watts"]
                let hr: [Double]? = streams["heartrate"]
                let np = MetricsEngine.normalizedPower(from: power) ?? 0.0
                let ifv = MetricsEngine.intensityFactor(np: np, ftp: ftp) ?? 0.0
                let tss = MetricsEngine.tss(np: np, ifv: ifv, seconds: Double(activity.movingTime ?? 0), ftp: ftp) ?? 0.0
                // Assign Double value to NSNumber? property
                w.np = NSNumber(value: np)
                w.intensityFactor = NSNumber(value: ifv)
                w.tss = NSNumber(value: tss)
                let avgPower = w.avgPower?.doubleValue ?? 0
                let avgHR = w.avgHR?.doubleValue ?? 0
                let npValue = w.np?.doubleValue ?? 0
                let intensity = w.intensityFactor?.doubleValue ?? 0
                let tssValue = w.tss?.doubleValue ?? 0
                print("[StravaService] Saved metrics for activity \(activity.id): np=\(npValue), if=\(intensity), tss=\(tssValue)")
            }
        }
        try context.save()
        print("[StravaService] Synced \(allActivities.count) activities from Strava to Core Data (with streams & metrics)")
    }

    func syncHistory() async throws {
        // TODO: Implement year-by-year backfill, Core Data storage, metrics calculation
        print("[StravaService] syncHistory() called (stub)")
    }

    // MARK: - FTP
    func saveFTP(_ ftpValue: Double) {
        self.ftp = ftpValue
        // TODO: Persist FTP to Core Data or UserDefaults
        print("[StravaService] FTP saved: \(ftpValue)")
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
        guard (r as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "Strava", code: 2, userInfo: nil)
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
