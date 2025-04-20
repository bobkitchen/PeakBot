
import Foundation

struct ActivityDetail: Decodable {
    let id: Int
    let avg_hr, max_hr, avg_power: Double?
}
