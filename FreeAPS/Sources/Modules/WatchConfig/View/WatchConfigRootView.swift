import SwiftUI
import Swinject

extension WatchConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        var body: some View {
            Form {
                Section(header: Text("Apple Watch")) {
                    Picker(
                        selection: $state.selectedAwConfig,
                        label: Text("Display on Watch")
                    ) {
                        ForEach(AwConfig.allCases) { v in
                            Text(v.displayName).tag(v)
                        }
                    }
                }

                Toggle("Visa protein och fett", isOn: $state.displayFatAndProteinOnWatch)
                Toggle("Visa ->15min BG (Sensorfördröjning) ", isOn: $state.displaySensorDelayOnWatch)
                // Dölj knapp för att växla mellan temp targets och overrides på klockan. ANvänder longpress istället. Sparar koden tillsvidare ifall den behövs
                // Toggle("Visa tillfälliga mål istället för overrides", isOn: $state.useTargetButton)

                Section(header: Text("Garmin Watch")) {
                    List {
                        ForEach(state.devices, id: \.uuid) { device in
                            Text(device.friendlyName)
                        }
                        .onDelete(perform: onDelete)
                    }
                    Button("Add devices") {
                        state.selectGarminDevices()
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Watch")
            .navigationBarTitleDisplayMode(.automatic)
        }

        private func onDelete(offsets: IndexSet) {
            state.devices.remove(atOffsets: offsets)
            state.deleteGarminDevice()
        }
    }
}
