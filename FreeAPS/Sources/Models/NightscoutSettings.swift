import Foundation

struct NightscoutSettings: JSON {
    var report = "settings"
    let settings: FreeAPSSettings?
}
