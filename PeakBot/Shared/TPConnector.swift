//  TPConnector.swift   — 2025-05-03
import Foundation
import SwiftSoup

// MARK: – errors
enum TPError: Error { case loginFailed, csrfMissing, badStatus(Int), athleteMissing }

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
        guard let ids = try? await recentIDs(limit:limit) else { return }
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

    private func recentIDs(limit:Int) async throws -> [Int] {
        let aid = try await ensureAthleteID()
        let cookieId = cookies.first(where: { $0.name == "ajs_user_id" })?.value
        print("[DEBUG] request id =", aid, "cookie id =", cookieId ?? "nil")
        print("[TPConnector] using athleteId", aid)
        let base = URL(string: "https://api.trainingpeaks.com/v1/")!
        let url = base.appendingPathComponent("athlete/\(aid)/workouts?limit=\(limit)&sort=-startDate")
        var req = URLRequest(url: url)
        addCookies(to: &req)
        let (data, resp) = try await session.data(for: req)
        print("[TPConnector] status:", (resp as? HTTPURLResponse)?.statusCode ?? -1)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, code==200 else {
            print("[DEBUG] server body:", String(data: data, encoding: .utf8) ?? "(non-UTF8)")
            throw TPError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct Head:Decodable{ let workoutId:Int }
        return try JSONDecoder().decode([Head].self, from:data).map(\Head.workoutId)
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

    private var athleteId: Int? {
        get { UserDefaults.standard.integer(forKey: "tpAthleteID").nilIfZero }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "tpAthleteID") }
    }

    private func addCookies(to req: inout URLRequest) {
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        req.allHTTPHeaderFields = (req.allHTTPHeaderFields ?? [:]).merging(cookieHeader) { $1 }
    }
}

// MARK: – helpers
private extension Int { var nilIfZero:Int?{ self==0 ? nil : self}}
extension String { var int: Int? { Int(self) } }
