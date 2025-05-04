//  TPConnector.swift   — 2025-05-03
import Foundation
import SwiftSoup

// MARK: – errors
enum TPError: Error { case loginFailed, csrfMissing, badStatus(Int), athleteMissing, missingAthleteId }

// MARK: – cookie + credential vault (UserDefaults stub; swap for Keychain)
enum CookieVault {
    private static let key = "tpCookies"
    static func save(_ cookies:[HTTPCookie]) {
        let wantedNames = [
            "tpauth",                   // Production_/Sandbox_
            "asp.net_sessionid",
            "__requestverificationtoken" // ← NEW (case-insensitive)
        ]
        let wanted = cookies.filter { c in
            wantedNames.contains(where: { c.name.lowercased().hasSuffix($0.lowercased()) })
        }.compactMap(\.properties)
        UserDefaults.standard.set(wanted, forKey:key)
    }
    static func restore() -> [HTTPCookie] {
        guard let arr = UserDefaults.standard.array(forKey:key)
              as? [[HTTPCookiePropertyKey:Any]] else { return [] }
        let ck = arr.compactMap(HTTPCookie.init(properties:))
        ck.forEach { HTTPCookieStorage.shared.setCookie($0) }
        return ck
    }
}
enum SecureStore {
    static func save(email:String,pwd:String){
        UserDefaults.standard.set([email,pwd],forKey:"tpCreds")
    }
    static func load() -> (String,String)? {
        (UserDefaults.standard.array(forKey:"tpCreds")as?[String]).flatMap{$0.count==2 ?($0[0],$0[1]):nil}
    }
}

// MARK: – Atlas Session (shared, with cookies/redirects)
private let atlasSession: URLSession = {
    let cfg = URLSessionConfiguration.default
    cfg.httpCookieStorage = HTTPCookieStorage.shared      // ← IMPORTANT
    cfg.httpCookieAcceptPolicy = .always
    cfg.httpShouldSetCookies  = true
    cfg.requestCachePolicy    = .reloadIgnoringCacheData
    return URLSession(configuration: cfg,
                      delegate: nil,
                      delegateQueue: nil)
}()

// MARK: – main connector
@MainActor
final class TPConnector {
    static let shared = TPConnector()
    private init() {
        _ = CookieVault.restore()
        // Seed AtlasContext at launch if cookies exist
        if hasAuthCookies && !hasAtlasContext {
            Task { try? await self.warmUpAtlasCookies() }
        }
    }

    // public entry
    func syncLatest(limit:Int=20) async throws {
        try await ensureLogin()
        guard let ids = try? await recentIDs(limit:limit), !ids.isEmpty else {
            print("[TPConnector] No athleteId – aborting sync")
            return
        }
        print("[TPConnector] got ids:", ids.prefix(5))
        // … downloadFIT(id:) & ingest here …
    }

    func saveCredentials(email:String,password:String){
        SecureStore.save(email:email,pwd:password)
    }

    // MARK: – internals
    private var cookies:[HTTPCookie] { HTTPCookieStorage.shared.cookies ?? [] }
    private let userAPI = URL(string:"https://api.trainingpeaks.com/v1/users")!
    private let session:URLSession = .init(configuration:.ephemeral)

    private func ensureLogin() async throws {
        guard cookies.contains(where:{ $0.name.lowercased().hasSuffix("tpauth") }) else {
            try await interactiveLogin()
            return
        }
        print("[TPConnector] using stored TP cookies")
    }

    // — login via WebView already handled in UI; no-op here —
    private func interactiveLogin() async throws {
        throw TPError.loginFailed   // UI should present WKWebView sheet
    }

    // Fetch recent workout IDs – simple Atlas-based implementation
    func recentIDs(limit: Int = 20) async throws -> [Int] {
        // Ensure we have athleteId resolved
        _ = try await ensureAthleteID()

        // Use Atlas list directly (public REST not available for most users)
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end

        let atlas = try await fetchWorkoutsAtlas(start: start, end: end, fields: "id,startDate")
        let sorted = atlas.sorted { $0.startDate > $1.startDate }
        return Array(sorted.prefix(limit).map { $0.WorkoutId })
    }

    // MARK: Atlas workout list
    public func fetchWorkoutsAtlas(start: Date,
                                   end:   Date,
                                   fields: String = "basic") async throws
           -> [AtlasWorkout] {
        try await ensureAtlasContext()

        guard let athlete = self.athleteId else {
            throw TPError.missingAthleteId
        }
        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            return df
        }()
        let req = try makeAtlasRequest(
            path: "/athletes/\(athlete)/workouts",
            query: [
                .init(name: "startDate", value: dateFormatter.string(from: start)),
                .init(name: "endDate", value: dateFormatter.string(from: end)),
                .init(name: "fields", value: fields),
                .init(name: "tz", value: "0")
            ]
        )
        print("[Atlas] URL =", req.url?.absoluteString ?? "nil")
        print("[Atlas] Cookies:", HTTPCookieStorage.shared.cookies?.map { $0.name } ?? [])
        print("[Atlas] Headers:", req.allHTTPHeaderFields ?? [:])

