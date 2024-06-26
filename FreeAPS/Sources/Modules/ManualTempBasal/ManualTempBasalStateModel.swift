import SwiftUI

extension ManualTempBasal {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var apsManager: APSManager!
        @Injected() var pumpHistoryStorage: PumpHistoryStorage!

        @Published var rate: Decimal = 0
        @Published var durationIndex = 0
        @Published var maxBasal: Decimal = 0.0

        let durationValues = stride(from: 30.0, to: 720.1, by: 30.0).map { $0 }

        override func subscribe() {
            maxBasal = provider.pumpSettings().maxBasal
        }

        func cancel() {
            apsManager.enactTempBasal(rate: 0, duration: 0)
            showModal(for: nil)
        }

        func enact() {
            let duration = durationValues[durationIndex]
            apsManager.enactTempBasal(rate: Double(rate), duration: duration * 60)
            showModal(for: nil)
        }
    }
}
