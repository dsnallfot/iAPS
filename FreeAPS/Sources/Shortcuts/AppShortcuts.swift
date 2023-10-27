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
        AppShortcut(
            intent: AddCarbPresentIntent(),
            phrases: [
                "Lägg till måltid i \(.applicationName)",
                "\(.applicationName) tillåter att måltid läggs till"
            ]
        )
        AppShortcut(
            intent: AddCarbPresentIntent(),
            phrases: [
                "Add carbs in \(.applicationName)",
                "\(.applicationName) allows to add carbs"
            ]
        )
    }
}
