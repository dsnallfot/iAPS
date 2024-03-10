import AppIntents
import Foundation
import Intents

@available(iOS 16.0,*) struct BolusIntent: AppIntent {
    static var title: LocalizedStringResource = "Bolus"
    static var description = IntentDescription("Tillåt att skicka boluskommandon till iAPS.")

    @Parameter(
        title: "Mängd",
        description: "Bolusmängd i E",
        controlStyle: .field,
        inclusiveRange: (lowerBound: 0.05, upperBound: 1.5),
        requestValueDialog: IntentDialog("Vad är bolusmängden i insulinenheter?")
    ) var bolusQuantity: Double?

    @Parameter(
        title: "Konfirmera före aktivering",
        description: "Om aktiverad, behöver du konfirmera innan registrering genomförs",
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        When(\.$confirmBeforeApplying, .equalTo, true, {
            Summary("Registrera \(\.$bolusQuantity)") {
                \.$confirmBeforeApplying
            }
        }, otherwise: {
            Summary("Omedelbar registrering av \(\.$bolusQuantity)") {
                \.$confirmBeforeApplying
            }
        })
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        do {
            let amount: Double
            if let cq = bolusQuantity {
                amount = cq
            } else {
                amount = try await $bolusQuantity.requestValue("Ange en bolusmängd")
            }
            let bolusAmountString = amount.formatted()
            if confirmBeforeApplying {
                try await requestConfirmation(
                    result: .result(dialog: "Är du säker på att du vill ge en bolus på \(bolusAmountString) E insulin?")
                )
            }
            let finalQuantityBolusDisplay = try BolusIntentRequest().bolus(amount)
            return .result(
                dialog: IntentDialog(stringLiteral: finalQuantityBolusDisplay)
            )

        } catch {
            throw error
        }
    }
}

@available(iOS 16.0,*) final class BolusIntentRequest: BaseIntentsRequest {
    func bolus(_ bolusAmount: Double) throws -> String {
        guard bolusAmount >= Double(settingsManager.preferences.bolusIncrement) else {
            return "för låg bolusmängd"
        }
        let bolus = min(
            max(Decimal(bolusAmount), settingsManager.preferences.bolusIncrement),
            settingsManager.pumpSettings.maxBolus
        )
        let resultDisplay: String =
            "En bolus på \(bolus) E insulin skickades i iAPS. Bekräfta i iAPS app eller Nightscout om bolusen levererades som förväntat."

        apsManager.enactBolus(amount: Double(bolus), isSMB: false)
        return resultDisplay
    }
}
