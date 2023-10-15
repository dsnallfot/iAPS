import AppIntents
import Foundation
import Intents
import Swinject

@available(iOS 16.0,*) struct AddCarbPresentIntent: AppIntent {
    // Title of the action in the Shortcuts app
    static var title: LocalizedStringResource = "Lägg till måltid"

    // Description of the action in the Shortcuts app
    static var description = IntentDescription("Tillåt att måltid läggs till i iAPS.")

    internal var carbRequest: CarbPresetIntentRequest

    init() {
        carbRequest = CarbPresetIntentRequest()
        dateAdded = Date()
    }

    @Parameter(
        title: "Mängd kolhydrater",
        description: "Mängd kolhydrater i g",
        controlStyle: .field,
        inclusiveRange: (lowerBound: 0, upperBound: 200),
        requestValueDialog: IntentDialog("Vilken mängd kolhydrater i gram vill du lägga till?")
    ) var carbQuantity: Double?

    @Parameter(
        title: "Mängd fett",
        description: "Mängd fett i g",
        default: 0.0,
        inclusiveRange: (0, 200)
    ) var fatQuantity: Double

    @Parameter(
        title: "Mängd protein",
        description: "Mängd protein i g",
        default: 0.0,
        inclusiveRange: (0, 200)
    ) var proteinQuantity: Double

    @Parameter(
        title: "Datum",
        description: "Datum för registrering"
    ) var dateAdded: Date

    @Parameter(
        title: "Notering",
        description: "Emoji eller kort text"
    ) var note: String?

    @Parameter(
        title: "Bekräfta innan registrering",
        description: "Om aktiverad, behöver du konfirmera innan registrering genomförs",
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        When(\.$confirmBeforeApplying, .equalTo, true, {
            Summary("Registrera \(\.$carbQuantity) \(\.$dateAdded)") {
                \.$fatQuantity
                \.$proteinQuantity
                \.$note
                \.$confirmBeforeApplying
            }
        }, otherwise: {
            Summary("Omedelbar registrering av \(\.$carbQuantity) \(\.$dateAdded)") {
                \.$fatQuantity
                \.$proteinQuantity
                \.$note
                \.$confirmBeforeApplying
            }
        })
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        do {
            let quantityCarbs: Double
            if let cq = carbQuantity {
                quantityCarbs = cq
            } else {
                quantityCarbs = try await $carbQuantity.requestValue("Hur många kh?")
            }

            let quantityCarbsName = quantityCarbs.toString()
            if confirmBeforeApplying {
                try await requestConfirmation(
                    result: .result(dialog: "Är du säker på att du vill registrera \(quantityCarbsName) g kh?")
                )
            }

            // Pass the 'note' parameter when calling addCarbs
            let finalQuantityCarbsDisplay = try carbRequest.addCarbs(
                quantityCarbs,
                fatQuantity,
                proteinQuantity,
                dateAdded,
                note
            )
            return .result(
                dialog: IntentDialog(stringLiteral: finalQuantityCarbsDisplay)
            )

        } catch {
            throw error
        }
    }
}
