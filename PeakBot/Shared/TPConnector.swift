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

// MARK: – main connector
@MainActor
final class TPConnector {
    static let shared = TPConnector()
    private init() { _ = CookieVault.restore() }

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

    // Fetch recent workout IDs (stub implementation)
    func recentIDs(limit: Int = 20) async throws -> [Int] {
        // TODO: Replace this stub with real API call to fetch recent workout IDs
        // For now, just return an empty array or mock data
        return []
    }

    // MARK: Atlas workout list
    func fetchWorkoutsAtlas(start: Date, end: Date, fields: String = "basic") async throws -> [AtlasWorkout] {
        guard let athlete = self.athleteId else {
            throw TPError.missingAthleteId
        }
        var c = URLComponents(string: "https://home.trainingpeaks.com/atlas/v1/athlete/\(athlete)/workouts")!
        let tz = 0 // required by Atlas: timezone offset in minutes, can be fixed at 0
        c.queryItems = [
            .init(name: "startDate", value: start.tpDate),
            .init(name: "endDate", value: end.tpDate),
            .init(name: "fields", value: fields),
            .init(name: "tz", value: String(tz))
        ]
        var req = URLRequest(url: c.url!)
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw TPError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode([AtlasWorkout].self, from: data)
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
