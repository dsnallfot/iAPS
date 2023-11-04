import SwiftUI

extension BolusCalculatorConfig {
    final class StateModel: BaseStateModel<Provider> {
        @Published var overrideFactor: Decimal = 0
        @Published var useCalc: Bool = false
        @Published var fattyMeals: Bool = false
        @Published var fattyMealFactor: Decimal = 0
        @Published var fattyMealTrigger: Decimal = 0

        override func subscribe() {
            subscribeSetting(\.overrideFactor, on: $overrideFactor, initial: {
                let value = max(min($0, 1.2), 0.1)
                overrideFactor = value
            }, map: {
                $0
            })
            subscribeSetting(\.useCalc, on: $useCalc) { useCalc = $0 }
            subscribeSetting(\.fattyMeals, on: $fattyMeals) { fattyMeals = $0 }
            subscribeSetting(\.fattyMealFactor, on: $fattyMealFactor, initial: {
                let value = max(min($0, 1.2), 0.1)
                fattyMealFactor = value
            }, map: {
                $0
            })
            subscribeSetting(\.fattyMealTrigger, on: $fattyMealTrigger, initial: {
                let value = max(min($0, 1.0), 0.1)
                fattyMealTrigger = value
            }, map: {
                $0
            })
        }
    }
}
