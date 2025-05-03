//  TPConnector.swift   — 2025-05-03
import Foundation
import SwiftSoup

// MARK: – errors
enum TPError: Error { case loginFailed, csrfMissing, badStatus(Int), athleteMissing }

// MARK: – cookie + credential vault (UserDefaults stub; swap for Keychain)
enum CookieVault {
    private static let key = "tpCookies"
    static func save(_ cookies:[HTTPCookie]) {
        let wantedNames = ["ASP.NET_SessionId", "TPAuth"]
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
        try await ensureAthleteID()
        let ids = try await recentIDs(limit:limit)
        print("[TPConnector] got ids:", ids.prefix(5))
        // … downloadFIT(id:) & ingest here …
    }

    func saveCredentials(email:String,password:String){
        SecureStore.save(email:email,pwd:password)
    }

    // MARK: – internals
    private var cookies:[HTTPCookie] { HTTPCookieStorage.shared.cookies ?? [] }
    private var athleteID:Int? {
        get { UserDefaults.standard.integer(forKey:"tpAthleteID").nilIfZero }
        set { UserDefaults.standard.set(newValue ?? 0, forKey:"tpAthleteID") }
    }
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

    private func ensureAthleteID() async throws {
        guard athleteID != nil else {
            try await fetchAthleteID()
            return
        }
    }

    private func fetchAthleteID() async throws {
        var r = URLRequest(url: URL(string:"https://api.trainingpeaks.com/v1/user")!)
        r.addCookies(cookies)
        let (data, resp) = try await session.data(for:r)
        guard let code = (resp as? HTTPURLResponse)?.statusCode else {
            throw TPError.badStatus(-1)
        }
        print("[TPConnector] /v1/user status:", code)
        guard code == 200 else {
            throw TPError.badStatus(code)
        }
        struct U:Decodable{let athleteId:Int}
        athleteID = try JSONDecoder().decode(U.self, from:data).athleteId
        print("[TPConnector] athleteId =", athleteID ?? -1)
    }

    private func recentIDs(limit:Int) async throws -> [Int] {
        guard let aid = athleteID else { throw TPError.athleteMissing }
        let url = URL(string:
          "https://api.trainingpeaks.com/v1/athlete/\(aid)/workouts?limit=\(limit)&sort=-startDate")!
        var r = URLRequest(url:url); r.addCookies(cookies)
        print("[TPConnector] GET", url.absoluteString)
        let (data,resp) = try await session.data(for:r)
        print("[TPConnector] status:", (resp as? HTTPURLResponse)?.statusCode ?? -1)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, code==200 else {
            throw TPError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct Head:Decodable{ let workoutId:Int }
        return try JSONDecoder().decode([Head].self, from:data).map(\Head.workoutId)
    }
}

// MARK: – helpers
private extension Int { var nilIfZero:Int?{ self==0 ? nil : self}}
private extension URLRequest {
    mutating func addCookies(_ c:[HTTPCookie]){
        for (k,v) in HTTPCookie.requestHeaderFields(with:c){ setValue(v,forHTTPHeaderField:k)}
    }
}
