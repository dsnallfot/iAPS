import AppIntents
import Foundation
import Intents

@available(iOS 16.0, *) struct OverrideEntity: AppEntity, Identifiable {
    static var defaultQuery = OverrideQuery()

    var id: UUID
    var name: String
    var description: String // Currently not displayed in Shortcuts

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Presets"
}

enum OverrideIntentError: Error {
    case StateIntentUnknownError
    case NoPresets
}

@available(iOS 16.0, *) struct ApplyOverrideIntent: AppIntent {
    // Title of the action in the Shortcuts app
    static var title: LocalizedStringResource = "Aktivera en override"

    // Description of the action in the Shortcuts app
    static var description = IntentDescription("Tillåt att en override aktiveras.")

    internal var intentRequest: OverrideIntentRequest

    init() {
        intentRequest = OverrideIntentRequest()
    }

    @Parameter(title: "Förval") var preset: OverrideEntity?

    @Parameter(
        title: "Konfirmera före aktivering",
        description: "Om aktiverad, behöver du konfirmera innan registrering genomförs",
        default: true
    ) var confirmBeforeApplying: Bool

    static var parameterSummary: some ParameterSummary {
        When(\ApplyOverrideIntent.$confirmBeforeApplying, .equalTo, true, {
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
            let presetToApply: OverrideEntity
            if let preset = preset {
                presetToApply = preset
            } else {
                presetToApply = try await $preset.requestDisambiguation(
                    among: intentRequest.fetchPresets(),
                    dialog: "Vilken override vill du aktivera?"
                )
            }

            let displayName: String = presetToApply.name
            if confirmBeforeApplying {
                try await requestConfirmation(
                    result: .result(dialog: "Är du säker att du vill aktivera override \(displayName) ?")
                )
            }

            let preset = try intentRequest.findPreset(displayName)
            let finalOverrideApply = try intentRequest.enactOverride(preset)
            let isDone = finalOverrideApply.isPreset

            let displayDetail: String = isDone ?
                "Override \(displayName) är nu aktiverad" : "Aktivering av override misslyckades"
            return .result(
                dialog: IntentDialog(stringLiteral: displayDetail)
            )
        } catch {
            throw error
        }
    }
}

@available(iOS 16.0, *) struct CancelOverrideIntent: AppIntent {
    static var title: LocalizedStringResource = "Avbryt aktiv override"
    static var description = IntentDescription("Avbryt aktiv override.")

    internal var intentRequest: OverrideIntentRequest

    init() {
        intentRequest = OverrideIntentRequest()
    }

    @MainActor func perform() async throws -> some ProvidesDialog {
        do {
            try intentRequest.cancelOverride()
            return .result(
                dialog: IntentDialog(stringLiteral: "Override avbröts")
            )
        } catch {
            throw error
        }
    }
}

@available(iOS 16.0, *) struct OverrideQuery: EntityQuery {
    internal var intentRequest: OverrideIntentRequest

    init() {
        intentRequest = OverrideIntentRequest()
    }

    func entities(for identifiers: [OverrideEntity.ID]) async throws -> [OverrideEntity] {
        let presets = intentRequest.fetchIDs(identifiers)
        return presets
    }

    func suggestedEntities() async throws -> [OverrideEntity] {
        let presets = try intentRequest.fetchPresets()
        return presets
    }
}

@available(iOS 16.0, *) final class OverrideIntentRequest: BaseIntentsRequest {
    func fetchPresets() throws -> ([OverrideEntity]) {
        let presets = overrideStorage.fetchProfiles().flatMap { preset -> [OverrideEntity] in
            let percentage = preset.percentage != 100 ? preset.percentage.formatted() : ""
            let targetRaw = settingsManager.settings
                .units == .mgdL ? Decimal(Double(preset.target ?? 0)) : Double(preset.target ?? 0)
                .asMmolL
            let target = (preset.target != 0 || preset.target != 6) ?
                (glucoseFormatter.string(from: targetRaw as NSNumber) ?? "") : ""
            let string = percentage != "" ? percentage + ", " + target : target

            return [OverrideEntity(
                id: UUID(uuidString: preset.id ?? "") ?? UUID(),
                name: preset.name ?? "",
                description: string
            )]
        }
        return presets
    }

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if settingsManager.settings.units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
        }
        formatter.roundingMode = .halfUp
        return formatter
    }

    func findPreset(_ name: String) throws -> OverridePresets {
        let presetFound = overrideStorage.fetchProfiles().filter({ $0.name == name })
        guard let preset = presetFound.first else { throw OverrideIntentError.NoPresets }
        return preset
    }

    func fetchIDs(_ id: [OverrideEntity.ID]) -> [OverrideEntity] {
        let presets = overrideStorage.fetchProfiles().filter { id.contains(UUID(uuidString: $0.id ?? "")!) }
            .map { preset -> OverrideEntity in
                let percentage = preset.percentage != 100 ? preset.percentage.formatted() : ""
                let targetRaw = settingsManager.settings
                    .units == .mgdL ? Decimal(Double(preset.target ?? 0)) : Double(preset.target ?? 0)
                    .asMmolL
                let target = (preset.target != 0 || preset.target != 6) ?
                    (glucoseFormatter.string(from: targetRaw as NSNumber) ?? "") : ""
                let string = percentage != "" ? percentage + ", " + target : target

                return OverrideEntity(
                    id: UUID(uuidString: preset.id ?? "") ?? UUID(),
                    name: preset.name ?? "",
                    description: string
                )
            }
        return presets
    }

    func enactOverride(_ preset: OverridePresets) throws -> Override {
        guard let override = overrideStorage.fetchProfile(preset.name ?? "") else {
            return Override()
        }

        let lastActiveOverride = overrideStorage.fetchLatestOverride().first
        let isActive = lastActiveOverride?.enabled ?? false

        // Cancel eventual current active override first
        if isActive {
            if let duration = overrideStorage.cancelProfile(), let last = lastActiveOverride {
                let presetName = overrideStorage.isPresetName()
                let nsString = presetName != nil ? presetName : last.percentage.formatted()
                nightscoutManager.editOverride(nsString!, duration, last.date ?? Date())
            }
        }
        overrideStorage.overrideFromPreset(preset)
        let currentActiveOverride = overrideStorage.fetchLatestOverride().first
        nightscoutManager.uploadOverride(preset.name ?? "", Double(preset.duration ?? 0), currentActiveOverride?.date ?? Date.now)
        return override
    }

    func cancelOverride() throws {
        // Is there even a saved Override?
        if let activeOverride = overrideStorage.fetchLatestOverride().first {
            let presetName = overrideStorage.isPresetName()
            // Is the Override a Preset?
            if let preset = presetName {
                if let duration = overrideStorage.cancelProfile() {
                    // Update in Nightscout
                    nightscoutManager.editOverride(preset, duration, activeOverride.date ?? Date.now)
                }
            } else {
                let nsString = activeOverride.percentage.formatted() != "100" ? activeOverride.percentage
                    .formatted() + " %" : "Custom"
                if let duration = overrideStorage.cancelProfile() {
                    nightscoutManager.editOverride(nsString, duration, activeOverride.date ?? Date.now)
                }
            }
        }
    }
}
