import AppIntents
import Foundation

@available(iOS 16.0, *) struct AppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
        /* AppShortcut(
             intent: ApplyTempPresetIntent(),
             phrases: [
                 "Aktivera \(.applicationName) tillfälligt mål",
                 "\(.applicationName) aktivera ett tillfälligt mål"
             ]
         )
         AppShortcut(
             intent: CancelTempPresetIntent(),
             phrases: [
                 "Avbryt \(.applicationName) tillfälligt mål",
                 "Avbryter ett aktivt \(.applicationName) tillfälligt mål"
             ]
         ) */
        AppShortcut(
            intent: ListStateIntent(),
            phrases: [
                "Lista \(.applicationName) status",
                "\(.applicationName) status"
            ]
        )
        /* AppShortcut(
             intent: AddCarbPresentIntent(),
             phrases: [
                 "Lägg till måltid i \(.applicationName)",
                 "\(.applicationName) tillåter att måltid läggs till"
             ]
         )
         AppShortcut(
             intent: ApplyOverrideIntent(),
             phrases: [
                 "Aktivera \(.applicationName) override",
                 "Aktivera en \(.applicationName) override"
             ]
         )
         AppShortcut(
             intent: CancelOverrideIntent(),
             phrases: [
                 "Avbryt \(.applicationName) override",
                 "Avbryter en aktiv \(.applicationName) override"
             ]
         )
         AppShortcut(
             intent: BolusIntent(),
             phrases: [
                 "\(.applicationName) bolus",
                 "\(.applicationName) försöker ge en bolus"
             ]
         ) */
    }
}
