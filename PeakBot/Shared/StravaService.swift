#if os(macOS)
import AppKit
#endif
import Foundation
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
        case id
        case name
        case startDateLocal = "start_date_local"
        case distance
        case movingTime = "moving_time"
        case averageWatts = "average_watts"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case tss
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try? container.decode(String.self, forKey: .name)
        if let dateString = try? container.decode(String.self, forKey: .startDateLocal) {
            // Try ISO8601 first
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: dateString) {
                startDateLocal = date
            } else {
                // Fallback: Strava sometimes uses fractional seconds
                let fallback = DateFormatter()
                fallback.locale = Locale(identifier: "en_US_POSIX")
                fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                if let date = fallback.date(from: dateString) {
                    startDateLocal = date
                } else {
                    // Fallback: Try without fractional seconds
                    fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    startDateLocal = fallback.date(from: dateString)
                }
            }
        } else {
            startDateLocal = nil
        }
        distance = try? container.decodeIfPresent(Double.self, forKey: .distance)
        movingTime = try? container.decodeIfPresent(Int.self, forKey: .movingTime)
        averageWatts = try? container.decodeIfPresent(Double.self, forKey: .averageWatts)
        averageHeartrate = try? container.decodeIfPresent(Double.self, forKey: .averageHeartrate)
        maxHeartrate = try? container.decodeIfPresent(Double.self, forKey: .maxHeartrate)
        tss = try? container.decodeIfPresent(Double.self, forKey: .tss)
    }
}

// MARK: - Strava Service Skeleton
final class StravaService: ObservableObject {
    let clientID: String = "156540"
    let clientSecret: String = "44a03f92d978c830b493f5f4218eb48b8e7b2dbe"
    let redirectURI: String = "http://localhost:8080/callback"
    
    @Published var tokens: StravaOAuthTokens? {
        didSet {
            if let tokens = tokens {
                KeychainHelper.stravaAccessToken = tokens.accessToken
                KeychainHelper.stravaRefreshToken = tokens.refreshToken
                KeychainHelper.stravaExpiresAt = tokens.expiresAt
            } else {
                KeychainHelper.clearStravaTokens()
            }
        }
    }
    private var oauthServer: HttpServer?

    init() {
        // Attempt to load tokens from Keychain on startup
        if let access = KeychainHelper.stravaAccessToken,
           let refresh = KeychainHelper.stravaRefreshToken,
           let expires = KeychainHelper.stravaExpiresAt {
            self.tokens = StravaOAuthTokens(accessToken: access, refreshToken: refresh, expiresAt: expires)
        }
    }

