import AppIntents
import Foundation

@available(iOS 16.0, *) struct AppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApplyTempPresetIntent(),
            phrases: [
                "Aktivera \(.applicationName) tillfälligt mål?",
                "\(.applicationName) aktivera ett tillfälligt mål"
            ]
        )
        AppShortcut(
            intent: ListStateIntent(),
            phrases: [
                "Lista \(.applicationName) status",
                "\(.applicationName) status"
            ]
        )
    }
}
