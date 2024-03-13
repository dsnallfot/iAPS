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
        inclusiveRange: (lowerBound: 0.05, upperBound: 3),
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
                let glucoseString = BolusIntentRequest().currentGlucose() // Fetch current glucose
                try await requestConfirmation(
                    result: .result(
                        dialog: "Your current glucose is \(glucoseString != nil ? glucoseString! : "not available"). Are you sure you want to bolus \(bolusAmountString) U of insulin?"
                    )
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
        guard settingsManager.settings.allowBolusShortcut else {
            return NSLocalizedString("Bolus Shortcuts are disabled in iAPS settings", comment: "")
        }
        guard bolusAmount >= Double(settingsManager.preferences.bolusIncrement) else {
            return NSLocalizedString("too small bolus amount", comment: "")
        }

        let maxBolus = Double(settingsManager.pumpSettings.maxBolus)

        guard bolusAmount <= Double(settingsManager.pumpSettings.maxBolus),
              settingsManager.settings.allowedRemoteBolusAmount >= Decimal(bolusAmount)
        else {
            return NSLocalizedString(
                "Angiven bolus \(bolusAmount) E är större än din inställda maxbolus \(maxBolus) E. Åtgärden avbröts! Vänligen försök igen med en mindre bolusmängd",
                comment: ""
            )
        }

        let bolus = min(
            max(Decimal(bolusAmount), settingsManager.preferences.bolusIncrement),
            settingsManager.pumpSettings.maxBolus, settingsManager.settings.allowedRemoteBolusAmount
        )
        let resultDisplay: String =
            "En bolus på \(bolus) E insulin skickades i iAPS. Bekräfta i iAPS app eller Nightscout att bolusen levererades som förväntat."

        apsManager.enactBolus(amount: Double(bolus), isSMB: false)
        return resultDisplay
    }

    func currentGlucose() -> String? {
        if let fetchedReading = coreDataStorage.fetchGlucose(interval: DateFilter().today).first {
            let fetchedGlucose = Decimal(fetchedReading.glucose)
            let convertedString = settingsManager.settings.units == .mmolL ? fetchedGlucose.asMmolL
                .formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) : fetchedGlucose
                .formatted(.number.grouping(.never).rounded().precision(.fractionLength(0)))

            return convertedString + " " + NSLocalizedString(settingsManager.settings.units.rawValue, comment: "Glucose Unit")
        }
        return nil
    }
}