        let (data, resp) = try await atlasSession.data(for: req)
        KeychainHelper.persistTPCookies(cookies: HTTPCookieStorage.shared.cookies ?? [])
        if let http = resp as? HTTPURLResponse {
            print("[Atlas] status", http.statusCode)
        }
        print(String(data: data, encoding: .utf8) ?? "<non-utf8>")

        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw TPError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode([AtlasWorkout].self, from: data)
    }

    /// Ensure AtlasContext cookie is present by hitting the context endpoint once per launch.
    private func ensureAtlasContext() async throws {
        print("[Atlas] ensuring context")
        if HTTPCookieStorage.shared.cookies?.contains(where: { $0.name == "AtlasContext" }) == true {
            print("[Atlas] AtlasContext cookie already present, skipping context call.")
            return
        }

        let req = try makeAtlasRequest(path: "/context", query: [])
        print("[Atlas] GET", req.url?.absoluteString ?? "nil")

        let (data, resp) = try await atlasSession.data(for: req)
        if let http = resp as? HTTPURLResponse {
            print("[Atlas] context status", http.statusCode)
            print("[Atlas] context headers", http.allHeaderFields)
        }
        KeychainHelper.persistTPCookies(cookies: HTTPCookieStorage.shared.cookies ?? [])
        print("[Atlas] cookies after context:", HTTPCookieStorage.shared.cookies?.map { $0.name } ?? [])
        print("[Atlas] context body", String(data: data, encoding: .utf8) ?? "<non-utf8>")
    }

    // Warm-up call that seeds Atlas-required cookies (mirrors tapiriik)
    private func warmUpAtlasCookies() async throws {
        guard let aid = self.athleteId else { throw TPError.missingAthleteId }
        var req = URLRequest(url: URL(string: "https://home.trainingpeaks.com/atlas/v1/athlete/\(aid)")!)
        addCookies(to: &req)
        _ = try? await session.data(for: req) // ignore status; purpose is to seed cookies
    }

    // MARK: - athlete-id resolver
    private func ensureAthleteID() async throws -> Int {
        // 1. return cached value if we resolved it once
        if let id = athleteId {
            print("[DEBUG] resolved athleteId =", id)
            return id
        }
        guard let userId = cookies.first(where: { $0.name == "ajs_user_id" })?.value.int else {
            throw TPError.athleteMissing
        }

        var req = URLRequest(url: userAPI.appendingPathComponent("\(userId)"))
        addCookies(to: &req)

        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 {
            let aid = try await discoverAthleteViaWorkout(userId: userId)
            print("[DEBUG] resolved athleteId =", aid)
            return aid
        }
        guard status == 200 else {
            throw TPError.badStatus(status)
        }

        struct UserMeta: Decodable { let athleteId: Int }
        let meta = try JSONDecoder().decode(UserMeta.self, from: data)
        athleteId = meta.athleteId
        UserDefaults.standard.set(meta.athleteId, forKey: "tpAthleteID")
        print("[DEBUG] resolved athleteId =", meta.athleteId)
        return meta.athleteId
    }

    private func discoverAthleteViaWorkout(userId: Int) async throws -> Int {
        let base = URL(string: "https://api.trainingpeaks.com/v1/")!
        var req = URLRequest(url: base.appendingPathComponent("workouts/user/\(userId)?limit=1"))
        addCookies(to: &req)
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw TPError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        struct W: Decodable { let athleteId: Int }
        let athleteId = try JSONDecoder().decode([W].self, from: data).first!.athleteId
        print("[TPConnector] resolved athleteId via workout =", athleteId)
        self.athleteId = athleteId
        UserDefaults.standard.set(athleteId, forKey: "tpAthleteID")
        return athleteId
    }

    var athleteId: Int? {
        get { UserDefaults.standard.integer(forKey: "tpAthleteID").nilIfZero }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "tpAthleteID") }
    }

    private func addCookies(to req: inout URLRequest) {
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        req.allHTTPHeaderFields = (req.allHTTPHeaderFields ?? [:]).merging(cookieHeader) { $1 }
    }

    // MARK: - Cookie helpers
    private var hasAuthCookies: Bool {
        cookies.contains { $0.name.lowercased().hasSuffix("tpauth") }
    }
    private var hasAtlasContext: Bool {
        cookies.contains { $0.name == "AtlasContext" }
    }

    // Extract JWT from Production_tpAuth cookie
    private var jwt: String? {
        HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "Production_tpAuth" })?.value
    }

    // Build Atlas API requests with Authorization header
    private func makeAtlasRequest(path: String, query: [URLQueryItem]) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "app.trainingpeaks.com"
        components.path   = "/atlas/v1" + path
        components.queryItems = query

        guard let url = components.url else { throw TPError.badStatus(-1) }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("XMLHttpRequest",  forHTTPHeaderField: "X-Requested-With")

        if let token = jwt {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ no JWT – you must login first")
            throw TPError.loginFailed
        }
        return req
    }
}

// AtlasWorkout minimal model
struct AtlasWorkout: Decodable, Identifiable {
    let WorkoutId: Int
    let StartTimeLocal: String
    let WorkoutType: Int
    var id: Int { WorkoutId }
    var startDate: Date {
        ISO8601DateFormatter().date(from: StartTimeLocal) ?? Date.distantPast
    }
}

extension Date {
    var tpDate: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: self)
    }
}

// MARK: – helpers
private extension Int { var nilIfZero:Int?{ self==0 ? nil : self}}
extension String { var int: Int? { Int(self) } }
