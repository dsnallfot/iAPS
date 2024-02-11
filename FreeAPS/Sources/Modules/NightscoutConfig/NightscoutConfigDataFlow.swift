import Combine
import Foundation

enum NightscoutConfig {
    enum Config {
        static let urlKey = "NightscoutConfig.url"
        static let secretKey = "NightscoutConfig.secret"
        static let carbsUrlKey = "NightscoutConfig.carbsUrl"
        static let userKey = "Pappa" // Uppdatera här så uppdateras enteredBy överallt
    }
}

protocol NightscoutConfigProvider: Provider {
    func checkConnection(url: URL, secret: String?) -> AnyPublisher<Void, Error>
}
