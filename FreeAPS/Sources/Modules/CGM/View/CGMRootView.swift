import LoopKitUI
import SwiftUI
import Swinject

extension CGM {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var setupCGM = false

        // @AppStorage(UserDefaults.BTKey.cgmTransmitterDeviceAddress.rawValue) private var cgmTransmitterDeviceAddress: String? = nil

        var body: some View {
            // NavigationView {
            Form {
                Section(header: Text("CGM")) {
                    Picker("Type", selection: $state.cgm) {
                        ForEach(CGMType.allCases) { type in
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                                Text(type.subtitle).font(.caption).foregroundColor(.secondary)
                            }.tag(type)
                        }
                    }
                    if let link = state.cgm.externalLink {
                        Button("About this source") {
                            UIApplication.shared.open(link, options: [:], completionHandler: nil)
                        }
                    }
                }
                if [.dexcomG5, .dexcomG6, .dexcomG7].contains(state.cgm) {
                    Section {
                        Button("CGM Configuration") {
                            setupCGM.toggle()
                        }
                    }
                }
                if state.cgm == .xdrip {
                    Section(header: Text("Heartbeat")) {
                        VStack(alignment: .leading) {
                            if let cgmTransmitterDeviceAddress = state.cgmTransmitterDeviceAddress {
                                Text("CGM address :")
                                Text(cgmTransmitterDeviceAddress)
                            } else {
                                Text("CGM is not used as heartbeat.")
                            }
                        }
                    }
                }
                if state.cgm == .libreTransmitter {
                    Button("Configure Libre Transmitter") {
                        state.showModal(for: .libreConfig)
                    }
                    Text("Calibrations").navigationLink(to: .calibrations, from: self)
                }
                Section(header: Text("Calendar")) {
                    Toggle("Skapa kalenderhändelser", isOn: $state.createCalendarEvents)
                    if state.calendarIDs.isNotEmpty {
                        Picker("Calendar", selection: $state.currentCalendarID) {
                            ForEach(state.calendarIDs, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        Toggle("Visa ->15min BG (Sensorfördröjning)", isOn: $state.displayCalendarEmojis)
                        Toggle("Visa COB och IOB", isOn: $state.displayCalendarIOBandCOB)
                    } else if state.createCalendarEvents {
                        if #available(iOS 17.0, *) {
                            Text(
                                "Om du inte får upp kalendrar att välja från här, gå till Inställningar  -> iAPS -> Kalendrar och ändra behörighet till \"Full åtkomst\""
                            ).font(.footnote)

                            Button("Open Settings") {
                                // Get the settings URL and open it
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Experimental")) {
                    Toggle("Smooth Glucose Value", isOn: $state.smoothGlucose)
                }

                Section(header: Text("Simulatorläge")) {
                    Toggle("Denna enhet används som simulator", isOn: $state.simulatorMode)
                }
            }

            .onAppear(perform: configureView)
            .navigationTitle("CGM")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $setupCGM) {
                if let cgmFetchManager = state.cgmManager, cgmFetchManager.glucoseSource.cgmType == state.cgm,
                   let cgmManager = cgmFetchManager.glucoseSource.cgmManager
                {
                    CGMSettingsView(
                        cgmManager: cgmManager,
                        bluetoothManager: state.provider.apsManager.bluetoothManager!,
                        unit: state.settingsManager.settings.units,
                        completionDelegate: state
                    )
                } else {
                    CGMSetupView(
                        CGMType: state.cgm,
                        bluetoothManager: state.provider.apsManager.bluetoothManager!,
                        unit: state.settingsManager.settings.units,
                        completionDelegate: state,
                        setupDelegate: state
                    )
                }
            }
            .onChange(of: setupCGM) { setupCGM in
                state.setupCGM = setupCGM
            }
            .onChange(of: state.setupCGM) { setupCGM in
                self.setupCGM = setupCGM
            }
            // }
        }
    }
}
