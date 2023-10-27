import AppIntents
import Foundation

@available(iOS 16.0, *) struct CancelTempPresetIntent: AppIntent {
    // Title of the action in the Shortcuts app
    static var title: LocalizedStringResource = "Avbryt tillfälligt mål"

    // Description of the action in the Shortcuts app
    static var description = IntentDescription("Avbryt tillfälligt mål.")

    internal var intentRequest: TempPresetsIntentRequest

    init() {
        intentRequest = TempPresetsIntentRequest()
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        do {
            try intentRequest.cancelTempTarget()
            return .result(
                dialog: IntentDialog(stringLiteral: "Tillfälligt mål avbrutet")
            )
        } catch {
            throw error
        }
    }
}
