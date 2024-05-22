import CoreData
import SwiftUI
import Swinject

extension NightscoutConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State var importAlert: Alert?
        @State var isImportAlertPresented = false
        @State var importedHasRun = false

        @FetchRequest(
            entity: ImportError.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)], predicate: NSPredicate(
                format: "date > %@", Date().addingTimeInterval(-1.minutes.timeInterval) as NSDate
            )
        ) var fetchedErrors: FetchedResults<ImportError>

        private var portFormater: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.allowsFloats = false
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    TextField("URL", text: $state.url)
                        .disableAutocorrection(true)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    SecureField("API secret", text: $state.secret)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .textContentType(.password)
                        .keyboardType(.asciiCapable)
                    if !state.message.isEmpty {
                        Text(state.message)
                    }
                    if state.connecting {
                        HStack {
                            Text("Connecting...")
                            Spacer()
                            ProgressView()
                        }
                    }
                } header: {
                    Text("Nightscout URL och Secret")
                }

                Section {
                    TextField("Räkna KH URL", text: $state.carbsUrl)
                        .disableAutocorrection(true)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                } header: {
                    Text("URL till Räkna KH")
                }

                Section {
                    Button("Anslut till Nightscout") { state.connect() }
                        .disabled(state.url.isEmpty || state.connecting)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(
                            AnyView(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                    Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                    Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                    Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                    Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        )
                        .tint(.white)
                        .fontWeight(.semibold)
                }
                /* Section {
                     Button("Radera URL och Secret") { state.delete() }
                         .frame(maxWidth: .infinity, alignment: .center)
                         // .foregroundColor(.loopRed)
                         .disabled(state.connecting)
                         .listRowBackground(Color(.red)).tint(.white)
                         .fontWeight(.semibold)
                 }*/

                Section {
                    Toggle("Ladda upp behandlingar", isOn: $state.isUploadEnabled)
                    // Toggle("Ladda även upp statistik", isOn: $state.uploadStats)
                    Toggle("Ladda upp glukosvärden", isOn: $state.uploadGlucose)

                    Toggle("Ladda ner behandlingar", isOn: $state.isDownloadEnabled)
                } header: {
                    Text("Tillåt upp-/nedladdning Nightscout")
                }

                Section {
                    Toggle("Aktivera fjärrstyrning", isOn: $state.allowAnnouncements)
                } header: { Text("Tillåt fjärrstyrning av iAPS") }

                Section {
                    Button(action: {
                        importAlert = Alert(
                            title: Text("Import settings?"),
                            message: Text(
                                "\n" +
                                    NSLocalizedString(
                                        "This will replace some or all of your current pump settings. Are you sure you want to import profile settings from Nightscout?",
                                        comment: "Profile Import Alert"
                                    ) +
                                    "\n"
                            ),
                            primaryButton: .destructive(
                                Text("Yes, Import"),
                                action: {
                                    state.importSettings()
                                    importedHasRun = true
                                }
                            ),
                            secondaryButton: .cancel()
                        )
                        isImportAlertPresented.toggle()
                    }) {
                        Text("Import settings from Nightscout")
                            .fontWeight(.semibold)
                    }
                    .disabled(state.url.isEmpty || state.connecting)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(
                        AnyView(LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    )
                    .tint(.white)
                } header: { Text("Import from Nightscout") }

                    .alert(isPresented: $importedHasRun) {
                        Alert(
                            title: Text((fetchedErrors.first?.error ?? "").count < 4 ? "Settings imported" : "Import Error"),
                            message: Text(
                                (fetchedErrors.first?.error ?? "").count < 4 ?
                                    NSLocalizedString(
                                        "\nNow please verify all of your new settings thoroughly:\n\n* Basal Settings\n * Carb Ratios\n * Glucose Targets\n * Insulin Sensitivities\n * DIA\n\n in iAPS Settings > Configuration.\n\nBad or invalid profile settings could have disatrous effects.",
                                        comment: "Imported Profiles Alert"
                                    ) :
                                    NSLocalizedString(fetchedErrors.first?.error ?? "", comment: "Import Error")
                            ),
                            primaryButton: .destructive(
                                Text("OK")
                            ),
                            secondaryButton: .cancel()
                        )
                    }

                /* Section {
                     Toggle("Use local glucose server", isOn: $state.useLocalSource)
                     HStack {
                         Text("Port")
                         DecimalTextField("", value: $state.localPort, formatter: portFormater)
                     }
                 } header: { Text("Local glucose source") } */
                Section {
                    Button("Backfill glucose") { state.backfillGlucose() }
                        .disabled(state.url.isEmpty || state.connecting || state.backfilling)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fontWeight(.semibold)
                        .listRowBackground(
                            AnyView(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                    Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                    Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                    Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                    Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        )
                        .tint(.white)
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Nightscout och web")
            .navigationBarTitleDisplayMode(.automatic)
            .alert(isPresented: $isImportAlertPresented) {
                importAlert!
            }
        }
    }
}
