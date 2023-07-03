import AppIntents
import Foundation

@available(iOS 16.0, *) struct ApplyTempPresetIntent: AppIntent {
    // Title of the action in the Shortcuts app
    static var title: LocalizedStringResource = "Aktivera ett tillfälligt mål"

    // Description of the action in the Shortcuts app
    static var description = IntentDescription("Tillåt att ett specifikt tillfälligt mål aktiveras.")

    internal var intentRequest: TempPresetsIntentRequest

    init() {
        intentRequest = TempPresetsIntentRequest()
    }

    @Parameter(title: "Förval") var preset: tempPreset?

    @Parameter(
        title: "Konfirmera före aktivering",
        description: "If toggled, you will need to confirm before applying",
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        When(\ApplyTempPresetIntent.$confirmBeforeApplying, .equalTo, true, {
            Summary("Aktiverar \(\.$preset)") {
                \.$confirmBeforeApplying
            }
        }, otherwise: {
            Summary("Omedelbar aktivering av \(\.$preset)") {
                \.$confirmBeforeApplying
            }
        })
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        do {
            let presetToApply: tempPreset
            if let preset = preset {
                presetToApply = preset
            } else {
                presetToApply = try await $preset.requestDisambiguation(
                    among: intentRequest.fetchAll(),
                    dialog: "Vilket tillfälligt mål vill du välja?"
                )
            }

            let displayName: String = presetToApply.name
            if confirmBeforeApplying {
                try await requestConfirmation(
                    result: .result(dialog: "Är du säker att du vill aktivera det tillfälliga målet \(displayName) ?")
                )
            }

            // TODO: enact the temp target
            let tempTarget = try intentRequest.findTempTarget(presetToApply)
            let finalTempTargetApply = try intentRequest.enactTempTarget(tempTarget)
            let displayDetail: String =
                "Det tillfälliga målet \(finalTempTargetApply.displayName) aktiveras i \(finalTempTargetApply.duration) minuter"
            return .result(
                dialog: IntentDialog(stringLiteral: displayDetail)
            )
        } catch {
            throw error
        }
    }
}
