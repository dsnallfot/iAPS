import CoreData
import Foundation

@available(iOS 16.0,*) final class CarbPresetIntentRequest: BaseIntentsRequest {
    func addCarbs(
        _ quantityCarbs: Double,
        _ quantityFat: Double,
        _ quantityProtein: Double,
        _ dateAdded: Date,
        _ note: String?
    ) throws -> String {
        guard quantityCarbs >= 0.0 || quantityFat >= 0.0 || quantityProtein >= 0.0 else {
            return "Måltid registreras inte i iAPS"
        }

        let carbs = min(Decimal(quantityCarbs), settingsManager.settings.maxCarbs)

        carbsStorage.storeCarbs(
            [CarbsEntry(
                collectionID: UUID().uuidString,
                createdAt: dateAdded,
                carbs: carbs,
                fat: Decimal(quantityFat),
                protein: Decimal(quantityProtein),
                note: note,
                enteredBy: CarbsEntry.manual,
                isFPU: false, fpuID: nil
            )]
        )
        var resultDisplay: String
        resultDisplay = "\(carbs) g kh"
        if quantityFat > 0.0 {
            resultDisplay = "\(resultDisplay) och \(quantityFat) g fett"
        }
        if quantityProtein > 0.0 {
            resultDisplay = "\(resultDisplay) och \(quantityProtein) g protein"
        }
        let dateName = dateAdded.formatted()
        resultDisplay = "\(resultDisplay) registrerades \(dateName)"
        return resultDisplay
    }
}
