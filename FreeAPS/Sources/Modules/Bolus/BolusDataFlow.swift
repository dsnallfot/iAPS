enum Bolus {
    enum Config {}

    class Item: Identifiable, Hashable, Equatable {
        // let id = UUID()
        var rateIndex = 0
        var timeIndex = 0

        init(rateIndex: Int, timeIndex: Int) {
            self.rateIndex = rateIndex
            self.timeIndex = timeIndex
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.timeIndex == rhs.timeIndex
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(timeIndex)
        }
    }
}

protocol BolusProvider: Provider {
    var suggestion: Suggestion? { get }
    func pumpSettings() -> PumpSettings
}