    // Start OAuth flow: launches browser and starts local server
    func startOAuth(completion: @escaping (Bool) -> Void) {
        // Start local HTTP server to receive callback
        let server = HttpServer()
        server["/callback"] = { [weak self] (req: HttpRequest) -> HttpResponse in
            guard let self = self else { return .internalServerError }
            if let code = req.queryParams.first(where: { $0.0 == "code" })?.1 {
                Task {
                    do {
                        let tokens = try await self.exchangeCodeForToken(code: code)
                        DispatchQueue.main.async {
                            self.tokens = tokens
                            completion(true)
                        }
                    } catch {
                        print("[StravaService] Token exchange failed: \(error)")
                        completion(false)
                    }
                }
                return .ok(.html("<h2>Strava authorization complete. You may close this window.</h2>"))
            }
            return .badRequest(nil)
        }
        do {
            try server.start(8080, forceIPv4: true)
            self.oauthServer = server
            print("[StravaService] OAuth server started on http://localhost:8080/callback")
        } catch {
            print("[StravaService] Failed to start OAuth server: \(error)")
            completion(false)
        }
        // Open browser to authorize
        if let url = self.authorizeURL(scopes: ["activity:read_all", "profile:read_all"]) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #elseif os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }

    func stopOAuthServer() {
        oauthServer?.stop()
        oauthServer = nil
    }

    // MARK: - OAuth URLs
    func authorizeURL(scopes: [String]) -> URL? {
        var comps = URLComponents(string: "https://www.strava.com/oauth/authorize")
        comps?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: ","))
        ]
        return comps?.url
    }
    
    // Exchange OAuth code for tokens
    func exchangeCodeForToken(code: String) async throws -> StravaOAuthTokens {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let params: [String: String] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        request.httpBody = params.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "StravaService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token exchange failed: \(errorString)"])
        }
        struct StravaTokenResponse: Codable {
            let access_token: String
            let refresh_token: String
            let expires_at: TimeInterval
        }
        let decoded = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
        return StravaOAuthTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: decoded.expires_at
        )
    }
    
    // MARK: - Refresh Token
    func refreshToken(_ refreshToken: String) async throws -> StravaOAuthTokens {
        // Implement POST /oauth/token with grant_type=refresh_token
        throw NSError(domain: "StravaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    
    // MARK: - Fetch Activities
    func fetchActivities(after: Date? = nil, perPage: Int = 50, page: Int = 1) async throws -> [StravaActivitySummary] {
        guard let tokens = tokens else {
            throw NSError(domain: "StravaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Strava tokens available"])
        }
        var comps = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if let after = after {
            let afterTimestamp = Int(after.timeIntervalSince1970)
            queryItems.append(URLQueryItem(name: "after", value: String(afterTimestamp)))
        }
        comps.queryItems = queryItems
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "StravaService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Fetch activities failed: \(errorString)"])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([StravaActivitySummary].self, from: data)
    }

    // MARK: - Fetch Activities with Details & Streams
    struct StravaActivityDetail: Codable, Identifiable, Hashable {
        let id: Int
        let name: String
        let type: String
        let startDateLocal: Date
        let movingTime: Int?
        let distance: Double?
        let sufferScore: Double? // Relative Effort
        let weightedAverageWatts: Double?
        let averageWatts: Double?
        let averageHeartrate: Double?
        let maxHeartrate: Double?
        let averageCadence: Double?
        let calories: Double?
        let trainer: Bool?
        let commute: Bool?
        let intensityScore: Double? // Not always present
        // Streams will be attached after fetching
        var hrStream: [Double]?
        var powerStream: [Double]?
        // NEW: TSS field (auto or manual)
        var tss: Double?
        // NEW: Flag for manual override
        var tssIsManual: Bool?

        enum CodingKeys: String, CodingKey {
            case id, name, type, distance, trainer, commute
            case startDateLocal = "start_date_local"
            case movingTime = "moving_time"
            case sufferScore = "suffer_score"
            case weightedAverageWatts = "weighted_average_watts"
            case averageWatts = "average_watts"
            case averageHeartrate = "average_heartrate"
            case maxHeartrate = "max_heartrate"
            case averageCadence = "average_cadence"
            case calories
            case intensityScore = "intensity_score"
            case tss
            case tssIsManual = "tss_is_manual"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? container.decode(Int.self, forKey: .id)) ?? -1
            name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
            type = (try? container.decodeIfPresent(String.self, forKey: .type)) ?? ""
            // Robust date decoding
            let dateString = (try? container.decodeIfPresent(String.self, forKey: .startDateLocal)) ?? ""
            startDateLocal = ISO8601DateFormatter().date(from: dateString) ?? Date()
            movingTime = StravaActivityDetail.decodeIntOrString(forKey: .movingTime, in: container)
            distance = StravaActivityDetail.decodeDoubleOrString(forKey: .distance, in: container)
            sufferScore = StravaActivityDetail.decodeDoubleOrString(forKey: .sufferScore, in: container)
            weightedAverageWatts = StravaActivityDetail.decodeDoubleOrString(forKey: .weightedAverageWatts, in: container)
            averageWatts = StravaActivityDetail.decodeDoubleOrString(forKey: .averageWatts, in: container)
            averageHeartrate = StravaActivityDetail.decodeDoubleOrString(forKey: .averageHeartrate, in: container)
            maxHeartrate = StravaActivityDetail.decodeDoubleOrString(forKey: .maxHeartrate, in: container)
            averageCadence = StravaActivityDetail.decodeDoubleOrString(forKey: .averageCadence, in: container)
            calories = StravaActivityDetail.decodeDoubleOrString(forKey: .calories, in: container)
            trainer = (try? container.decodeIfPresent(Bool.self, forKey: .trainer)) ?? false
            commute = (try? container.decodeIfPresent(Bool.self, forKey: .commute)) ?? false
            intensityScore = StravaActivityDetail.decodeDoubleOrString(forKey: .intensityScore, in: container)
            tss = StravaActivityDetail.decodeDoubleOrString(forKey: .tss, in: container)
            tssIsManual = (try? container.decodeIfPresent(Bool.self, forKey: .tssIsManual)) ?? false
            hrStream = nil
            powerStream = nil
        }

        static func decodeDoubleOrString(forKey key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>) -> Double? {
            if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: key) {
                return doubleVal
            }
            if let stringVal = try? container.decodeIfPresent(String.self, forKey: key) {
                return Double(stringVal)
            }
            return nil
        }

        static func decodeIntOrString(forKey key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>) -> Int? {
            if let intVal = try? container.decodeIfPresent(Int.self, forKey: key) {
                return intVal
            }
            if let stringVal = try? container.decodeIfPresent(String.self, forKey: key) {
                return Int(stringVal)
            }
            return nil
        }
    }

    struct StravaStreamSet: Codable {
        let type: String
        let data: [Double]
    }

    func fetchDetailedActivities(lastNDays: Int = 90) async throws -> [StravaActivityDetail] {
        // 1. Fetch activity summaries for last N days
        let after = Calendar.current.date(byAdding: .day, value: -lastNDays, to: Date())
        let summaries = try await fetchActivities(after: after)
        var details: [StravaActivityDetail] = []
        // Limit to 10 activities for testing
        let limitedSummaries = summaries.prefix(10)
        for summary in limitedSummaries {
            do {
                let detail = try await fetchActivityDetailAndStreams(id: summary.id)
                details.append(detail)
            } catch {
                print("[StravaService] Failed to fetch detail for activity \(summary.id):", error)
            }
        }
        return details
    }

    private func fetchActivityDetailAndStreams(id: Int) async throws -> StravaActivityDetail {
        guard let tokens = tokens else { throw NSError(domain: "StravaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Strava tokens available"]) }
        // Fetch detail
        let detailURL = URL(string: "https://www.strava.com/api/v3/activities/\(id)")!
        var detailReq = URLRequest(url: detailURL)
        detailReq.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        let (detailData, detailResp) = try await URLSession.shared.data(for: detailReq)
        guard let detailHTTP = detailResp as? HTTPURLResponse, detailHTTP.statusCode == 200 else {
            let errStr = String(data: detailData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "StravaService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Fetch activity detail failed: \(errStr)"])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var detail = try decoder.decode(StravaActivityDetail.self, from: detailData)
        // Fetch streams
        let streamsURL = URL(string: "https://www.strava.com/api/v3/activities/\(id)/streams?keys=heartrate,power&key_by_type=true")!
        var streamsReq = URLRequest(url: streamsURL)
        streamsReq.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        let (streamsData, streamsResp) = try await URLSession.shared.data(for: streamsReq)
        guard let streamsHTTP = streamsResp as? HTTPURLResponse, streamsHTTP.statusCode == 200 else {
            let errStr = String(data: streamsData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "StravaService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Fetch streams failed: \(errStr)"])
        }
        let streamsDict = try JSONDecoder().decode([String: StravaStreamSet].self, from: streamsData)
        detail.hrStream = streamsDict["heartrate"]?.data
        detail.powerStream = streamsDict["power"]?.data
        return detail
    }
}
